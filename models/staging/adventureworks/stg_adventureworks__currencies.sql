with

source as (

    select * from {{ source('adventureworks', 'DimCurrency') }}

),

renamed as (

    select
        CurrencyKey as currency_key,
        trim(CurrencyAlternateKey) as currency_code,
        CurrencyName as currency_name

    from source

)

select * from renamed
