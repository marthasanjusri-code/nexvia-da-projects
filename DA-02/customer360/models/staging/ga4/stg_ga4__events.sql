-- One row per GA4 event. Flattens the event_params needed downstream.
-- Value types follow the event_params profiling (19 Nov 2026):
--   int:    ga_session_id, ga_session_number, engagement_time_msec
--   string: source, medium, campaign, page_location, page_referrer
--   mixed:  session_engaged (string and int), so both are read
-- Transaction ID and revenue come from the ecommerce record, the same fields
-- used to build raw_crm.orders.

with source as (

    select * from {{ source('ga4', 'events') }}

),

renamed as (

    select
        parse_date('%Y%m%d', event_date)                                    as event_date,
        timestamp_micros(event_timestamp)                                   as event_at,
        event_name,
        user_pseudo_id,
        (select value.int_value    from unnest(event_params) where key = 'ga_session_id')        as ga_session_id,
        (select value.int_value    from unnest(event_params) where key = 'ga_session_number')    as ga_session_number,
        (select value.string_value from unnest(event_params) where key = 'source')               as traffic_source,
        (select value.string_value from unnest(event_params) where key = 'medium')               as traffic_medium,
        (select value.string_value from unnest(event_params) where key = 'campaign')             as traffic_campaign,
        (select value.string_value from unnest(event_params) where key = 'page_location')        as page_location,
        (select value.string_value from unnest(event_params) where key = 'page_referrer')        as page_referrer,
        (select coalesce(value.string_value, cast(value.int_value as string))
           from unnest(event_params) where key = 'session_engaged')                              as session_engaged,
        (select value.int_value    from unnest(event_params) where key = 'engagement_time_msec') as engagement_time_msec,
        nullif(ecommerce.transaction_id, '(not set)')                       as transaction_id,
        ecommerce.purchase_revenue_in_usd                                   as purchase_revenue_usd,
        device.category                                                     as device_category,
        geo.country                                                         as country
    from source

)

select
    {{ dbt_utils.generate_surrogate_key(['user_pseudo_id', 'ga_session_id']) }} as session_key,
    *
from renamed
