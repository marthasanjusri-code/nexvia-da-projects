-- Campaign results for the three paid channels under each attribution model,
-- with cost, ROAS, ROI and CPA. One row per channel, campaign and model.
--
-- Cost by campaign:
--   Affiliates: exact. The commission report has the campaign on every order.
--   Paid Search and Email: the cost reports are by day (Google Ads) and by month
--   (email platform invoice), not by campaign. Each month's cost is shared across
--   that channel's campaigns in proportion to their sessions in the same month
--   (activity-based allocation). Paid search campaign names are obfuscated in the
--   GA4 sample, so its sessions carry '<other>' or no campaign.
-- Campaign totals add up to the channel totals (tested).

with attribution as (

    select
        channel,
        coalesce(session_campaign, '(not set)') as campaign,
        *  except (channel, session_campaign)
    from {{ ref('fct_attribution') }}
    where channel in ('Paid Search', 'Affiliates', 'Email')

),

by_model as (

    {% set models = ['first_touch', 'last_touch', 'linear', 'time_decay'] %}
    {% for m in models %}
    select
        channel,
        campaign,
        '{{ m }}'                       as attribution_model,
        sum({{ m }}_credit)             as conversions,
        sum({{ m }}_revenue_usd)        as revenue_usd
    from attribution
    group by 1, 2
    {% if not loop.last %}union all{% endif %}
    {% endfor %}

),

campaign_sessions as (

    select
        channel,
        coalesce(session_campaign, '(not set)')     as campaign,
        date_trunc(session_date, month)             as month,
        count(*)                                    as sessions
    from {{ ref('int_ga4__sessions') }}
    where channel in ('Paid Search', 'Email')
    group by 1, 2, 3

),

session_share as (

    select
        *,
        sessions / sum(sessions) over (partition by channel, month) as share_of_month
    from campaign_sessions

),

monthly_cost as (

    select 'Paid Search' as channel, date_trunc(cost_date, month) as month, sum(cost_usd) as cost_usd
    from {{ ref('stg_marketing__google_ads_daily_cost') }}
    group by 1, 2
    union all
    select 'Email', invoice_month, sum(amount_usd)
    from {{ ref('stg_marketing__esp_monthly_invoices') }}
    group by 1, 2

),

allocated_cost as (

    select
        s.channel,
        s.campaign,
        sum(c.cost_usd * s.share_of_month)  as cost_usd
    from session_share as s
    inner join monthly_cost as c
        on s.channel = c.channel and s.month = c.month
    group by 1, 2

    union all

    select
        'Affiliates',
        lower(campaign_name),
        sum(commission_usd)
    from {{ ref('stg_marketing__affiliate_commissions') }}
    group by 1, 2

),

campaigns as (

    select distinct channel, campaign from allocated_cost
    union distinct
    select distinct channel, campaign from by_model

),

campaign_models as (

    select c.channel, c.campaign, m.attribution_model
    from campaigns as c
    cross join (select distinct attribution_model from by_model) as m

)

select
    cm.channel,
    cm.campaign,
    cm.attribution_model,
    coalesce(b.conversions, 0)                                  as conversions,
    cast(round(coalesce(b.revenue_usd, 0), 2) as numeric)       as revenue_usd,
    cast(round(coalesce(a.cost_usd, 0), 2) as numeric)          as cost_usd,
    safe_divide(b.revenue_usd, a.cost_usd)                      as roas,
    safe_divide(b.revenue_usd - a.cost_usd, a.cost_usd)         as roi,
    safe_divide(a.cost_usd, b.conversions)                      as cpa_usd
from campaign_models as cm
left join by_model as b
    on cm.channel = b.channel and cm.campaign = b.campaign and cm.attribution_model = b.attribution_model
left join allocated_cost as a
    on cm.channel = a.channel and cm.campaign = a.campaign
