{{ config(tags=['clv']) }}

with source as (

    select * from {{ source('ml', 'customer_clv') }}

),

renamed as (

    select
        customer_id,
        cast(repeat_purchase_days as int64)         as clv_repeat_purchase_days,
        probability_alive,
        expected_purchases_90d,
        expected_order_value_usd,
        clv_12m_usd,
        model                                       as clv_model,
        cast(observation_end as date)               as clv_observation_end
    from source

)

select * from renamed
