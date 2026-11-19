-- Customer 360: one row per CRM customer with profile, devices, web activity,
-- purchase history, and RFM scores and segment. CLV is added by the Python model.
--
-- RFM scoring:
--   Recency and Monetary: quintiles (1-5) by percent rank, so equal values get
--   equal scores. Recency is reversed: fewer days since last order = higher score.
--   Frequency: fixed bands, because 88% of customers have one order and quintiles
--   would give identical customers different scores:
--   1 order = 1, 2 = 2, 3 = 3, 4-5 = 4, 6 or more = 5.
-- Segments: the standard recency x frequency segment map (Champions, Loyal
-- Customers, Potential Loyalists, New Customers, Promising, Need Attention,
-- About to Sleep, At Risk, Cannot Lose Them, Hibernating).

{% set as_of = "date('" ~ var('as_of_date') ~ "')" %}

with customers as (

    select * from {{ ref('stg_crm__customers') }}

),

orders as (

    select * from {{ ref('fct_orders') }}

),

devices as (

    select customer_id, count(*) as devices, array_agg(user_pseudo_id order by user_pseudo_id) as device_ids
    from {{ ref('int_identity__device_customers') }}
    group by 1

),

web as (

    select
        d.customer_id,
        count(*)                        as sessions,
        countif(s.is_engaged)           as engaged_sessions,
        min(s.session_start_at)         as first_seen_at,
        array_agg(s.channel order by s.session_start_at limit 1)[offset(0)] as first_session_channel
    from {{ ref('int_identity__device_customers') }} as d
    inner join {{ ref('int_ga4__sessions') }} as s
        on d.user_pseudo_id = s.user_pseudo_id
    group by 1

),

order_summary as (

    select
        customer_id,
        count(*)                                    as orders,
        sum(order_total_usd)                        as revenue_usd,
        min(order_date)                             as first_order_date,
        max(order_date)                             as last_order_date,
        max(if(customer_order_number = 1, last_touch_channel, null)) as first_order_channel
    from orders
    group by 1

),

base as (

    select
        c.customer_id,
        c.first_name,
        c.last_name,
        c.email,
        c.country,
        c.signup_date,
        coalesce(d.devices, 0)                      as devices,
        w.sessions,
        w.engaged_sessions,
        w.first_seen_at,
        w.first_session_channel,
        os.first_order_channel,
        os.orders,
        os.revenue_usd,
        safe_divide(os.revenue_usd, os.orders)      as average_order_value_usd,
        os.first_order_date,
        os.last_order_date,
        date_diff({{ as_of }}, os.last_order_date, day)     as recency_days,
        date_diff({{ as_of }}, os.first_order_date, day)    as customer_age_days
    from customers as c
    inner join order_summary as os on c.customer_id = os.customer_id
    left join devices as d on c.customer_id = d.customer_id
    left join web as w on c.customer_id = w.customer_id

),

scored as (

    select
        *,
        1 + least(4, cast(floor(percent_rank() over (order by recency_days desc) * 5) as int64)) as r_score,
        case
            when orders >= 6 then 5
            when orders >= 4 then 4
            when orders = 3 then 3
            when orders = 2 then 2
            else 1
        end                                                                                     as f_score,
        1 + least(4, cast(floor(percent_rank() over (order by revenue_usd) * 5) as int64))      as m_score
    from base

)

select
    *,
    concat(cast(r_score as string), cast(f_score as string), cast(m_score as string)) as rfm_score,
    case
        when r_score = 5 and f_score >= 4             then 'Champions'
        when r_score in (3, 4) and f_score >= 4       then 'Loyal Customers'
        when r_score >= 4 and f_score in (2, 3)       then 'Potential Loyalists'
        when r_score = 5 and f_score = 1              then 'New Customers'
        when r_score = 4 and f_score = 1              then 'Promising'
        when r_score = 3 and f_score = 3              then 'Need Attention'
        when r_score = 3 and f_score <= 2             then 'About to Sleep'
        when r_score <= 2 and f_score = 5             then 'Cannot Lose Them'
        when r_score <= 2 and f_score in (3, 4)       then 'At Risk'
        else 'Hibernating'
    end                                                                               as rfm_segment
from scored
