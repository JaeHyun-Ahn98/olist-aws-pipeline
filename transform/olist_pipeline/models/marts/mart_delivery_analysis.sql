-- 배송 지연 분석
-- 실제 배송일 vs 예상 배송일 비교
-- 지역별, 셀러별 지연율 분석

with orders as (
    select * from {{ ref('mart_orders') }}
    where order_status = 'delivered'
        and delivered_at is not null
        and estimated_delivery_at is not null
),

sellers as (
    select * from {{ ref('stg_sellers') }}
),

order_items as (
    select
        order_id,
        seller_id
    from {{ ref('stg_order_items') }}
),

final as (
    select
        o.order_id,
        o.customer_unique_id,
        o.state                                           as customer_state,
        s.seller_id,
        s.state                                           as seller_state,
        o.ordered_at,
        o.shipped_at,
        o.delivered_at,
        o.estimated_delivery_at,
        o.is_delayed,
        -- 실제 배송 소요일
        datediff(day, o.ordered_at, o.delivered_at)       as actual_delivery_days,
        -- 예상 배송 소요일
        datediff(day, o.ordered_at, o.estimated_delivery_at) as estimated_delivery_days,
        -- 지연일수 (음수면 빠른 배송, 양수면 지연)
        datediff(day, o.estimated_delivery_at, o.delivered_at) as delay_days
    from orders o
    left join order_items oi on o.order_id = oi.order_id
    left join sellers s on oi.seller_id = s.seller_id
)

select * from final