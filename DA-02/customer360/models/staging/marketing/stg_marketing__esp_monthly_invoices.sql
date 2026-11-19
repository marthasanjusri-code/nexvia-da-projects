with source as (

    select * from {{ source('marketing', 'esp_monthly_invoices') }}

),

renamed as (

    select
        cast(invoice_month as date)                 as invoice_month,
        provider,
        plan,
        cast(contacts as int64)                     as contacts,
        cast(round(amount_usd, 2) as numeric)       as amount_usd
    from source

)

select * from renamed
