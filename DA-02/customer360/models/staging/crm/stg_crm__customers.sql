with source as (

    select * from {{ source('crm', 'customers') }}

),

renamed as (

    select
        customer_id,
        first_name,
        last_name,
        lower(trim(email))          as email,
        country,
        cast(signup_date as date)   as signup_date
    from source

)

select * from renamed
