# Decision Log

Every design decision for the Customer 360 and Marketing Attribution Platform, with the reason and the evidence behind it. Query results quoted here were run on the GA4 sample or on the built models; test names refer to the dbt project in `customer360/`.

---

## 1. Platform and tools

| ID | Decision | Reason | Evidence |
|---|---|---|---|
| D01 | BigQuery Sandbox, project `da02-customer360-515112`, location US | Free, no billing account. The GA4 sample is in the US multi-region, so the project data sits in the same location. Sandbox limits: no DML, tables expire after 60 days, 1 TB of queries a month | All loads use load jobs and all models are views or tables (no incremental models) |
| D02 | dbt-core 1.12 with dbt-bigquery 1.12, not dbt v2 | 1.12 is the stable line and supports Python 3.14; v2 was new. Upgrade is a next step | `requirements.txt` |
| D03 | Authentication by gcloud Application Default Credentials (OAuth) | No service account keys to store; `profiles.yml` lives in the user's home folder and `*.keyfile.json` and `profiles.yml` are git-ignored | `.gitignore` |
| D04 | Read the GA4 sample in place through the wildcard `events_*` | No copy needed; 4,295,584 events over 92 days | `_ga4__sources.yml`; staging reconciliation (test results, section 2) |
| D05 | Raw CRM and cost data loaded as BigQuery tables and read as dbt sources, not dbt seeds | dbt's documentation says seeds are not for loading raw data; seeds are kept for static reference lists (D12) | `scripts/generate_synthetic_data.py` |
| D06 | dbt project structure from dbt's guide: staging views (one per source table, `stg_[source]__[entity]s`), intermediate tables, marts tables; one `_[dir]__sources.yml` and `_[dir]__models.yml` per folder | Standard layout, so any dbt user can find things; staging is the only layer that uses `source()` | `dbt_project.yml`, `models/` |
| D07 | dbt_utils 1.4.x (dbt Labs) for surrogate keys and generic tests; `package-lock.yml` committed | Standard package; the lock file pins the installed version | `packages.yml`, `package-lock.yml` |
| D08 | The Velir dbt-ga4 package is not installed; its patterns are followed | Its base model is incremental with `insert_overwrite`, which runs a MERGE, and the Sandbox does not allow DML. Patterns used: flatten `event_params`, session key from `user_pseudo_id` + `ga_session_id` | `stg_ga4__events.sql` |
| D09 | Money stored as NUMERIC | Exact decimals, so totals reconcile to the cent | Staging casts; `assert_revenue_reconciles` |

## 2. Data

| ID | Decision | Reason | Evidence |
|---|---|---|---|
| D10 | CRM orders are the real GA4 transactions, one row per `transaction_id`; null and `(not set)` IDs excluded; revenue is the transaction's purchase revenue once | 5,692 purchase events but 4,452 distinct IDs (GA4 resends some purchases). 2 groups have no valid ID. Raw sum $362,165 would double count | 4,451 orders, $308,200 (generator output, `assert_revenue_reconciles`) |
| D11 | Customer attributes are synthetic: Faker names, `@example.com` emails, fixed seed 42; country from GA4; signup date 0–365 days before the first order | The brief asks for a synthetic CRM; real behaviour stays real. Fixed seed makes reruns identical | `generate_synthetic_data.py` |
| D12 | Costs priced the way each channel bills, from cited benchmarks: paid search $2.61 per click (WordStream/LocaliQ 2024, Shopping, Collectibles & Gifts) on the real paid search sessions; affiliates 8.4% of sale (2026 ecommerce average; Impact.com retail range 3–10%) on the real affiliate orders; email Mailchimp Standard $100 a month (up to 5,000 contacts) | Invented numbers would make ROI meaningless; benchmarks can be checked | 7,672 clicks × $2.61 = $20,023.92; $167 × 8.4% = $14.03; 3 × $100 |
| D13 | Personal fields (names, emails, device IDs) are not exported to Tableau | A Tableau Public workbook is visible to anyone | `export_tableau_extracts.py` |

## 3. Sessions, channels and identity

| ID | Decision | Reason | Evidence |
|---|---|---|---|
| D14 | Identity resolution is deterministic only: a GA4 device is linked to a CRM customer when its purchase `transaction_id` equals a CRM `order_id`. Devices that share an order belong to one customer. No probabilistic matching. In production this is the role of Segment's identity resolution | `user_id` is empty in the sample, so orders are the only shared identifier. Deterministic matching cannot merge two different people by guesswork | 15 orders placed from 2 devices (30 distinct device IDs); 3,713 devices → 3,698 customers; `unique_int_identity__device_customers_user_pseudo_id` |
| D15 | Session = `user_pseudo_id` + `ga_session_id` | GA4's session definition; `ga_session_id` is on every event | 4,295,584 of 4,295,584 events have it; 360,129 sessions |
| D16 | Session traffic source = the first event in the session that has a medium | In this export, source, medium and campaign are on page_view and other events, not on session_start | Profiling: 265,575 sessions have a medium, 94,554 have none |
| D17 | Channel = GA4 default channel group, Google's rules for manually tagged traffic, checked in Google's order; Google's source category list (820 sources) as a dbt seed, taken from the Velir dbt-ga4 package (MIT); inputs lowercased | Google's definition is the industry standard and makes the channels comparable with GA4 reports | `macros/default_channel_grouping.sql`; every channel total matches the source/medium counts (test results, section 3) |
| D18 | A session with no source and no medium is Unassigned, not Direct | Google's Direct rule needs source `(direct)`; Velir maps it to Direct. Following Google keeps Direct to real direct visits | 126,324 Unassigned = 94,554 no medium + 31,770 `<Other>`/`(data deleted)` |
| D19 | `session_engaged` read from both its string and integer values | Profiling: 3,682,921 string values and 313,391 integer values; actual values are only '1' and '0' | Staging reconciliation query |

