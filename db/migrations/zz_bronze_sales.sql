-- Supabase analytics.sales -> Iceberg bronze.sales
select id, order_ts, region, store_id, amount
from postgresql."public".analytics_sales -- ensure Trino maps Supabase table
