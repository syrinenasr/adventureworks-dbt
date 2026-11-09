-- Rebuilds the SCD type 2 validity ranges of products from the history rows
-- in the source. The source EndDate cannot be trusted (it is earlier than
-- StartDate on every history row), so:
--   valid_from = the version's start date
--   valid_to   = the start date of the product's next version;
--                for the last version of a discontinued product, the date of
--                the next catalogue release (the first release it is missing
--                from); null for the current version.
-- Ranges are half-open: valid_from <= date < valid_to.

with

products as (

    select * from {{ ref('stg_adventureworks__products') }}

),

catalogue_releases as (

    select distinct source_start_date as release_date
    from products

),

releases_with_next as (

    select
        release_date,
        lead(release_date) over (order by release_date) as next_release_date
    from catalogue_releases

),

versions as (

    select
        products.*,
        row_number() over (
            partition by products.product_number
            order by products.source_start_date
        ) as version_number,
        lead(products.source_start_date) over (
            partition by products.product_number
            order by products.source_start_date
        ) as next_version_start_date
    from products

),

final as (

    select
        versions.product_key,
        versions.product_number,
        versions.version_number,
        versions.product_subcategory_key,
        versions.product_name,
        versions.model_name,
        versions.product_description,
        versions.color,
        versions.size,
        versions.size_range,
        versions.weight,
        versions.weight_unit,
        versions.product_line_code,
        versions.class_code,
        versions.style_code,
        versions.is_finished_good,
        versions.days_to_manufacture,
        versions.standard_cost,
        versions.list_price,
        versions.dealer_price,
        versions.source_start_date as valid_from,
        case
            when versions.is_current_in_source then null
            else
                coalesce(
                    versions.next_version_start_date,
                    releases_with_next.next_release_date
                )
        end as valid_to,
        versions.is_current_in_source as is_current
    from versions
    inner join releases_with_next
        on versions.source_start_date = releases_with_next.release_date

)

select * from final
