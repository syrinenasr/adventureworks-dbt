-- A product has at most one current version, and when it has one, it is
-- its latest version. (Discontinued products have no current version.)

with

products as (

    select * from {{ ref('dim_product') }}

),

per_product as (

    select
        product_number,
        sum(case when is_current then 1 else 0 end) as current_versions,
        max(version_number) as latest_version,
        max(case when is_current then version_number end) as current_version
    from products
    group by product_number

)

select *
from per_product
where
    current_versions > 1
    or (current_versions = 1 and current_version != latest_version)
