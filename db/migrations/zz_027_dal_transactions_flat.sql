-- 027_dal_transactions_flat.sql
-- Create Data Access Layer (DAL) view with business-friendly column names

create or replace view scout.dal_transactions_flat as
select
  transaction_id as txn_id,
  store_id, customer_id, campaign_id,
  transaction_date as txn_date, transaction_time as txn_time,
  full_timestamp,
  total_amount as gross_sales,
  discount_amount as discount_value,
  tax_amount as tax_value,
  net_amount as net_sales,
  discount_percentage as discount_pct,
  payment_method,
  status as txn_status,
  item_count as line_items,
  total_quantity as units_sold,
  total_line_amount as gross_item_sales,
  total_item_discount as item_discounts,
  skus as product_skus,
  avg_unit_price as avg_price,
  source_type as data_source,
  source_icon as source_emoji,
  file_name as import_file,
  year as txn_year, month as txn_month, day as txn_day,
  day_of_week, month_name, hour as txn_hour, time_of_day as daypart,
  created_at as processed_at
from scout.v_gold_transactions_flat;

-- Grant access to the DAL view
grant select on scout.dal_transactions_flat to dash_ro, anon, authenticated;