## 4. Attribution, ROI and CPA

| ID | Decision | Reason | Evidence |
|---|---|---|---|
| D20 | Four rule-based models: first touch, last touch, linear, time decay | The brief asks for them; GA4 now offers only last click and data-driven, so they are built in SQL | `fct_attribution.sql` |
| D21 | Lookback 90 days | GA4's default for key events other than first_visit and first_open | `attribution_lookback_days` in `dbt_project.yml` |
| D22 | Direct visits get credit only when the whole path is direct | GA4 rule for all attribution models | `int_attribution__touchpoints.sql` |
| D23 | Time decay weight 2^(−days before order / 7) | Google's time decay half-life of 7 days | `time_decay_half_life_days` |
| D24 | Touchpoints include sessions on every device of the customer | This is the point of identity resolution: cross-device paths | `int_attribution__touchpoints.sql` |
| D25 | Order time = the first purchase event for that transaction | Some orders were sent more than once or from two devices | `int_orders__purchase_events.sql` |
| D26 | ROAS = revenue ÷ cost; ROI = (revenue − cost) ÷ cost; CPA = cost ÷ conversions; cost only for the three paid channels | Standard definitions. ROI is on revenue because no product margin is available | `mart_channel_performance.sql` |

## 5. RFM and CLV

| ID | Decision | Reason | Evidence |
|---|---|---|---|
| D27 | Recency and Monetary scored 1–5 by quintile using percent rank | Equal values get equal scores (NTILE would split ties at random) | `dim_customers.sql` |
| D28 | Frequency scored by fixed bands: 1, 2, 3, 4–5, 6+ orders | 3,259 of 3,698 customers (88%) have one order, so quintiles cannot separate them | Orders per customer: 3,259 / 301 / 76 / 34 / 28 |
| D29 | Segments from the standard recency × frequency map (Champions, Loyal Customers, Potential Loyalists, New Customers, Promising, Need Attention, About to Sleep, At Risk, Cannot Lose Them, Hibernating) | Widely used, readable names | `accepted_values` test on `rfm_segment` |
| D30 | Analysis date fixed at 2021-02-01 (dbt variable) | The data is historical; `current_date` would make every customer look lost | `as_of_date` in `dbt_project.yml` |
| D31 | CLV in Python with PyMC-Marketing: a transaction model plus Gamma-Gamma for order value; MAP fit; 12 months; 1% monthly discount | Standard "buy till you die" models; the older lifetimes package is no longer maintained; 1% a month is the common default | `scripts/predict_clv.py` |
| D32 | Transaction model chosen by holdout: fit on Nov–Dec 2020, predict January 2021, keep the model with the smaller total error. Modified BG/NBD chosen | In BG/NBD a customer can only drop out after a repeat purchase, so every one-time buyer is "alive" with probability 1; Modified BG/NBD (Batislam et al., 2007) allows drop out after the first purchase. The holdout decides, not preference | Actual 48 repeat purchases; BG/NBD 110.8 (error 62.8), Modified BG/NBD 95.6 (error 47.6) |
| D33 | Gamma-Gamma assumption checked | It assumes order value does not depend on purchase frequency | Correlation −0.054 |
| D34 | CLV used as tiers for ranking, not as a dollar forecast | The model still over-predicts the holdout about two times (D32) | Limitations, section 3 |
| D35 | CLV output loaded to `ml_clv.customer_clv` and read by dbt as a source; the models that use it are tagged `clv` | The usual pattern for model outputs; the tag gives a clear run order | `_ml__sources.yml`, README run steps |

| D39 | `fct_sessions` mart: every session with its channel and the `customer_id` from identity resolution (null for anonymous sessions) | The brief asks for a sessions model that links sessions and customers | `relationships` test to `dim_customers` |
| D40 | Campaign cost: affiliates exact (campaign on each commission row); paid search and email monthly cost shared across the channel's campaigns by their sessions in that month | The Google Ads report is daily and the email invoice monthly, with no campaign split; activity-based allocation is the standard way to share a common cost. Paid search campaign names are hidden in the sample (`<other>`) | `assert_campaign_cost_reconciles`: Email $300.01 vs $300 (cent rounding), Paid Search $20,023.92 |

## 6. Reporting

| ID | Decision | Reason | Evidence |
|---|---|---|---|
| D36 | Tableau Public with CSV extracts of the marts, exported by a script | Tableau Public cannot connect to BigQuery; the script keeps the extracts repeatable and all logic stays in dbt | `export_tableau_extracts.py`; export check 3,698 customers, $308,200 |
| D37 | Every channel chart shows one attribution model at a time (dropdown) or all four side by side | Each extract row is one channel under one model; summing models would count revenue four times | Model comparison sheet totals $1,232,800 = 4 × $308,200 |
| D38 | Workbook kept as a packaged `.twbx` in the repository and published to Tableau Public | The file is version-controlled with the code; Tableau Public gives the shareable link | `tableau/Customer360_Attribution.twbx` |

## 7. Engineering

| ID | Decision | Reason | Evidence |
|---|---|---|---|
| D41 | GitHub Actions CI without cloud credentials: compile the scripts, `dbt deps`, `dbt parse` on every push that changes DA-02 | Catches broken models, references and YAML before review, with no keys stored in GitHub. Running models and data tests in CI needs warehouse access; the keyless way is Workload Identity Federation (next step) | `.github/workflows/da02-ci.yml`; Actions tab |
