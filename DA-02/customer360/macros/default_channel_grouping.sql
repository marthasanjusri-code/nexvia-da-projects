{#-
  GA4 default channel group, following Google's rules for manually tagged traffic:
  https://support.google.com/analytics/answer/9756891
  Adapted from the Velir/dbt-ga4 package (MIT licence), with two changes:
    1. A session with no source and no medium is 'Unassigned', as Google's rules say
       (Direct needs source "(direct)"); Velir maps it to Direct.
    2. Rules are checked in Google's order (Email before Referral).
  Google Ads-only rules (ad network type, campaign type) are not available in the
  export, so the manual-traffic rules are used. Inputs must be lowercase,
  because Google's rules are not case-sensitive.
-#}
{% macro default_channel_grouping(source, medium, source_category, campaign) %}
case
    when {{ source }} = '(direct)' and {{ medium }} in ('(none)', '(not set)')
        then 'Direct'
    when regexp_contains({{ campaign }}, r'cross-network')
        then 'Cross-network'
    when ({{ source_category }} = 'SOURCE_CATEGORY_SHOPPING'
          or regexp_contains({{ campaign }}, r'^(.*(([^a-df-z]|^)shop|shopping).*)$'))
         and regexp_contains({{ medium }}, r'^(.*cp.*|ppc|retargeting|paid.*)$')
        then 'Paid Shopping'
    when {{ source_category }} = 'SOURCE_CATEGORY_SEARCH'
         and regexp_contains({{ medium }}, r'^(.*cp.*|ppc|retargeting|paid.*)$')
        then 'Paid Search'
    when {{ source_category }} = 'SOURCE_CATEGORY_SOCIAL'
         and regexp_contains({{ medium }}, r'^(.*cp.*|ppc|retargeting|paid.*)$')
        then 'Paid Social'
    when {{ source_category }} = 'SOURCE_CATEGORY_VIDEO'
         and regexp_contains({{ medium }}, r'^(.*cp.*|ppc|retargeting|paid.*)$')
        then 'Paid Video'
    when {{ medium }} in ('display', 'banner', 'expandable', 'interstitial', 'cpm')
        then 'Display'
    when regexp_contains({{ medium }}, r'^(.*cp.*|ppc|retargeting|paid.*)$')
        then 'Paid Other'
    when {{ source_category }} = 'SOURCE_CATEGORY_SHOPPING'
         or regexp_contains({{ campaign }}, r'^(.*(([^a-df-z]|^)shop|shopping).*)$')
        then 'Organic Shopping'
    when {{ source_category }} = 'SOURCE_CATEGORY_SOCIAL'
         or {{ medium }} in ('social', 'social-network', 'social-media', 'sm', 'social network', 'social media')
        then 'Organic Social'
    when {{ source_category }} = 'SOURCE_CATEGORY_VIDEO'
         or regexp_contains({{ medium }}, r'^(.*video.*)$')
        then 'Organic Video'
    when {{ source_category }} = 'SOURCE_CATEGORY_SEARCH' or {{ medium }} = 'organic'
        then 'Organic Search'
    when regexp_contains({{ source }}, r'^(email|e-mail|e_mail|e mail)$')
         or regexp_contains({{ medium }}, r'^(email|e-mail|e_mail|e mail)$')
        then 'Email'
    when {{ medium }} = 'affiliate'
        then 'Affiliates'
    when {{ medium }} in ('referral', 'app', 'link')
        then 'Referral'
    when {{ medium }} = 'audio'
        then 'Audio'
    when {{ source }} = 'sms' or {{ medium }} = 'sms'
        then 'SMS'
    when regexp_contains({{ medium }}, r'push$')
         or regexp_contains({{ medium }}, r'mobile|notification')
         or {{ source }} = 'firebase'
        then 'Mobile Push Notifications'
    else 'Unassigned'
end
{% endmacro %}
