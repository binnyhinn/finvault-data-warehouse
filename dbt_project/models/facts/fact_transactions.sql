{{ config(materialized='incremental', unique_key='transaction_id') }}

select t.transaction_id,
       to_char(t.posting_date, 'YYYYMMDD')::int as date_key,
       a.account_key,
       c.customer_key,
       tt.txn_type_key,
       t.txn_ts,
       t.amount,
       case when t.status = 'POSTED'
            then case t.direction when 'CREDIT' then t.amount else -t.amount end
            else 0 end as signed_amount,
       t.direction,
       t.status,
       (t.status = 'POSTED') as is_posted,
       t.batch_id
from {{ source('silver', 'transactions') }} t
left join {{ source('gold', 'dim_account') }} a
       on a.account_id = t.account_id and t.txn_ts >= a.valid_from and t.txn_ts < a.valid_to
left join {{ source('gold', 'dim_customer') }} c
       on c.customer_id = a.customer_id and t.txn_ts >= c.valid_from and t.txn_ts < c.valid_to
left join {{ source('gold', 'dim_transaction_type') }} tt
       on tt.txn_type_code = t.txn_type_code
{% if is_incremental() %}
where t.batch_id > (select coalesce(max(batch_id), 0) from {{ this }})
{% endif %}
