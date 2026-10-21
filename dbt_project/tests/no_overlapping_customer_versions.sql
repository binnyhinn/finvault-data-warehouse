select a.customer_id
from {{ source('gold', 'dim_customer') }} a
join {{ source('gold', 'dim_customer') }} b
  on a.customer_id = b.customer_id
 and a.customer_key < b.customer_key
 and a.valid_from < b.valid_to
 and b.valid_from < a.valid_to
