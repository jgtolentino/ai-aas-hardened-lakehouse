with s as (select * from {{ ref('silver_sales') }})
select date_trunc('day', order_ts) as day, region, sum(amount) as total_amount
from s
group by 1,2;
