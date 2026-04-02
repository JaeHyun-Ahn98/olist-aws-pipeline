with source as (
    select * from {{ source('raw', 'raw_customers') }}
),

staged as (
    select distinct
        customer_id,
        customer_unique_id,
        customer_zip_code_prefix as zip_code,
        customer_city            as city,
        customer_state           as state
    from source
)

select * from staged