# Test Results

All checks run on 19 November 2026 against BigQuery project `da02-customer360-515112`. Every expected value comes from an independent query on the source data, not from the model being tested.

## 1. Automated tests (dbt)

| Run | Result |
|---|---|
| `dbt test --select "source:*"` (raw tables) | PASS=18 ERROR=0 |
| `dbt build --exclude tag:clv` (all models except CLV) | PASS=93 ERROR=0 (14 models, 1 seed, 78 tests) |
| `dbt build --select tag:clv` (CLV staging and Customer 360) | PASS=14 ERROR=0 |

The project has 90 data tests. Main ones:

| Test | What it proves |
|---|---|
| `unique` / `not_null` on every key | No duplicate or missing customers, orders, sessions or cost days |
| `relationships` | Every order has a customer; every affiliate commission has an order; every CLV row has a customer |
| `unique_int_identity__device_customers_user_pseudo_id` | A device is never linked to two customers |
| `accepted_values` on `channel` and `rfm_segment` | Only GA4 channel names and the ten RFM segments appear |
| `accepted_range` on `probability_alive` (0–1) and `clv_12m_usd` (≥ 0) | Model outputs are valid |
| `equal_rowcount` `mart_customer_360` vs `dim_customers` | Every customer has a CLV |
| `assert_attribution_credits_sum_to_one` | Each model gives exactly 1 credit per order |
| `assert_every_order_is_attributed` | All 4,451 orders have at least one touchpoint |
| `assert_revenue_reconciles` | CRM, `fct_orders` and all four models total the same revenue, to the cent |

## 2. Raw and staging data against the GA4 sample

| Check | Expected (GA4 profiling) | Result |
|---|---|---|
| Events in `stg_ga4__events` | 4,295,584 | 4,295,584 |
| Sessions | 360,129 | 360,129 |
| Distinct valid transactions | 4,451 | 4,451 |
| CRM orders and revenue | 4,451, $308,200.00 | 4,451, $308,200.00 |
| Orders shared by two devices | 15 orders, 30 distinct devices (query) | 15 accounts with 2 linked devices |
| Repeat customers, most orders | 439 devices with repeat orders, up to 16 | 439, 16 |
| Paid search clicks and cost | 7,672 cpc sessions × $2.61 | 7,672, $20,023.92 |
| Affiliate orders | 2 (orders by purchase-session medium) | 2, commission $14.03 = $167 × 8.4% |
| Email invoices | Nov, Dec, Jan × $100 | 3, $300 |

## 3. Sessions, channels and identity

| Check | Expected | Result |
|---|---|---|
| Sessions by channel total | 360,129 | 360,129 |
| Direct | 37,786 `(direct)/(none)` sessions | 37,786 |
| Paid Search | 7,672 `google/cpc` | 7,672 |
| Affiliates | 1,329 `Partners/affiliate` | 1,329 |
| Email | 106 + 55 + 32 newsletter sessions | 193 |
| Unassigned | 94,554 + 25,327 + 6,343 + 100 | 126,324 |
| Customers in identity map | 3,698 | 3,698 |
| Devices | 3,698 + 15 second devices | 3,713 |

## 4. Attribution and channel performance

| Check | Expected | Result |
|---|---|---|
| Revenue per model | $308,200 each | $308,200 each; Tableau model comparison $1,232,800 = 4 × $308,200 |
| Affiliates, last touch | Commission report: $14.03 ÷ 8.4% = $167 | 2 orders, $167 |
| Email, last touch | 20 orders with an email purchase session | 20 orders |
| Paid Search, last touch | 43 orders with a cpc purchase session, plus orders whose purchase session was direct after a paid search visit (GA4 direct rule) | 44 orders |

## 5. CLV model

| Check | Result |
|---|---|
| Orders, customers, revenue read | 4,451, 3,698, $308,200.00 |
| Holdout (fit to 2020-12-31, predict January 2021; actual 48 repeat purchases) | BG/NBD 110.8 (error 62.8, 0.053 per customer); Modified BG/NBD 95.6 (error 47.6, 0.048 per customer); Modified BG/NBD chosen |
| Gamma-Gamma assumption (frequency vs order value) | Correlation −0.054 |
| Output rows | 3,698 |

## 6. Tableau extracts

| Check | Result |
|---|---|
| `channel_performance.csv` | 36 rows (9 channels × 4 models) |
| `customer_360.csv` | 3,698 rows, revenue $308,200.00 |
| Revenue by channel sheet, last touch | Total $308,200 |
