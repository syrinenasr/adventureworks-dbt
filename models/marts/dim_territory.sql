with

territories as (

    select * from {{ ref('stg_adventureworks__sales_territories') }}

),

final as (

    select
        sales_territory_key,
        sales_territory_region,
        sales_territory_country,
        sales_territory_group
    from territories

)

select * from final
