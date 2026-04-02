with source as (
    select * from {{ source('raw', 'raw_category_translation') }}
),

staged as (
    select distinct
        product_category_name,
        product_category_name_english as category_name_english
    from source
)

select * from staged