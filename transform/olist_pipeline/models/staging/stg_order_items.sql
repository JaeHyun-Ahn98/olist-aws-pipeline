with source as (
    select * from {{ source('raw', 'raw_order_items') }}
),

staged as (
    select distinct
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_date,
        price,
        freight_value
    from source
)

select * from staged