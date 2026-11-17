# Limitations, Anomalies and Open Items

What the report cannot show, what is unusual in the source data, and what could be added later.
Stating these openly is part of the design: a number is only trustworthy when its limits are known.

Decision IDs refer to [`decision_log.md`](decision_log.md). Data quality checks that monitor
these items on every load are listed in [`architecture.md`](architecture.md#3-data-quality-checks).

---

## 1. Limitations of the source data

| Area | Limitation | Effect on the report | Decision |
|---|---|---|---|
| All | AdventureWorks is generated sample data; the two databases were generated separately | Finance and sales agree in total (about 6%) but not per organisation; they are never combined in one KPI | D40 |
| Dates | Sales, purchasing and production are on 2022-2025; HR and the DW were on older timelines | HR shifted +4,017 days, DW +4,170 days, both proven on matching records | D20, D21 |
| Dates | Each module ends on a different date (finance May 2025 to purchases October 2025) | Every KPI shows its own "as of" date | D24 |
| Finance | Budget exists only for May 2022 to April 2023 | Budget vs actual only for those months | – |
| Finance | No finance unit for the United Kingdom | The Europe view has UK sales but no UK finance | D72 |
| Finance | Exchange rates in the source are synthetic, not real-world rates | Converted amounts follow the source's rates | D36 |
| Finance | Converting assets and liabilities at month-end rates leaves a translation difference | The balance sheet does not balance exactly in USD; ratios within one unit are not affected | D36 |
| Finance | May 2025 has income statement rows but no asset rows (only 6 equity reclassification rows) | Balance sheet KPIs show April 2025 as their latest month | D39, D115 |
| HR | No termination dates; every employee is current | No attrition; headcount never falls (283 to 290 over the period) | D55 |
| HR | Leave hours and salaried flag exist only as today's values | Shown as current values, not as history | D62 |
| HR | No performance data for non-sales roles | No "top performing employees" view | D15 |
| Purchasing | No invoice data | Spend is measured at goods receipt using the order price | D42 |
| Purchasing | Vendor lead time exists only as today's value | Lead time comparisons use the current value | – |
| Purchasing | Weight is missing for 94% of purchased products | Freight is allocated by value, not weight | D44 |
| Purchasing | All 104 vendors are in the United States | No vendor country view | D67 |
| Production | 18 made components have no cost anywhere in the source | Scrap cost covers 21.4% of scrapped units and stays hidden; scrap rate is used | D46 |
| Inventory | 6.5% of stock units have no cost | Stock value shows its coverage (93.5%) | D53 |
| Inventory | No usable stock history (the DW snapshot disagrees with operations on every product) | No stock trend for now | D49, D54 |
| Sales | Every order ships in 7-8 days and none is late | Shipping KPIs exist but are hidden | D18 |
| Sales | Online customers never received a promotion | Discount analysis is about reseller sales | D66 |
| Sales | Online orders have no salesperson | Salesperson views cover reseller sales only | D59 |
| Sales | Sales start on 30 May 2022 and June 2025 holds only 47,492 of revenue (orders stop on 29 June) | 2023 growth against 2022 (+117%) compares a full year with 7 months; a trend ending in June 2025 drops; revenue per employee is low for 2022 and 2025. Pages show the as-of date and state part years | D24, D126 |
| Sales | Salesperson 282 sells in both Europe and North America | Salespeople cannot be filtered by one region; managers see all 17 names, figures only for their own region | D72, D132 |

---

## 2. Anomalies found in the source

Kept as they are (source data is never changed on suspicion) and documented.

| Anomaly | Count | Handling | Decision |
|---|---|---|---|
| Sales lines sold after the product's cost history ended (also after its sell end date) | 64 lines, 25 products | Last known cost, flagged `is_cost_estimated`; Microsoft's DW dropped exactly these lines | D26, D27 |
| Salesperson 284: first quota and territory one month before hire | 1 quota row | Nearest territory period | D21, D32 |
| Salesperson 280: territory history ends 2023-09-29, but sales in Northwest continue to 2025-04-30 | 6 quota rows | Nearest territory period (Northwest), confirmed by orders | D32 |
| Pay rate starting before the hire date | 2 employees | Harmless for "as of month-end" lookups | D55 |
| Lines on a discounted offer that received no discount | 2,151 lines | Discounts always from the line | D66 |
| Purchase lines due before their order date | 7 lines | Flagged and excluded from on-time measures | D45 |
| Pending and Approved purchase orders already holding received goods | Up to 534 lines | Spend measured by quantities, not status | D42 |
| Corporate finance rows equal to their children's total | 342 rows (0.9%) | Kept as Corporate's own data; would be confirmed with the finance team in a real company | D35 |
| Reorder point below safety stock for every product (opposite of the textbook rule) | All products | Each column used for its role in the source description | D51 |
| Product master standard cost 0 for internal parts | 200 products | Stored as NULL (unknown) | D60 |
| Two pairs of stores share a name | 2 names | Account number added to the label | D65 |
| Offer names contain old years (e.g. "Sport Helmet Discount-2002") | Several offers | Names kept as in the source | D66 |
| "Paint Shop" behaves as storage (no cost rate, no hours, no routing) | 1 location | Classified by data, not by name | D50 |
| Helper function `ufnGetStock` counts only one storage location | 1 function | Not used | D51 |
| Old European currencies (DEM, FRF) on some orders | 135 lines | No effect: amounts are stored in USD | D36 |
| DW territory table has an "NA" row | 1 row | Recognised as an unknown member | D61 |

---

## 3. Limitations of the solution

| Limitation | Why | Decision |
|---|---|---|
| Row-level security does not protect the .pbix file itself | Security is enforced when content is shared through the Power BI Service, which is not used | D11, D74 |
| Refresh is shown in Power BI Desktop, not scheduled in the Power BI Service | Service not mandatory for the internship | D11 |
| Facts are fully reloaded rather than loaded incrementally | Volumes are small | D76 |
| Internal parts are valued at last purchase price, not weighted average cost | Simpler; weighted average needs full movement history | D53 |
| HR data is hidden from regional managers; supply chain data (except inventory) is head-office only | The source has no region for these modules | D72 |
| Staging tables are copied one after another, not as one consistent snapshot | Changing the source's isolation settings was out of scope; an orphan-line check covers the risk | D82 |
| The Power BI connection to SQL Server is not encrypted | The laptop's SQL Server uses a self-signed certificate; on one machine no data crosses a network. A server on a network would get a trusted certificate | D121 |
| Revenue in Power BI differs from SQL by 0.000001 | Floating point addition of 121,317 values; all money is shown and reconciled to the cent | D120 |
| Power BI Desktop projects (.pbip) are marked as preview by Microsoft | Used for readable version control; the .pbix for submission is saved from the project | D131 |
| The scheduled load runs late when the laptop is asleep, and a load in progress pauses while it sleeps | SQL Server Agent runs on this laptop. A job that falls due during sleep runs when the laptop wakes: the runs of 12, 14 and 15 Nov each started within a minute of a wake in the Windows power log. Batch 5082 started at 03:34 on 15 Nov, the laptop slept seconds later and woke at 15:51, and the batch finished 22 s after that, so its 44,269 s are almost all sleep. On a server that stays on, the job runs at its scheduled time. The demo starts the job manually | D09, D78 |
| Power BI Desktop has no page-level security: pages for executives are visible to every user, with their figures hidden and a message shown | The standard alternative, separate reports shown through Power BI app audiences, needs the Service | D11, D134 |
| The age band on the HR page is the employee's age on 2025-10-31, so the age chart is the same for every year | Age band is a current attribute of `dim_employee_hr`, not a monthly snapshot; birth date is not stored | D62, D137 |
| The three product count cards (to reorder, below minimum, OK) show 0 rather than blank for a user not in the security table | The count measures add 0 so that an empty category shows 0; no product data is shown | D73 |
| Executive Overview shows blank cards ("--") to regional managers for headcount, OTIF and revenue per employee, without a message | The page is mainly for every user; a message would cover visible figures | D72, D134 |

---

## 4. Open items and possible extensions

| Item | Value | Status |
|---|---|---|
| Stock trend (P5) rebuilt from OLTP transaction history | Trend that agrees with current stock by construction | Optional, after Must items |
| Planned vs actual production cost from `WorkOrderRouting` | Production efficiency KPI | Optional, end of project |
| Local currency selector on finance pages | Local managers see their own currency | Should |
| Org chart from `manager_key` | Management structure view | Should |
| Days to ship vs promised lead time (vendors) | Vendor reliability | Should |
| Landed cost (spend + freight) | Full purchase cost | Should |
| Line fill rate, average days late (production) | Extra supply chain detail | Should |
| "Constant currency" growth | Growth without exchange-rate effects | Next step (presentation) |
| Incremental loading by `ModifiedDate` | Needed if volumes grow | Next step |
| Azure Data Factory pipeline calling the same procedures | Cloud orchestration | Optional |
| Weighted average costing for internal parts | Closer to accounting practice | Next step |
