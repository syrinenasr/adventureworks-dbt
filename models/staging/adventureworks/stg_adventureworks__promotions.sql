with

source as (

    select * from {{ source('adventureworks', 'DimPromotion') }}

),

renamed as (

    select
        PromotionKey as promotion_key,
        EnglishPromotionName as promotion_name,
        EnglishPromotionType as promotion_type,
        EnglishPromotionCategory as promotion_category,
        DiscountPct as discount_pct,
        MinQty as min_quantity,
        MaxQty as max_quantity,
        cast(StartDate as date) as start_date,
        cast(EndDate as date) as end_date

    from source

)

select * from renamed
