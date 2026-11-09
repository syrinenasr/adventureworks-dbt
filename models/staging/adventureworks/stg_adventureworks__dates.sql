with

source as (

    select * from {{ source('adventureworks', 'DimDate') }}

),

renamed as (

    select
        DateKey as date_key,
        FullDateAlternateKey as date_day,
        DayNumberOfWeek as day_of_week,
        EnglishDayNameOfWeek as day_name,
        DayNumberOfMonth as day_of_month,
        DayNumberOfYear as day_of_year,
        WeekNumberOfYear as week_of_year,
        EnglishMonthName as month_name,
        MonthNumberOfYear as month_of_year,
        CalendarQuarter as calendar_quarter,
        CalendarYear as calendar_year,
        CalendarSemester as calendar_semester,
        FiscalQuarter as fiscal_quarter,
        FiscalYear as fiscal_year,
        FiscalSemester as fiscal_semester

    from source

)

select * from renamed
