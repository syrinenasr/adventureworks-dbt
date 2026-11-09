with

source as (

    select * from {{ source('adventureworks', 'DimReseller') }}

),

renamed as (

    select
        ResellerKey as reseller_key,
        ResellerAlternateKey as reseller_number,
        GeographyKey as geography_key,
        ResellerName as reseller_name,
        BusinessType as business_type,
        NumberEmployees as employee_count,
        ProductLine as product_line,
        AnnualSales as annual_sales,
        AnnualRevenue as annual_revenue,
        YearOpened as year_opened,
        FirstOrderYear as first_order_year,
        LastOrderYear as last_order_year

    from source

)

select * from renamed
