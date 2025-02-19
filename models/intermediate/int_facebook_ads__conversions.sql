{{ config(enabled=var('ad_reporting__facebook_ads_enabled', True)) }}

with actions_report as (

    select *
    from {{ var('basic_ad_actions') }}
),

action_values_report as (

    select *
    from {{ var('basic_ad_action_values') }}
),

action_metrics as (

    select
        source_relation,
        ad_id,
        date_day,
        sum(conversions) as conversions

        {{ fivetran_utils.persist_pass_through_columns(pass_through_variable='facebook_ads__basic_ad_actions_passthrough_metrics', transform='sum') }}

    from actions_report
    {% if var('facebook_ads__conversion_action_types') -%}
    where 
        {# Limit conversions to the chosen action types #}
        {% for action_type in var('facebook_ads__conversion_action_types') -%}
            (
            {%- if action_type.name -%}
                action_type = '{{ action_type.name }}'
            {%- elif action_type.pattern -%}
                action_type like '{{ action_type.pattern }}'
            {%- endif -%}

            {% if action_type.where_sql %}
                and {{ action_type.where_sql }}
            {%- endif -%}
            ) {% if not loop.last %} or {% endif %}
        {%- endfor %}
    {% endif %}
    group by 1,2,3
),

action_value_metrics as (

    select
        source_relation,
        ad_id,
        date_day,
        sum(conversions_value) as conversions_value

        {{ fivetran_utils.persist_pass_through_columns(pass_through_variable='facebook_ads__basic_ad_action_values_passthrough_metrics', transform='sum') }}

    from action_values_report
    {% if var('facebook_ads__conversion_action_types') -%}
    where 
        {# Limit conversions to the chosen action types #}
        {% for action_type in var('facebook_ads__conversion_action_types') -%}
            (
            {%- if action_type.name -%}
                action_type = '{{ action_type.name }}'
            {%- elif action_type.pattern -%}
                action_type like '{{ action_type.pattern }}'
            {%- endif -%}

            {% if action_type.where_sql %}
                and {{ action_type.where_sql }}
            {%- endif -%}
            ) {% if not loop.last %} or {% endif %}
        {%- endfor %}
    {% endif %}

    group by 1,2,3
),

metrics_join as (

    select
        action_metrics.source_relation,
        action_metrics.ad_id,
        action_metrics.date_day,
        action_metrics.conversions,
        action_value_metrics.conversions_value
        
        {{ fivetran_utils.persist_pass_through_columns(pass_through_variable='facebook_ads__basic_ad_actions_passthrough_metrics', identifier='action_metrics') }}
        {{ fivetran_utils.persist_pass_through_columns(pass_through_variable='facebook_ads__basic_ad_action_values_passthrough_metrics', identifier='action_value_metrics') }}

    from action_metrics 
    left join action_value_metrics
        on action_metrics.source_relation = action_value_metrics.source_relation
        and action_metrics.ad_id = action_value_metrics.ad_id
        and action_metrics.date_day = action_value_metrics.date_day
)

select * 
from metrics_join