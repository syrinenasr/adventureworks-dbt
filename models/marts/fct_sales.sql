{{
    config(
        materialized='incremental',
        unique_key='sales_line_key',
        incremental_strategy='delete+insert',
        on_schema_change='append_new_columns'
    )
}}

-- Grain: one row per order line, both channels.
-- Incremental on order_date: a run re-reads the last
-- var('sales_lookback_days') days before the latest loaded order date and
-- replaces those lines (delete+insert on sales_line_key), so late or
-- corrected lines are picked up without a full rebuild.

with

sales as (

    select * from {{ ref('int_sales__unioned') }}

    {% if is_incremental() %}
        where order_date >= (
            select
                {{ dbt.dateadd(
                    'day',
                    -1 * var('sales_lookback_days'),
                    'max(order_date)'
                ) }}
            from {{ this }}
        )
    {% endif %}

),

final as (

    select
        sales_line_key,
        channel,
        sales_order_number,
        sales_order_line_number,

        product_key,
        customer_key,
        reseller_key,
        promotion_key,
        sales_territory_key,
        order_date,
        ship_date,
        due_date,
        {{
            dbt.datediff('order_date', 'ship_date', 'day')
        }} as days_to_ship,
        currency_code,

        order_quantity,
        unit_price,
        unit_price_discount_pct,
        extended_amount,
        discount_amount,
        total_product_cost,
        sales_amount,
        sales_amount - total_product_cost as gross_profit,
        tax_amount,
        freight_amount
    from sales

)

select * from final
