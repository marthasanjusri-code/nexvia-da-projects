-- One row per CRM order with the moment it was placed in GA4.
-- order_at = the earliest purchase event for that transaction_id (GA4 sends some
-- purchases more than once, and 15 orders were sent from two devices).

with purchases as (

    select
        transaction_id,
        session_key,
        user_pseudo_id,
        event_at
    from {{ ref('stg_ga4__events') }}
    where event_name = 'purchase'
      and transaction_id is not null

),

first_purchase as (

    select
        transaction_id,
        array_agg(struct(event_at, session_key, user_pseudo_id) order by event_at limit 1)[offset(0)] as p
    from purchases
    group by 1

)

select
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_total_usd,
    fp.p.event_at           as order_at,
    fp.p.session_key        as purchase_session_key,
    fp.p.user_pseudo_id     as purchase_user_pseudo_id
from {{ ref('stg_crm__orders') }} as o
inner join first_purchase as fp
    on o.order_id = fp.transaction_id
