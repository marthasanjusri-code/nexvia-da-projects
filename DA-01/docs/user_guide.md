# User Guide: Enterprise BI Suite

One report for sales, finance, HR and supply chain. Executives see the whole company; regional managers see their own region.

**Open it:** `powerbi/EnterpriseBI_Suite.pbip` in Power BI Desktop. The data is reloaded every night at 02:00. Click **Home → Refresh** to load the latest run.

## Pages

| Page | Use it to |
|---|---|
| Executive Overview | See one headline figure per area: revenue, net income, headcount, supplier delivery (OTIF), revenue per employee |
| Sales | Follow revenue and growth, compare regions, channels and categories, check salespeople against quota |
| Finance | Read the income statement, margins, budget vs actual, balance sheet and current ratio |
| HR | Track headcount, workforce make-up, hiring, tenure, pay and leave (executives only) |
| Purchasing & Inventory | Review spend and vendor quality, order status, stock value and the products to reorder now |
| Production | Watch scrap and on-time completion of work orders (executives only) |
| Data Quality | Check that last night's load succeeded and passed its checks (executives only) |
| Product Detail | See one product across sales, purchasing, stock and production (opened by drill-through) |

## How to use it

- **Choose a year** with the Year slicer at the top right. The report opens on 2024, the latest full year in every area. 2022 and 2025 are part years.
- **Check the dates.** Each page subtitle shows the date its data runs to. The areas end on different dates. The **Last data load** card shows when the data was last refreshed.
- **Filter by clicking.** Click a bar or a table row to filter the rest of the page, and click it again to clear. For example, click an organisation on the Finance page to see its current ratio.
- **Drill through to a product.** Right-click a product in **Products to reorder now** or **Products by work orders**, then choose **Drill through → Product Detail**. Ctrl+click the back arrow to return.
- **See exact values.** Hover over a chart to see its tooltip, or use **…→ Show as a table** on any visual.
- **Stock figures** are always the current position; they do not change with the Year slicer.

## Access

- Your access comes from your email address.
- Regional managers see their own region's sales and finance, and company-wide stock.
- Pages for executives show the message "This page is restricted to executives", and their figures stay hidden.
- If you see no data at all, your email is not set up. Ask the report administrator to add you to the security table.

## Good to know

- A product with "--" on Product Detail has no data in that area. For example, a part that is only bought has no work orders.
- Average pay is hidden for groups of fewer than 5 people.
- Questions or wrong figures: check the Data Quality page first, then contact the report administrator.
