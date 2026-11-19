"""
export_tableau_extracts.py

Exports the final dbt marts to CSV for Tableau Public, which cannot connect
to BigQuery. The files are read-only copies; all logic stays in dbt.

Personal fields (names, emails, device IDs) are left out, because a Tableau
Public workbook is visible to anyone. The names and emails are synthetic,
but the practice of not publishing them is kept.

Writes to DA-02/tableau/data/ (replaced on every run):
  channel_performance.csv   one row per channel and attribution model
  customer_360.csv          one row per customer: RFM, segment, CLV

Run from DA-02 with the venv active, after dbt build and predict_clv.py:
  python scripts/export_tableau_extracts.py
"""

from pathlib import Path

from google.cloud import bigquery

PROJECT_ID = "da02-customer360-515112"
LOCATION = "US"
MARTS = f"{PROJECT_ID}.customer360_dev_marts"
OUT_DIR = Path(__file__).resolve().parent.parent / "tableau" / "data"

EXTRACTS = {
    "channel_performance.csv": f"""
        select channel, attribution_model, sessions, conversions, revenue_usd,
               cost_usd, roas, roi, cpa_usd
        from `{MARTS}.mart_channel_performance`
        order by channel, attribution_model
    """,
    "customer_360.csv": f"""
        select customer_id, country, signup_date, devices, sessions, engaged_sessions,
               first_session_channel, first_order_channel, orders, revenue_usd,
               average_order_value_usd, first_order_date, last_order_date,
               recency_days, customer_age_days, r_score, f_score, m_score,
               rfm_score, rfm_segment, probability_alive, expected_purchases_90d,
               expected_order_value_usd, clv_12m_usd, clv_tier
        from `{MARTS}.mart_customer_360`
        order by customer_id
    """,
}


def main():
    client = bigquery.Client(project=PROJECT_ID, location=LOCATION)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, sql in EXTRACTS.items():
        df = client.query(sql).to_dataframe()
        path = OUT_DIR / name
        df.to_csv(path, index=False)
        print(f"  wrote {path.name}: {len(df)} rows")

    # reconciliation check printed with the export
    customers = client.query(
        f"select count(*) as n, sum(revenue_usd) as revenue from `{MARTS}.mart_customer_360`"
    ).to_dataframe().iloc[0]
    print(f"Check: customers {customers['n']}, revenue {float(customers['revenue']):,.2f} USD")


if __name__ == "__main__":
    main()
