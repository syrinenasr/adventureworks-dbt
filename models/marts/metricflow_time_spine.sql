-- Daily time spine required by MetricFlow (dbt semantic layer).

with

dates as (

    select * from {{ ref('dim_date') }}

),

final as (

    select date_day
    from dates

)

select * from final
