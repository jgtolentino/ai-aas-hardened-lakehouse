with src as (select * from {{ ref('bronze_sales') }})
select
  cast(id as bigint)          as id,
  cast(order_ts as timestamp) as order_ts,
  trim(region)                as region,
  trim(store_id)              as store_id,
  cast(amount as decimal(12,2)) as amount
from src
where amount is not null and region is not null;
