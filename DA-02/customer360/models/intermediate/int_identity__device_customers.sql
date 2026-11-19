-- Identity resolution: which GA4 device (user_pseudo_id) belongs to which CRM customer.
-- Deterministic match only: a device is linked when it placed an order whose GA4
-- transaction_id equals a CRM order_id. Null and '(not set)' IDs never link
-- (removed in staging). Devices that never bought stay anonymous and are not listed.

with purchases as (

    select distinct
        user_pseudo_id,
        transaction_id
    from {{ ref('stg_ga4__events') }}
    where event_name = 'purchase'
      and transaction_id is not null

),

orders as (

    select order_id, customer_id
    from {{ ref('stg_crm__orders') }}

)

select
    p.user_pseudo_id,
    o.customer_id,
    count(distinct p.transaction_id) as linked_orders
from purchases as p
inner join orders as o
    on p.transaction_id = o.order_id
group by 1, 2
