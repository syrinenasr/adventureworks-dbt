-- fct_sales must carry every source order line, per channel, with the same
-- revenue and cost. Returns the channels where anything differs.

with

source_totals as (

    select
        'Internet' as channel,
        count(*) as order_lines,
        count(distinct SalesOrderNumber) as orders,
        sum(SalesAmount) as revenue,
        sum(TotalProductCost) as product_cost
    from {{ source('adventureworks', 'FactInternetSales') }}

    union all

    select
        'Reseller' as channel,
        count(*) as order_lines,
        count(distinct SalesOrderNumber) as orders,
        sum(SalesAmount) as revenue,
        sum(TotalProductCost) as product_cost
    from {{ source('adventureworks', 'FactResellerSales') }}

),

mart_totals as (

    select
        channel,
        count(*) as order_lines,
        count(distinct sales_order_number) as orders,
        sum(sales_amount) as revenue,
        sum(total_product_cost) as product_cost
    from {{ ref('fct_sales') }}
    group by channel

)

select
    source_totals.channel,
    source_totals.order_lines as source_order_lines,
    mart_totals.order_lines as mart_order_lines,
    source_totals.revenue as source_revenue,
    mart_totals.revenue as mart_revenue
from source_totals
left join mart_totals
    on source_totals.channel = mart_totals.channel
where
    mart_totals.channel is null
    or source_totals.order_lines != mart_totals.order_lines
    or source_totals.orders != mart_totals.orders
    or abs(source_totals.revenue - mart_totals.revenue) > 0.01
    or abs(source_totals.product_cost - mart_totals.product_cost) > 0.01
