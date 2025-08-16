with s as (select * from {{ ref('silver_sales') }})
select
  region as entity,
  'sales_7d' as feature_name,
  json_build_object('value', sum(amount)) as feature_value,
  max(order_ts) as as_of
from s
where order_ts >= current_date - interval '7' day
group by region;
