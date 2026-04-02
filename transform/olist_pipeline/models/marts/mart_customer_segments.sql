-- 고객 세그먼트 — RFM 기반 K-Means 클러스터링 결과
-- EDA에서 도출한 세그먼트 기준 적용
-- R과 M 중심으로 세그먼트 분류 (F는 대부분 1회라 의미없음)

with rfm as (
    select * from {{ ref('mart_rfm') }}
),

segmented as (
    select
        customer_unique_id,
        recency,
        frequency,
        monetary,
        -- EDA K-Means 결과 기반 세그먼트 분류
        -- Active:   recency 낮음 + monetary 보통
        -- VIP:      monetary 높음 (1,140달러 이상)
        -- At-Risk:  recency 중간 + monetary 보통
        -- Lost:     recency 높음 + monetary 보통
        case
            when monetary >= 500 and recency <= 180  then 'VIP Customers'
            when monetary >= 500 and recency > 180   then 'VIP Customers'
            when recency <= 180                      then 'Active Customers'
            when recency between 181 and 365         then 'At-Risk Customers'
            else                                          'Lost Customers'
        end as segment
    from rfm
)

select * from segmented