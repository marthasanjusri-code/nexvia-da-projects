-- Each attribution model must give out exactly 1 credit per order.
select
    order_id,
    sum(first_touch_credit) as first_touch,
    sum(last_touch_credit)  as last_touch,
    sum(linear_credit)      as linear,
    sum(time_decay_credit)  as time_decay
from {{ ref('fct_attribution') }}
group by 1
having abs(sum(first_touch_credit) - 1) > 1e-9
    or abs(sum(last_touch_credit)  - 1) > 1e-9
    or abs(sum(linear_credit)      - 1) > 1e-9
    or abs(sum(time_decay_credit)  - 1) > 1e-9
