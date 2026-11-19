{{ config(tags=['clv']) }}

-- Customer 360 for reporting: the customer profile and RFM segment from
-- dim_customers, plus predicted CLV from the Python model.
-- CLV tier: quartiles of 12-month CLV (equal CLV values get equal tiers).

with customers as (

    select * from {{ ref('dim_customers') }}

),

clv as (

    select * from {{ ref('stg_ml__customer_clv') }}

)

select
    c.*,
    clv.probability_alive,
    clv.expected_purchases_90d,
    clv.expected_order_value_usd,
    clv.clv_12m_usd,
    case 1 + least(3, cast(floor(percent_rank() over (order by clv.clv_12m_usd) * 4) as int64))
        when 4 then 'Top 25%'
        when 3 then 'Upper middle'
        when 2 then 'Lower middle'
        else 'Bottom 25%'
    end                             as clv_tier,
    clv.clv_model,
    clv.clv_observation_end
from customers as c
inner join clv
    on c.customer_id = clv.customer_id
