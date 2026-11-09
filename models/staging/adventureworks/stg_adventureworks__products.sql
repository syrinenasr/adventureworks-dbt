with

source as (

    select * from {{ source('adventureworks', 'DimProduct') }}

),

renamed as (

    -- One row per product version (SCD type 2 in the source).
    -- EndDate is not selected: in this release it is earlier than StartDate
    -- on every history row. Validity ranges are rebuilt downstream in
    -- int_products__versioned.
    select
        ProductKey as product_key,
        ProductAlternateKey as product_number,
        ProductSubcategoryKey as product_subcategory_key,

        EnglishProductName as product_name,
        ModelName as model_name,
        EnglishDescription as product_description,
        Color as color,
        Size as size,
        SizeRange as size_range,
        Weight as weight,
        WeightUnitMeasureCode as weight_unit,
        trim(ProductLine) as product_line_code,
        trim(Class) as class_code,
        trim(Style) as style_code,
        FinishedGoodsFlag as is_finished_good,
        DaysToManufacture as days_to_manufacture,
        SafetyStockLevel as safety_stock_level,
        ReorderPoint as reorder_point,

        StandardCost as standard_cost,
        ListPrice as list_price,
        DealerPrice as dealer_price,

        cast(StartDate as date) as source_start_date,
        coalesce(Status = 'Current', false) as is_current_in_source

    from source

)

select * from renamed
