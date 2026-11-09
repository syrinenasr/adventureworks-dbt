-- Stacks internet and reseller order lines into one shape with a channel
-- column. The two sources share no orders, so they are combined with
-- UNION ALL and never joined to each other.

with

internet_sales as (

    select * from {{ ref('stg_adventureworks__internet_sales') }}

),

reseller_sales as (

    select * from {{ ref('stg_adventureworks__reseller_sales') }}

),

currencies as (

    select * from {{ ref('stg_adventureworks__currencies') }}

),

unioned as (

    select
        'Internet' as channel,
        sales_order_number,
        sales_order_line_number,
        product_key,
        customer_key,
        cast(null as {{ dbt.type_int() }}) as reseller_key,
        promotion_key,
        currency_key,
        sales_territory_key,
        order_date,
        due_date,
        ship_date,
        order_quantity,
        unit_price,
        unit_price_discount_pct,
        extended_amount,
        discount_amount,
        product_standard_cost,
        total_product_cost,
        sales_amount,
        tax_amount,
        freight_amount
    from internet_sales

    union all

    select
        'Reseller' as channel,
        sales_order_number,
        sales_order_line_number,
        product_key,
        cast(null as {{ dbt.type_int() }}) as customer_key,
        reseller_key,
        promotion_key,
        currency_key,
        sales_territory_key,
        order_date,
        due_date,
        ship_date,
        order_quantity,
        unit_price,
        unit_price_discount_pct,
        extended_amount,
        discount_amount,
        product_standard_cost,
        total_product_cost,
        sales_amount,
        tax_amount,
        freight_amount
    from reseller_sales

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key([
            'unioned.channel',
            'unioned.sales_order_number',
            'unioned.sales_order_line_number'
        ]) }} as sales_line_key,
        unioned.channel,
        unioned.sales_order_number,
        unioned.sales_order_line_number,
        unioned.product_key,
        unioned.customer_key,
        unioned.reseller_key,
        unioned.promotion_key,
        unioned.sales_territory_key,
        unioned.order_date,
        unioned.due_date,
        unioned.ship_date,
        currencies.currency_code,
        unioned.order_quantity,
        unioned.unit_price,
        unioned.unit_price_discount_pct,
        unioned.extended_amount,
        unioned.discount_amount,
        unioned.product_standard_cost,
        unioned.total_product_cost,
        unioned.sales_amount,
        unioned.tax_amount,
        unioned.freight_amount
    from unioned
    left join currencies
        on unioned.currency_key = currencies.currency_key

)

select * from final
