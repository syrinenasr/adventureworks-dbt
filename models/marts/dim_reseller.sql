with

resellers as (

    select * from {{ ref('stg_adventureworks__resellers') }}

),

geographies as (

    select * from {{ ref('stg_adventureworks__geographies') }}

),

final as (

    select
        resellers.reseller_key,
        resellers.reseller_number,
        resellers.reseller_name,
        resellers.business_type,
        resellers.employee_count,
        resellers.product_line,
        resellers.annual_sales,
        resellers.annual_revenue,
        resellers.year_opened,
        resellers.first_order_year,
        resellers.last_order_year,
        geographies.city,
        geographies.state_province_name,
        geographies.country_code,
        geographies.country_name,
        geographies.postal_code
    from resellers
    left join geographies
        on resellers.geography_key = geographies.geography_key

)

select * from final
