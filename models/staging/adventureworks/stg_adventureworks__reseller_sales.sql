with

source as (

    select * from {{ source('adventureworks', 'FactResellerSales') }}

),

renamed as (

    select
        SalesOrderNumber as sales_order_number,
        SalesOrderLineNumber as sales_order_line_number,
        RevisionNumber as revision_number,

        ProductKey as product_key,
        ResellerKey as reseller_key,
        EmployeeKey as employee_key,
        PromotionKey as promotion_key,
        CurrencyKey as currency_key,
        SalesTerritoryKey as sales_territory_key,

        cast(OrderDate as date) as order_date,
        cast(DueDate as date) as due_date,
        cast(ShipDate as date) as ship_date,

        OrderQuantity as order_quantity,
        UnitPrice as unit_price,
        UnitPriceDiscountPct as unit_price_discount_pct,
        ExtendedAmount as extended_amount,
        cast(DiscountAmount as {{ dbt.type_numeric() }}) as discount_amount,
        ProductStandardCost as product_standard_cost,
        TotalProductCost as total_product_cost,
        SalesAmount as sales_amount,
        TaxAmt as tax_amount,
        Freight as freight_amount,

        CarrierTrackingNumber as carrier_tracking_number,
        CustomerPONumber as customer_po_number

    from source

)

select * from renamed
