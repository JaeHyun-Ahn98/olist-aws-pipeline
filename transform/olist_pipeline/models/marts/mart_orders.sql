-- 주문 + 고객 + 결제 조인한 분석용 테이블
with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

payments as (
    select
        order_id,
        sum(distinct payment_value)        as total_payment,
        count(distinct payment_sequential) as payment_count,
        max(payment_type)                  as payment_type
    from {{ ref('stg_order_payments') }}
    group by order_id
),

order_items as (
    select
        order_id,
        count(distinct order_item_id) as item_count,
        sum(distinct price)           as total_price,
        sum(distinct freight_value)   as total_freight
    from {{ ref('stg_order_items') }}
    group by order_id
),

final as (
    select
        o.order_id,
        o.customer_id,
        c.customer_unique_id,
        c.city,
        c.state,
        o.order_status,
        o.ordered_at,
        o.approved_at,
        o.shipped_at,
        o.delivered_at,
        o.estimated_delivery_at,
        p.total_payment,
        p.payment_count,
        p.payment_type,
        i.item_count,
        i.total_price,
        i.total_freight,
        -- 배송 지연 여부 (실제 배송일 - 예상 배송일)
        case
            when o.delivered_at > o.estimated_delivery_at then true
            else false
        end as is_delayed
    from orders o
    left join customers c on o.customer_id = c.customer_id
    left join payments p on o.order_id = p.order_id
    left join order_items i on o.order_id = i.order_id
)

select * from final