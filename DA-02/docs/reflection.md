# Reflection: DA-02 Customer 360 and Marketing Attribution

**Sanju Sri Martha · November 2026**

## What I built

I built a Customer 360 and marketing attribution platform on the public GA4 sample from the Google Merchandise Store. The data sits in BigQuery, dbt turns it into sessions, orders and customer profiles, Python predicts customer lifetime value, and three Tableau Public dashboards show the results with budget recommendations. The main finding was clear: email is the most efficient paid channel, while paid search takes almost all of the paid budget and returns only 15 to 27 cents per dollar.

## What went well

Checking every number paid off. Before building each layer, I ran a query on the raw GA4 data to know what the answer should be, and then compared the model against it. Because of that, revenue matches to the cent in the CRM, the orders table and all four attribution models, and I could trust the dashboards.

I also learned to make decisions with evidence instead of preference. For the channel groups I used Google's own rules, and for customer lifetime value I tested two models on a holdout month and kept the one with the smaller error.

## What was hard

The data had surprises. Traffic source was not on the session start event, a quarter of sessions had no source at all, and GA4 sent some purchases more than once. Most customers (88%) bought only once, which broke the usual way of scoring RFM frequency and made the first lifetime value model think every one-time buyer was still active.

The free BigQuery Sandbox also had limits, such as no updates to tables, so I could not use the standard GA4 dbt package and had to build those models myself.

## What I would do differently

I would profile the data even more at the start, before writing the data generator, because I had to rebuild it once to follow standard practice (load raw data as sources, use cost benchmarks instead of invented numbers). With more time, I would add data-driven attribution, retrain the lifetime value model on a full year of data, and run the dbt tests in GitHub Actions with keyless access to BigQuery.

## What I learned

I learned how real marketing data behaves, how dbt keeps a project organised and testable, and how important it is to say clearly what a model cannot do. Being honest about the limitations made the recommendations stronger, not weaker.
