"""
generate_synthetic_data.py

Creates the synthetic CRM and marketing-cost source tables for DA-02 and
loads them into BigQuery as raw data. dbt then reads them as sources.

Why load raw tables instead of dbt seeds: dbt's documentation says seeds
should not be used to load raw data; they are for small static reference
lists. A load job into a raw dataset is the standard ELT pattern.

What is real and what is synthetic
  Real (read from the GA4 sample):
    - every order: transaction_id, date, revenue, purchasing device(s), country
    - which devices share an order (they become one CRM customer)
    - paid search clicks per day (cpc sessions)
    - which orders came from an affiliate session
    - number of CRM contacts (drives the email platform price tier)
  Synthetic:
    - customer names, @example.com emails, signup dates (Faker)
    - costs, priced with published benchmarks (see COST_ASSUMPTIONS)

Tables written (all replaced on every run):
  raw_crm.customers
  raw_crm.orders
  raw_marketing.google_ads_daily_cost     cost report per day, like a Google Ads export
  raw_marketing.affiliate_commissions     commission per order, like an affiliate network report
  raw_marketing.esp_monthly_invoices      monthly bill of the email service provider

Run from DA-02 with the venv active:
  python scripts/generate_synthetic_data.py
"""

import random
import re
from datetime import date, timedelta

import pandas as pd
from faker import Faker
from google.cloud import bigquery

PROJECT_ID = "da02-customer360-515112"
LOCATION = "US"  # same location as the GA4 public dataset
GA4_TABLE = "bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*"
SEED = 42  # fixed seed: every run produces the same synthetic values

# Published benchmarks used to price the synthetic costs.
COST_ASSUMPTIONS = {
    # Average search CPC, category "Shopping, Collectibles & Gifts",
    # WordStream by LocaliQ search advertising benchmarks 2024.
    "paid_search_cpc_usd": 2.61,
    # Average ecommerce affiliate commission (cost per sale), 8.4% of order
    # value (2026 benchmark); retail programs typically pay 3-10% (impact.com).
    "affiliate_commission_rate": 0.084,
    # Mailchimp Standard plan list price for up to 5,000 contacts (2026).
    "esp_provider": "Mailchimp",
    "esp_plan": "Standard",
    "esp_contact_tier": 5000,
    "esp_monthly_price_usd": 100.00,
}

# Session source = the first event in a session that carries a medium.
# session_start events carry none in this export, so later events are used.
SESSION_SOURCE_CTE = f"""
ev AS (
  SELECT
    user_pseudo_id, event_timestamp,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'medium') AS medium,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'campaign') AS campaign
  FROM `{GA4_TABLE}`
),
session_source AS (
  SELECT
    user_pseudo_id, ga_session_id,
    ARRAY_AGG(STRUCT(event_date, medium, campaign) ORDER BY event_timestamp LIMIT 1)[OFFSET(0)] AS s
  FROM ev
  WHERE medium IS NOT NULL
  GROUP BY 1, 2
)
"""

ORDERS_SQL = f"""
WITH {SESSION_SOURCE_CTE},
purchases AS (
  SELECT
    ecommerce.transaction_id AS transaction_id,
    user_pseudo_id, event_timestamp, geo.country AS country,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
    ecommerce.purchase_revenue_in_usd AS revenue_usd
  FROM `{GA4_TABLE}`
  WHERE event_name = 'purchase'
    AND ecommerce.transaction_id IS NOT NULL
    AND ecommerce.transaction_id != '(not set)'
)
SELECT
  p.transaction_id,
  ARRAY_AGG(DISTINCT p.user_pseudo_id) AS devices,
  ARRAY_AGG(p.user_pseudo_id ORDER BY p.event_timestamp LIMIT 1)[OFFSET(0)] AS first_device,
  ARRAY_AGG(p.country ORDER BY p.event_timestamp LIMIT 1)[OFFSET(0)] AS country,
  MIN(p.event_date) AS order_date,
  MAX(p.revenue_usd) AS revenue_usd,
  ARRAY_AGG(ss.s.medium ORDER BY p.event_timestamp LIMIT 1)[OFFSET(0)] AS purchase_session_medium,
  ARRAY_AGG(ss.s.campaign ORDER BY p.event_timestamp LIMIT 1)[OFFSET(0)] AS purchase_session_campaign
FROM purchases AS p
LEFT JOIN session_source AS ss
  ON ss.user_pseudo_id = p.user_pseudo_id AND ss.ga_session_id = p.ga_session_id
GROUP BY 1
"""

PAID_SEARCH_CLICKS_SQL = f"""
WITH {SESSION_SOURCE_CTE}
SELECT s.event_date AS date, COUNT(*) AS clicks
FROM session_source
WHERE s.medium = 'cpc'
GROUP BY 1
ORDER BY 1
"""


def build_customers(orders: pd.DataFrame) -> dict:
    """Group devices that share an order into one customer (union-find).

    A CRM customer is one account. Devices that placed the same order belong
    to the same account. Every other device is its own customer.
    Returns {device: customer_key}.
    """
    parent = {}

    def find(x):
        parent.setdefault(x, x)
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[max(ra, rb)] = min(ra, rb)

    for devices in orders["devices"]:
        devices = list(devices)
        find(devices[0])
        for other in devices[1:]:
            union(devices[0], other)
    return {device: find(device) for device in parent}


