with

dates as (

    select * from {{ ref('stg_adventureworks__dates') }}

),

final as (

    select
        date_day,
        date_key,
        day_of_week,
        day_name,
        day_of_month,
        day_of_year,
        week_of_year,
        month_name,
        month_of_year,
        calendar_quarter,
        calendar_year,
        calendar_semester,
        fiscal_quarter,
        fiscal_year,
        fiscal_semester,
        cast({{ dbt.date_trunc('month', 'date_day') }} as date) as month_start_date,
        day_name in ('Saturday', 'Sunday') as is_weekend
    from dates

)

select * from final
