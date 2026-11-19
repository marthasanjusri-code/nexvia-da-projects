-- Revenue must be the same in CRM orders, fct_orders and every attribution model
-- (to the cent).
with totals as (
    select
        (select sum(order_total_usd) from {{ ref('stg_crm__orders') }})            as crm,
        (select sum(order_total_usd) from {{ ref('fct_orders') }})                 as orders_mart,
        (select sum(first_touch_revenue_usd) from {{ ref('fct_attribution') }})    as first_touch,
        (select sum(last_touch_revenue_usd)  from {{ ref('fct_attribution') }})    as last_touch,
        (select sum(linear_revenue_usd)      from {{ ref('fct_attribution') }})    as linear,
        (select sum(time_decay_revenue_usd)  from {{ ref('fct_attribution') }})    as time_decay
)
select *
from totals
where abs(orders_mart - crm) > 0.01
   or abs(first_touch - crm) > 0.01
   or abs(last_touch  - crm) > 0.01
   or abs(linear      - crm) > 0.01
   or abs(time_decay  - crm) > 0.01
