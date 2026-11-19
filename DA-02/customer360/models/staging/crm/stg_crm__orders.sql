with source as (

    select * from {{ source('crm', 'orders') }}

),

renamed as (

    select
        order_id,
        customer_id,
        cast(order_date as date)                        as order_date,
        cast(round(order_total_usd, 2) as numeric)      as order_total_usd,
        order_status
    from source

)

select * from renamed
