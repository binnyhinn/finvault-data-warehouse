select customer_id
from {{ source('gold', 'dim_customer') }}
where is_current
group by customer_id
having count(*) <> 1
