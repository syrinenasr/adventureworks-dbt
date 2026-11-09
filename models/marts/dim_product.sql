-- SCD type 2 product dimension: one row per product version.
-- product_key is the version key that the sales facts carry, so facts join
-- to the version that was valid when the line was recorded without a date
-- range join. Use is_current = true for the latest attributes.

with

products as (

    select * from {{ ref('int_products__versioned') }}

),

subcategories as (

    select * from {{ ref('stg_adventureworks__product_subcategories') }}

),

categories as (

    select * from {{ ref('stg_adventureworks__product_categories') }}

),

final as (

    select
        products.product_key,
        products.product_number,
        products.version_number,
        products.product_name,
        products.model_name,
        subcategories.product_subcategory_name,
        categories.product_category_name,
        products.product_description,
        products.color,
        products.size,
        products.size_range,
        products.weight,
        products.weight_unit,
        products.product_line_code,
        products.class_code,
        products.style_code,
        products.is_finished_good,
        products.days_to_manufacture,
        products.standard_cost,
        products.list_price,
        products.dealer_price,
        products.valid_from,
        products.valid_to,
        products.is_current
    from products
    left join subcategories
        on products.product_subcategory_key = subcategories.product_subcategory_key
    left join categories
        on subcategories.product_category_key = categories.product_category_key

)

select * from final
