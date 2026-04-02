-- RFM 분석 — EDA에서 계산한 것을 SQL로 구현
-- R(Recency): 마지막 구매일로부터 경과 일수
-- F(Frequency): 총 구매 횟수
-- M(Monetary): 총 결제 금액

with delivered_orders as (
    -- 실제 완료된 주문만 사용
    select * from {{ ref('mart_orders') }}
    where order_status = 'delivered'
        and delivered_at is not null
),

rfm as (
    select
        customer_unique_id,
        datediff(day, max(ordered_at),
            (select dateadd(day, 1, max(ordered_at)) from delivered_orders)
        ) as recency,
        count(order_id)      as frequency,
        sum(total_payment)   as monetary
    from delivered_orders
    group by customer_unique_id
)

select * from rfm