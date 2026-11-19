-- Every session that is eligible for credit on an order:
--   * a session of any device linked to the order's customer (identity map),
--   * that started on or before the purchase and within the lookback window.
-- GA4 rule: direct visits get no credit unless the path is only direct visits.

with orders as (

    select * from {{ ref('int_orders__purchase_events') }}

),

devices as (

    select user_pseudo_id, customer_id
    from {{ ref('int_identity__device_customers') }}

),

sessions as (

    select session_key, user_pseudo_id, session_start_at, channel,
           session_source, session_medium, session_campaign
    from {{ ref('int_ga4__sessions') }}

),

paths as (

    select
        o.order_id,
        o.customer_id,
        o.order_at,
        o.order_total_usd,
        s.session_key,
        s.session_start_at,
        s.channel,
        s.session_source,
        s.session_medium,
        s.session_campaign
    from orders as o
    inner join devices as d
        on o.customer_id = d.customer_id
    inner join sessions as s
        on d.user_pseudo_id = s.user_pseudo_id
       and s.session_start_at <= o.order_at
       and s.session_start_at >= timestamp_sub(o.order_at, interval {{ var('attribution_lookback_days') }} day)

),

flagged as (

    select
        *,
        logical_or(channel != 'Direct') over (partition by order_id) as path_has_non_direct
    from paths

)

select
    order_id,
    customer_id,
    order_at,
    order_total_usd,
    session_key,
    session_start_at,
    channel,
    session_source,
    session_medium,
    session_campaign,
    timestamp_diff(order_at, session_start_at, second) / 86400.0 as days_before_order
from flagged
where channel != 'Direct' or not path_has_non_direct
