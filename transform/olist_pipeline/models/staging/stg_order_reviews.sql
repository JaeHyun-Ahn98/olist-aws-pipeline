with source as (
    select * from {{ source('raw', 'raw_order_reviews') }}
),

staged as (
    select distinct
        review_id,
        order_id,
        review_score::integer          as review_score,
        review_comment_title           as comment_title,
        review_comment_message         as comment_message,
        review_creation_date::timestamp as created_at,
        review_answer_timestamp::timestamp as answered_at
    from source
)

select * from staged