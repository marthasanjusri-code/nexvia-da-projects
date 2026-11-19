-- One row per GA4 session with its channel and, when the device is linked to a
-- CRM customer (identity resolution), the customer_id. Sessions of devices that
-- never bought stay anonymous (customer_id is null).

with sessions as (

    select * from {{ ref('int_ga4__sessions') }}

),

devices as (

    select user_pseudo_id, customer_id
    from {{ ref('int_identity__device_customers') }}

)

select
    s.session_key,
    d.customer_id,
    s.user_pseudo_id,
    s.ga_session_id,
    s.session_date,
    s.session_start_at,
    s.session_end_at,
    s.channel,
    s.session_source,
    s.session_medium,
    s.session_campaign,
    s.source_category,
    s.events,
    s.page_views,
    s.is_engaged,
    s.engagement_time_msec,
    s.landing_page,
    s.device_category,
    s.country,
    s.transactions,
    d.customer_id is not null as is_identified
from sessions as s
left join devices as d
    on s.user_pseudo_id = d.user_pseudo_id
