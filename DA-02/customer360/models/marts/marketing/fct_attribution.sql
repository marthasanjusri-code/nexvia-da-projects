-- Credit for each order shared across its touchpoints under four rule-based models.
-- Each model's credits add up to 1 per order (tested), so attributed revenue
-- adds up to total revenue.
--   first touch: 100% to the earliest eligible session
--   last touch:  100% to the latest eligible session (last non-direct click)
--   linear:      equal share to every eligible session
--   time decay:  weight 2^(-days before order / half-life), half-life 7 days

with touchpoints as (

    select * from {{ ref('int_attribution__touchpoints') }}

),

ranked as (

    select
        *,
        row_number() over (partition by order_id order by session_start_at, session_key)      as touch_number,
        row_number() over (partition by order_id order by session_start_at desc, session_key desc) as touch_number_desc,
        count(*) over (partition by order_id)                                                as touches,
        pow(2, -days_before_order / {{ var('time_decay_half_life_days') }})                  as decay_weight
    from touchpoints

),

credited as (

    select
        *,
        if(touch_number = 1, 1.0, 0.0)                                       as first_touch_credit,
        if(touch_number_desc = 1, 1.0, 0.0)                                  as last_touch_credit,
        1.0 / touches                                                        as linear_credit,
        decay_weight / sum(decay_weight) over (partition by order_id)        as time_decay_credit
    from ranked

)

select
    {{ dbt_utils.generate_surrogate_key(['order_id', 'session_key']) }} as attribution_key,
    order_id,
    customer_id,
    order_at,
    session_key,
    session_start_at,
    channel,
    session_source,
    session_medium,
    session_campaign,
    touch_number,
    touches,
    days_before_order,
    first_touch_credit,
    last_touch_credit,
    linear_credit,
    time_decay_credit,
    order_total_usd * first_touch_credit  as first_touch_revenue_usd,
    order_total_usd * last_touch_credit   as last_touch_revenue_usd,
    order_total_usd * linear_credit       as linear_revenue_usd,
    order_total_usd * time_decay_credit   as time_decay_revenue_usd
from credited
