with

customers as (

    select * from {{ ref('stg_adventureworks__customers') }}

),

geographies as (

    select * from {{ ref('stg_adventureworks__geographies') }}

),

final as (

    select
        customers.customer_key,
        customers.customer_number,
        customers.first_name,
        customers.last_name,
        {{ dbt.concat(["customers.first_name", "' '", "customers.last_name"]) }} as full_name,
        customers.birth_date,
        customers.gender,
        customers.marital_status,
        customers.yearly_income,
        customers.total_children,
        customers.children_at_home,
        customers.education,
        customers.occupation,
        customers.is_house_owner,
        customers.cars_owned,
        customers.commute_distance,
        customers.first_purchase_date,
        geographies.city,
        geographies.state_province_name,
        geographies.country_code,
        geographies.country_name,
        geographies.postal_code
    from customers
    left join geographies
        on customers.geography_key = geographies.geography_key

)

select * from final
