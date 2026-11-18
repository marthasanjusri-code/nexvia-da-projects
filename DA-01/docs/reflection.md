# Reflection: DA-01 Enterprise BI Suite

Sanju Sri Martha, Nexvia Data Analytics Internship, November 2026

## What I owned

I owned the project from start to finish:

- I wrote the 32 business questions first, so that every table and measure had a reason to exist.
- I built the warehouse in SQL Server: staging, a star schema with 7 facts and 17 dimensions, and one pipeline that runs every night as a single all-or-nothing transaction with 27 data quality checks.
- In Power BI I built the model, the DAX measures, the dynamic row-level security, seven report pages and a drill-through page.
- I tested every figure against SQL, recorded each decision with its reason, and made every commit to the repository myself.

## What I learned

**Writing down the questions and decisions first saves time later.** When a number looked wrong, the decision log told me why it was built that way, and I could fix the cause instead of guessing.

**Security changes more than who sees what.** When I tested the report as a regional manager, days of stock cover showed 799 instead of 639. Row-level security had cut the sales figures but not the stock. I learned that DAX cannot remove a security filter, and that the standard fix is a summary table calculated at refresh. I also learned that Power BI has no page-level security, so I showed a clear message on executive pages while row-level security kept the data hidden.

**Testing beats assuming.** I compared each figure with a SQL query before I trusted it. This found real errors, such as a quota check that counted one date twice, and margin ranges calculated on the wrong basis. I corrected them and recorded why.

**Real environments have limits.** A scheduled job on a laptop runs late when the laptop sleeps, and a power cut in the middle of a commit broke my git branch. I traced the first through the Windows event log and repaired the second without losing work. Since then I commit and push after every step.

## What I would do differently

- **Plan the report pages with the warehouse.** I designed the drill-through page and the restricted-page messages late, after testing showed the need. Sketching every page and every user's view at the start would have surfaced them earlier.
- **Test security on every measure, not only on tables.** The days of stock cover issue only appeared when I viewed the report as a regional manager. I would now run that check on each measure as I write it.
- **Use a machine that stays on for scheduled work.** Running the pipeline on a laptop caused late runs and a power cut during a commit. A small server, or the Power BI Service with scheduled refresh, would have avoided both.

## Next steps for the project

- Publish to the Power BI Service and run the pipeline on an always-on server.
- Load data incrementally as volumes grow.
- Answer the remaining Should questions listed in the report guide.
