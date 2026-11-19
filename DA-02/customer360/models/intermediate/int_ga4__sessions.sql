-- One row per GA4 session (user_pseudo_id + ga_session_id).
-- Session traffic source = the first event in the session that carries a medium
-- (session_start carries none in this export). Sessions with no such event have
-- no source or medium and fall to 'Unassigned' under Google's channel rules.

with events as (

    select * from {{ ref('stg_ga4__events') }}

),

source_categories as (

    select lower(source) as source, source_category
    from {{ ref('ga4_source_categories') }}

),

session_traffic as (

    select
        session_key,
        array_agg(
            struct(
                lower(traffic_source)   as source,
                lower(traffic_medium)   as medium,
                lower(traffic_campaign) as campaign
            )
            order by event_at limit 1
        )[offset(0)] as traffic
    from events
    where traffic_medium is not null
    group by 1

),

session_events as (

    select
        session_key,
        any_value(user_pseudo_id)                                       as user_pseudo_id,
        any_value(ga_session_id)                                        as ga_session_id,
        min(event_date)                                                 as session_date,
        min(event_at)                                                   as session_start_at,
        max(event_at)                                                   as session_end_at,
        count(*)                                                        as events,
        countif(event_name = 'page_view')                               as page_views,
        logical_or(session_engaged = '1')                               as is_engaged,
        coalesce(sum(engagement_time_msec), 0)                          as engagement_time_msec,
        array_agg(page_location ignore nulls order by event_at limit 1)[safe_offset(0)]  as landing_page,
        array_agg(device_category ignore nulls order by event_at limit 1)[safe_offset(0)] as device_category,
        array_agg(country ignore nulls order by event_at limit 1)[safe_offset(0)]         as country,
        count(distinct if(event_name = 'purchase', transaction_id, null))                 as transactions
    from events
    group by 1

)

select
    s.session_key,
    s.user_pseudo_id,
    s.ga_session_id,
    s.session_date,
    s.session_start_at,
    s.session_end_at,
    t.traffic.source                as session_source,
    t.traffic.medium                as session_medium,
    t.traffic.campaign              as session_campaign,
    sc.source_category,
    {{ default_channel_grouping('t.traffic.source', 't.traffic.medium', 'sc.source_category', 't.traffic.campaign') }}
                                    as channel,
    s.events,
    s.page_views,
    s.is_engaged,
    s.engagement_time_msec,
    s.landing_page,
    s.device_category,
    s.country,
    s.transactions
from session_events as s
left join session_traffic as t
    on s.session_key = t.session_key
left join source_categories as sc
    on t.traffic.source = sc.source
