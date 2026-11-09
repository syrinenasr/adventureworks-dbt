with

source as (

    select * from {{ source('adventureworks', 'DimProductSubcategory') }}

),

renamed as (

    select
        ProductSubcategoryKey as product_subcategory_key,
        ProductCategoryKey as product_category_key,
        EnglishProductSubcategoryName as product_subcategory_name

    from source

)

select * from renamed
