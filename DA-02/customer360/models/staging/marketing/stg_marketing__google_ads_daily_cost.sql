with source as (

    select * from {{ source('marketing', 'google_ads_daily_cost') }}

),

renamed as (

    select
        cast(date as date)                          as cost_date,
        campaign_name,
        cast(clicks as int64)                       as clicks,
        cast(round(cost_usd, 2) as numeric)         as cost_usd
    from source

)

select * from renamed
