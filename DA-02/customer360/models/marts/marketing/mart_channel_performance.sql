-- Channel results for the whole period under each attribution model, with cost,
-- ROAS, ROI and CPA. One row per channel and model (long format for Tableau).
-- Cost exists only for the paid channels: Paid Search (per click),
-- Affiliates (commission per sale) and Email (platform fee).
-- ROI here is on revenue, as no product margin is available.

with attribution as (

    select * from {{ ref('fct_attribution') }}

),

by_model as (

    {% set models = ['first_touch', 'last_touch', 'linear', 'time_decay'] %}
    {% for m in models %}
    select
        channel,
        '{{ m }}'                               as attribution_model,
        sum({{ m }}_credit)                     as conversions,
        sum({{ m }}_revenue_usd)                as revenue_usd
    from attribution
    group by 1
    {% if not loop.last %}union all{% endif %}
    {% endfor %}

),

sessions as (

    select channel, count(*) as sessions
    from {{ ref('int_ga4__sessions') }}
    group by 1

),

costs as (

    select 'Paid Search' as channel, sum(cost_usd) as cost_usd
    from {{ ref('stg_marketing__google_ads_daily_cost') }}
    union all
    select 'Affiliates', sum(commission_usd)
    from {{ ref('stg_marketing__affiliate_commissions') }}
    union all
    select 'Email', sum(amount_usd)
    from {{ ref('stg_marketing__esp_monthly_invoices') }}

),

channel_models as (

    -- every channel with sessions appears under every model, even with no conversions
    select s.channel, m.attribution_model
    from sessions as s
    cross join (select distinct attribution_model from by_model) as m

)

select
    cm.channel,
    cm.attribution_model,
    s.sessions,
    coalesce(b.conversions, 0)                              as conversions,
    cast(round(coalesce(b.revenue_usd, 0), 2) as numeric)   as revenue_usd,
    c.cost_usd,
    safe_divide(b.revenue_usd, c.cost_usd)                  as roas,
    safe_divide(b.revenue_usd - c.cost_usd, c.cost_usd)     as roi,
    safe_divide(c.cost_usd, b.conversions)                  as cpa_usd
from channel_models as cm
inner join sessions as s
    on cm.channel = s.channel
left join by_model as b
    on cm.channel = b.channel and cm.attribution_model = b.attribution_model
left join costs as c
    on cm.channel = c.channel
