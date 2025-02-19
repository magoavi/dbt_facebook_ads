{{ config(enabled=var('ad_reporting__facebook_ads_enabled', True)) }}

with report as (

    select *
    from {{ var('basic_ad') }}

), 

conversion_report as (

    select *
    from {{ ref('int_facebook_ads__conversions') }}

), 

accounts as (

    select *
    from {{ var('account_history') }}
    where is_most_recent_record = true

),

campaigns as (

    select *
    from {{ var('campaign_history') }}
    where is_most_recent_record = true

),

ad_sets as (

    select *
    from {{ var('ad_set_history') }}
    where is_most_recent_record = true

),

ads as (

    select *
    from {{ var('ad_history') }}
    where is_most_recent_record = true

),

joined as (

    select 
        report.source_relation,
        report.date_day,
        accounts.account_id,
        accounts.account_name,
        campaigns.campaign_id,
        campaigns.campaign_name,
        ad_sets.ad_set_id,
        ad_sets.ad_set_name,
        ad_sets.start_at,
        ad_sets.end_at,
        ad_sets.bid_strategy,
        ad_sets.daily_budget,
        ad_sets.budget_remaining,
        ad_sets.optimization_goal,
        sum(report.clicks) as clicks,
        sum(report.impressions) as impressions,
        sum(report.spend) as spend, 
        sum(coalesce(conversion_report.conversions, 0)) as conversions,
        sum(coalesce(conversion_report.conversions_value, 0)) as conversions_value

        {{ facebook_ads_persist_pass_through_columns(pass_through_variable='facebook_ads__basic_ad_passthrough_metrics', transform = 'sum', exclude_fields=['conversions', 'conversions_value']) }}
        {{ facebook_ads_persist_pass_through_columns(pass_through_variable='facebook_ads__basic_ad_actions_passthrough_metrics', transform = 'sum', coalesce_with=0) }}
        {{ facebook_ads_persist_pass_through_columns(pass_through_variable='facebook_ads__basic_ad_action_values_passthrough_metrics', transform = 'sum', coalesce_with=0) }}

    from report 
    left join conversion_report
        on report.date_day = conversion_report.date_day
        and report.ad_id = conversion_report.ad_id
        and report.source_relation = conversion_report.source_relation
    left join accounts
        on report.account_id = accounts.account_id
        and report.source_relation = accounts.source_relation
    left join ads 
        on report.ad_id = ads.ad_id
        and report.source_relation = ads.source_relation
    left join campaigns
        on ads.campaign_id = campaigns.campaign_id
        and ads.source_relation = campaigns.source_relation
    left join ad_sets
        on ads.ad_set_id = ad_sets.ad_set_id
        and ads.source_relation = ad_sets.source_relation
    {{ dbt_utils.group_by(14) }}
)

select *
from joined