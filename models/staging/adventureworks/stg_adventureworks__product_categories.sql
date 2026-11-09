with

source as (

    select * from {{ source('adventureworks', 'DimProductCategory') }}

),

renamed as (

    select
        ProductCategoryKey as product_category_key,
        EnglishProductCategoryName as product_category_name

    from source

)

select * from renamed
