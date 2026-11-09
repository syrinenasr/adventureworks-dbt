with

source as (

    select * from {{ source('adventureworks', 'DimSalesTerritory') }}

),

renamed as (

    select
        SalesTerritoryKey as sales_territory_key,
        SalesTerritoryRegion as sales_territory_region,
        SalesTerritoryCountry as sales_territory_country,
        SalesTerritoryGroup as sales_territory_group

    from source

)

select * from renamed
