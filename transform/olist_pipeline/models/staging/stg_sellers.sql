with source as (
    select * from {{ source('raw', 'raw_sellers') }}
),

staged as (
    select distinct
        seller_id,
        seller_zip_code_prefix as zip_code,
        seller_city            as city,
        seller_state           as state
    from source
)

select * from staged