def make_customers(orders: pd.DataFrame, fake: Faker) -> tuple[pd.DataFrame, dict]:
    device_to_key = build_customers(orders)
    orders["customer_key"] = orders["first_device"].map(device_to_key)
    first = (
        orders.sort_values(["order_date", "transaction_id"])
        .groupby("customer_key")
        .agg(first_order_date=("order_date", "min"), country=("country", "first"))
        .reset_index()
        .sort_values(["first_order_date", "customer_key"])
        .reset_index(drop=True)
    )
    first["customer_id"] = [f"C{n:05d}" for n in range(1, len(first) + 1)]

    rows = []
    for r in first.itertuples(index=False):
        first_name, last_name = fake.first_name(), fake.last_name()
        # example.com is reserved for examples, so no real address is used.
        local = re.sub(r"[^a-z.]", "", f"{first_name}.{last_name}".lower())
        rows.append(
            {
                "customer_id": r.customer_id,
                "first_name": first_name,
                "last_name": last_name,
                "email": f"{local}.{r.customer_id.lower()}@example.com",
                "country": r.country,
                "signup_date": r.first_order_date - timedelta(days=random.randint(0, 365)),
            }
        )
    return pd.DataFrame(rows), dict(zip(first["customer_key"], first["customer_id"]))


def month_starts(first: date, last: date) -> list[date]:
    months, d = [], date(first.year, first.month, 1)
    while d <= last:
        months.append(d)
        d = date(d.year + (d.month == 12), d.month % 12 + 1, 1)
    return months


def load(client: bigquery.Client, df: pd.DataFrame, table: str) -> None:
    dataset = table.split(".")[0]
    client.create_dataset(bigquery.Dataset(f"{PROJECT_ID}.{dataset}"), exists_ok=True)
    job = client.load_table_from_dataframe(
        df,
        f"{PROJECT_ID}.{table}",
        job_config=bigquery.LoadJobConfig(write_disposition="WRITE_TRUNCATE"),
    )
    job.result()
    print(f"  loaded {table}: {job.output_rows} rows")


def main():
    random.seed(SEED)
    Faker.seed(SEED)
    fake = Faker("en_US")
    client = bigquery.Client(project=PROJECT_ID, location=LOCATION)

    orders = client.query(ORDERS_SQL).to_dataframe()
    clicks = client.query(PAID_SEARCH_CLICKS_SQL).to_dataframe()
    # BigQuery DATE columns arrive as a special pandas type; use plain dates.
    orders["order_date"] = pd.to_datetime(orders["order_date"]).dt.date
    clicks["date"] = pd.to_datetime(clicks["date"]).dt.date
    print(f"GA4 orders read: {len(orders)}, revenue {orders['revenue_usd'].sum():,.2f} USD")

    # CRM ------------------------------------------------------------------
    customers, key_to_id = make_customers(orders, fake)
    crm_orders = pd.DataFrame(
        {
            "order_id": orders["transaction_id"].astype(str),
            "customer_id": orders["customer_key"].map(key_to_id),
            "order_date": orders["order_date"],
            "order_total_usd": orders["revenue_usd"].round(2),
            "order_status": "completed",
        }
    ).sort_values(["order_date", "order_id"])

    # Google Ads daily cost report -------------------------------------------
    cpc = COST_ASSUMPTIONS["paid_search_cpc_usd"]
    google_ads = pd.DataFrame(
        {
            "date": clicks["date"],
            "campaign_name": "Google Merchandise Store - Search",
            "clicks": clicks["clicks"].astype(int),
            "cost_usd": (clicks["clicks"] * cpc).round(2),
        }
    )

    # Affiliate network commission report ------------------------------------
    rate = COST_ASSUMPTIONS["affiliate_commission_rate"]
    aff = orders[orders["purchase_session_medium"] == "affiliate"]
    affiliate = pd.DataFrame(
        {
            "order_id": aff["transaction_id"].astype(str),
            "order_date": aff["order_date"],
            "campaign": aff["purchase_session_campaign"],
            "sale_amount_usd": aff["revenue_usd"].round(2),
            "commission_rate": rate,
            "commission_usd": (aff["revenue_usd"] * rate).round(2),
        }
    )

    # Email service provider monthly invoices --------------------------------
    if len(customers) > COST_ASSUMPTIONS["esp_contact_tier"]:
        raise ValueError("CRM contacts exceed the priced email plan tier")
    esp = pd.DataFrame(
        {
            "invoice_month": month_starts(orders["order_date"].min(), orders["order_date"].max()),
            "provider": COST_ASSUMPTIONS["esp_provider"],
            "plan": COST_ASSUMPTIONS["esp_plan"],
            "contacts": len(customers),
            "amount_usd": COST_ASSUMPTIONS["esp_monthly_price_usd"],
        }
    )

    # Load ---------------------------------------------------------------------
    print("Loading into BigQuery:")
    load(client, customers, "raw_crm.customers")
    load(client, crm_orders, "raw_crm.orders")
    load(client, google_ads, "raw_marketing.google_ads_daily_cost")
    load(client, affiliate, "raw_marketing.affiliate_commissions")
    load(client, esp, "raw_marketing.esp_monthly_invoices")

    linked = pd.Series(build_customers(orders)).value_counts()
    orders_per_customer = crm_orders.groupby("customer_id").size()
    print("Checks:")
    print(f"  customers: {len(customers)} (accounts with 2+ linked devices: {int((linked > 1).sum())})")
    print(f"  repeat customers (2+ orders): {int((orders_per_customer > 1).sum())}, "
          f"most orders by one customer: {int(orders_per_customer.max())}")
    print(f"  orders: {len(crm_orders)}, revenue {crm_orders['order_total_usd'].sum():,.2f} USD")
    print(f"  paid search: {google_ads['clicks'].sum()} clicks, {google_ads['cost_usd'].sum():,.2f} USD")
    print(f"  affiliate: {len(affiliate)} orders, {affiliate['commission_usd'].sum():,.2f} USD commission")
    print(f"  email platform: {len(esp)} invoices, {esp['amount_usd'].sum():,.2f} USD")


if __name__ == "__main__":
    main()
