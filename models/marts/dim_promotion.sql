with

promotions as (

    select * from {{ ref('stg_adventureworks__promotions') }}

),

final as (

    select
        promotion_key,
        promotion_name,
        promotion_type,
        promotion_category,
        discount_pct,
        min_quantity,
        max_quantity,
        start_date,
        end_date
    from promotions

)

select * from final
