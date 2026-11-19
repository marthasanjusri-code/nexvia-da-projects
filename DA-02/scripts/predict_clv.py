"""
predict_clv.py

Predicts customer lifetime value (CLV) with the standard "buy till you die"
models and loads the result into BigQuery, where dbt reads it as a source.

Models (PyMC-Marketing):
  BG/NBD           how many repeat purchases a customer will make, and the
                   probability the customer is still active (Fader, Hardie & Lee, 2005).
                   A customer can only drop out after a repeat purchase, so every
                   one-time buyer gets probability alive = 1.
  Modified BG/NBD  the same, but a customer can also drop out after the first
                   purchase (Batislam et al., 2007), which matters here because
                   88% of customers bought once.
  Both are fitted and validated on the same holdout; the one with the smaller
  error in total repeat purchases is used.
  Gamma-Gamma      the expected value of those purchases (Fader & Hardie, 2013)
  CLV          expected purchases x expected value over 12 months,
               discounted at 1% a month (about 12.7% a year)

Steps
  1. Read orders from the dbt mart fct_orders.
  2. Build frequency / recency / T / monetary value with PyMC-Marketing's
     rfm_summary, in days. Repeat purchases are counted in distinct days.
  3. Validate both transaction models: fit on Nov-Dec 2020, predict January 2021,
     compare with actual. Pick the model with the smaller total error.
  4. Fit the chosen model on all data and predict per customer.
  5. Load ml_clv.customer_clv (replaced on every run).

Run from DA-02 with the venv active, after `dbt build`:
  python scripts/predict_clv.py
"""

import warnings

import pandas as pd
from google.cloud import bigquery
from pymc_marketing import clv

warnings.filterwarnings("ignore", category=UserWarning)
warnings.filterwarnings("ignore", category=FutureWarning)

PROJECT_ID = "da02-customer360-515112"
LOCATION = "US"
ORDERS_TABLE = f"{PROJECT_ID}.customer360_dev_marts.fct_orders"
OUTPUT_TABLE = f"{PROJECT_ID}.ml_clv.customer_clv"

OBSERVATION_END = "2021-01-31"  # last day of GA4 data
CALIBRATION_END = "2020-12-31"  # validation: fit to here, test on January 2021
FORECAST_MONTHS = 12
MONTHLY_DISCOUNT_RATE = 0.01
SEED = 42


def mean_over_samples(x) -> pd.Series:
    """MAP fits still return chain/draw dimensions of size 1; drop them."""
    for dim in ("chain", "draw"):
        if dim in x.dims:
            x = x.mean(dim)
    return x.to_series()


TRANSACTION_MODELS = {
    "BG/NBD": clv.BetaGeoModel,
    "Modified BG/NBD": clv.ModifiedBetaGeoModel,
}


def fit_transaction_model(name: str, rfm: pd.DataFrame):
    model = TRANSACTION_MODELS[name]()
    model.fit(data=rfm[["customer_id", "frequency", "recency", "T"]],
              method="map", progressbar=False, random_seed=SEED)
    return model


def validate(orders: pd.DataFrame) -> str:
    """Holdout check for each model; returns the name of the better one."""
    split = clv.rfm_train_test_split(
        orders, "customer_id", "order_date",
        train_period_end=CALIBRATION_END, test_period_end=OBSERVATION_END,
        time_unit="D",
    )
    test_days = (pd.Timestamp(OBSERVATION_END) - pd.Timestamp(CALIBRATION_END)).days
    actual = split.set_index("customer_id")["test_frequency"]
    print("Validation (fit to 2020-12-31, predict January 2021):")
    print(f"  customers in calibration: {len(split)}, actual repeat purchases: {actual.sum():.0f}")
    errors = {}
    for name in TRANSACTION_MODELS:
        model = fit_transaction_model(name, split)
        predicted = mean_over_samples(model.expected_purchases(data=split, future_t=test_days))
        mae = (predicted - actual.reindex(predicted.index)).abs().mean()
        errors[name] = abs(predicted.sum() - actual.sum())
        print(f"  {name}: predicted {predicted.sum():.1f}, "
              f"total error {errors[name]:.1f}, mean absolute error per customer {mae:.3f}")
    chosen = min(errors, key=errors.get)
    print(f"  chosen: {chosen}")
    return chosen


def main():
    client = bigquery.Client(project=PROJECT_ID, location=LOCATION)
    orders = client.query(
        f"select customer_id, order_date, order_total_usd from `{ORDERS_TABLE}`"
    ).to_dataframe()
    orders["order_date"] = pd.to_datetime(orders["order_date"])
    orders["order_total_usd"] = orders["order_total_usd"].astype(float)
    print(f"Orders read: {len(orders)}, customers: {orders['customer_id'].nunique()}, "
          f"revenue {orders['order_total_usd'].sum():,.2f} USD")

    chosen = validate(orders)

    rfm = clv.rfm_summary(
        orders, "customer_id", "order_date", "order_total_usd",
        observation_period_end=OBSERVATION_END, time_unit="D",
    )
    repeat = rfm[rfm["frequency"] > 0]

    # Gamma-Gamma assumes order value does not depend on purchase frequency.
    corr = repeat[["frequency", "monetary_value"]].corr().iloc[0, 1]
    print(f"Gamma-Gamma check, correlation of frequency and order value: {corr:.3f}")

    bgm = fit_transaction_model(chosen, rfm)
    ggm = clv.GammaGammaModel()
    ggm.fit(data=repeat[["customer_id", "frequency", "monetary_value"]],
            method="map", progressbar=False, random_seed=SEED)
    print(f"{chosen} parameters:", bgm.fit_summary().round(4).to_dict())
    print("Gamma-Gamma parameters:", ggm.fit_summary().round(4).to_dict())

    out = pd.DataFrame({
        "probability_alive": mean_over_samples(bgm.expected_probability_alive(data=rfm)),
        "expected_purchases_90d": mean_over_samples(bgm.expected_purchases(data=rfm, future_t=90)),
        "expected_order_value_usd": mean_over_samples(ggm.expected_customer_spend(data=rfm)),
        "clv_12m_usd": mean_over_samples(ggm.expected_customer_lifetime_value(
            transaction_model=bgm, data=rfm, future_t=FORECAST_MONTHS,
            discount_rate=MONTHLY_DISCOUNT_RATE, time_unit="D")),
    })
    out = rfm.set_index("customer_id").join(out).reset_index().rename(columns={
        "frequency": "repeat_purchase_days",
        "recency": "recency_days",
        "T": "customer_age_days",
        "monetary_value": "repeat_order_mean_value_usd",
    })
    out["model"] = f"{chosen} + Gamma-Gamma (PyMC-Marketing, MAP)"
    out["observation_end"] = pd.Timestamp(OBSERVATION_END).date()

    client.create_dataset(bigquery.Dataset(f"{PROJECT_ID}.ml_clv"), exists_ok=True)
    job = client.load_table_from_dataframe(
        out, OUTPUT_TABLE,
        job_config=bigquery.LoadJobConfig(write_disposition="WRITE_TRUNCATE"),
    )
    job.result()
    print(f"Loaded {OUTPUT_TABLE}: {job.output_rows} rows")
    print(f"  total 12-month CLV: {out['clv_12m_usd'].sum():,.2f} USD, "
          f"median {out['clv_12m_usd'].median():,.2f} USD")


if __name__ == "__main__":
    main()
