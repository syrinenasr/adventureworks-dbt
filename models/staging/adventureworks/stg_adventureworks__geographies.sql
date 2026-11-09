with

source as (

    select * from {{ source('adventureworks', 'DimGeography') }}

),

renamed as (

    select
        GeographyKey as geography_key,
        SalesTerritoryKey as sales_territory_key,
        City as city,
        StateProvinceCode as state_province_code,
        StateProvinceName as state_province_name,
        CountryRegionCode as country_code,
        EnglishCountryRegionName as country_name,
        PostalCode as postal_code

    from source

)

select * from renamed
