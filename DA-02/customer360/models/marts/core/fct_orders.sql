-- One row per order, with its place in the customer's history and the channel
-- that gets last-touch credit (GA4's last non-direct click).

with orders as (

    select * from {{ ref('int_orders__purchase_events') }}

),

last_touch as (

    select order_id, channel as last_touch_channel
    from {{ ref('fct_attribution') }}
    where last_touch_credit = 1

)

select
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_at,
    o.order_total_usd,
    row_number() over (partition by o.customer_id order by o.order_at, o.order_id) as customer_order_number,
    o.purchase_session_key,
    lt.last_touch_channel
from orders as o
left join last_touch as lt
    on o.order_id = lt.order_id
