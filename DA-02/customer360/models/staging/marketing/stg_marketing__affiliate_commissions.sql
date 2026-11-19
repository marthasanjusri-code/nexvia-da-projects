with source as (

    select * from {{ source('marketing', 'affiliate_commissions') }}

),

renamed as (

    select
        order_id,
        cast(order_date as date)                        as order_date,
        campaign                                        as campaign_name,
        cast(round(sale_amount_usd, 2) as numeric)      as sale_amount_usd,
        cast(commission_rate as numeric)                as commission_rate,
        cast(round(commission_usd, 2) as numeric)       as commission_usd
    from source

)

select * from renamed
