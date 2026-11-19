-- Campaign costs must add up to the channel costs in mart_channel_performance
-- (to the cent), so allocation neither loses nor invents cost.
with campaign as (
    select channel, sum(cost_usd) as cost_usd
    from {{ ref('mart_campaign_performance') }}
    where attribution_model = 'last_touch'
    group by 1
),
channel as (
    select channel, cost_usd
    from {{ ref('mart_channel_performance') }}
    where attribution_model = 'last_touch' and cost_usd is not null
)
select ch.channel, ch.cost_usd as channel_cost, ca.cost_usd as campaign_cost
from channel as ch
left join campaign as ca on ch.channel = ca.channel
where ca.cost_usd is null or abs(ch.cost_usd - ca.cost_usd) > 0.05
