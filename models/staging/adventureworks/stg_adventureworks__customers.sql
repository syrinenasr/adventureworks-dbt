with

source as (

    select * from {{ source('adventureworks', 'DimCustomer') }}

),

renamed as (

    -- Contact details (email, phone, address lines) are left out on purpose:
    -- no model needs them, so they do not travel downstream.
    select
        CustomerKey as customer_key,
        CustomerAlternateKey as customer_number,
        GeographyKey as geography_key,

        FirstName as first_name,
        LastName as last_name,
        BirthDate as birth_date,
        case Gender
            when 'M' then 'Male'
            when 'F' then 'Female'
        end as gender,
        case MaritalStatus
            when 'M' then 'Married'
            when 'S' then 'Single'
        end as marital_status,
        YearlyIncome as yearly_income,
        TotalChildren as total_children,
        NumberChildrenAtHome as children_at_home,
        EnglishEducation as education,
        EnglishOccupation as occupation,
        HouseOwnerFlag = '1' as is_house_owner,
        NumberCarsOwned as cars_owned,
        CommuteDistance as commute_distance,
        DateFirstPurchase as first_purchase_date

    from source

)

select * from renamed
