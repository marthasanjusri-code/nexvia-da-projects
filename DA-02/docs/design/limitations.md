# Limitations and Next Steps

What the platform cannot show, what is unusual in the data, and what could be added later. Decision IDs refer to [`decision_log.md`](decision_log.md).

---

## 1. Source data

| Area | Limitation | Effect | Decision |
|---|---|---|---|
| GA4 sample | Google obfuscated the public sample: some values are replaced by `<Other>` or `(data deleted)`, paid search campaign names are hidden, and click IDs (`gclid`, `dclid`) are empty | Those sessions fall to Unassigned; paid search cannot be split by campaign | D17, D18 |
| GA4 sample | 94,554 sessions (26%) carry no source or medium on any event | With the obfuscated values, 126,324 sessions (35%) are Unassigned; Unassigned still receives attribution credit | D16, D18 |
| GA4 sample | `user_id` is empty, so there is no login to link devices | Only devices that bought can be linked to a customer: 3,713 of 270,154 devices. Paths before a first purchase on another, never-buying device are not seen | D14 |
| GA4 sample | Only 92 days (1 Nov 2020 to 31 Jan 2021), including Black Friday and Christmas | The 90-day lookback covers almost the whole history; the CLV model sees one peak season and one quiet month | D21, D32 |
| CRM | Names, emails and signup dates are synthetic | Signup date is not used in any measure; customer counts, orders and revenue are real | D11 |
| Costs | Costs are benchmarks, not the store's real spend; the paid search CPC is from 2024 while the data is from 2020–21 | ROAS, ROI and CPA show the method and the relative picture; real cost reports would replace the raw tables without model changes | D12 |
| Costs | No product margin | ROI is on revenue, so it overstates profit for every channel equally | D26 |
| Affiliates | Only 2 affiliate orders | Affiliate ROAS (1.64 to 11.90 depending on model) is not reliable | – |

## 2. Methods

| Area | Limitation | Next step |
|---|---|---|
| Attribution | The four models are rules; none measures what would have happened without a channel | Data-driven attribution (Markov chain or Shapley value) and a holdout test for paid search |
| Attribution | Only sessions count as touchpoints; email opens and ad views are not in the data | Add email platform and ad platform event data when available |
| Identity | Deterministic matching on orders only | With a login or CRM email on events, link devices before the first purchase |
| RFM | Frequency uses fixed bands because 88% of customers bought once | Revisit bands with a full year of data |
| Platform | BigQuery Sandbox: tables expire after 60 days, no scheduled queries or incremental models | With billing: incremental models, scheduled `dbt build` (dbt Cloud, Cloud Composer or GitHub Actions), source freshness checks |
| Platform | dbt 1.12 | Upgrade to dbt v2 when stable for the project's packages |

## 3. CLV model

| Limitation | Evidence | How it is used |
|---|---|---|
| The model over-predicts. Trained on November and December 2020, it predicted 95.6 repeat purchases for January 2021 against 48 actual | Holdout validation in `predict_clv.py` output | CLV is shown as tiers to rank customers, not as a dollar forecast (D34) |
| Cause: purchase rates in the training months include Black Friday and Christmas, and January is the post-holiday dip. Buy-till-you-die models assume a steady purchase rate | Seasonal peak in the training window | Retrain on at least 12 months of data, or add seasonality |
| Predicted 12-month CLV is low (total $13,709, median $3.06) because the model estimates most customers stop after a purchase (88% bought once) | Modified BG/NBD parameters | Read together with RFM segments |
