-- 026_view_gold_flat.sql
-- Create gold-layer flattened transaction view with calculated fields

create or replace view scout.v_gold_transactions_flat as
SELECT
  ft.transaction_id, ft.store_id, ft.customer_id, ft.campaign_id,
  ft.transaction_date, ft.transaction_time,
  ft.transaction_date + ft.transaction_time AS full_timestamp,
  ft.total_amount, ft.discount_amount, ft.tax_amount, ft.payment_method,
  ft.status, ft.source_file, ft.created_at,
  count(fti.transaction_id)              as item_count,
  sum(fti.quantity)                      as total_quantity,
  sum(fti.line_amount)                   as total_line_amount,
  sum(fti.discount_amount)               as total_item_discount,
  string_agg(distinct fti.sku, ', ' order by fti.sku) as skus,
  min(fti.unit_price)                    as min_unit_price,
  max(fti.unit_price)                    as max_unit_price,
  avg(fti.unit_price)::numeric(10,2)     as avg_unit_price,
  case
    when ft.source_file like '%.zip'  then 'ZIP'
    when ft.source_file like '%.json' then 'JSON'
    when ft.source_file like '%.csv'  then 'CSV'
    when ft.source_file = 'legacy/unknown' then 'LEGACY'
    else 'OTHER'
  end as source_type,
  case
    when ft.source_file like '%.zip'  then '📦'
    when ft.source_file like '%.json' then '📄'
    when ft.source_file like '%.csv'  then '📊'
    when ft.source_file = 'legacy/unknown' then '🕐'
    else '❓'
  end as source_icon,
  substring(ft.source_file from '[^/]+$')        as file_name,
  substring(ft.source_file from '^(.*/)[^/]+$')  as file_path,
  ft.total_amount - coalesce(ft.discount_amount,0) - coalesce(ft.tax_amount,0) as net_amount,
  case when ft.total_amount > 0
       then round((coalesce(ft.discount_amount,0)/ft.total_amount*100)::numeric,2)
       else 0 end as discount_percentage,
  extract(year  from ft.transaction_date)  as year,
  extract(month from ft.transaction_date)  as month,
  extract(day   from ft.transaction_date)  as day,
  to_char(ft.transaction_date, 'Day')      as day_of_week,
  to_char(ft.transaction_date, 'Month')    as month_name,
  extract(hour  from ft.transaction_time)  as hour,
  case when extract(hour from ft.transaction_time) < 12 then 'Morning'
       when extract(hour from ft.transaction_time) < 17 then 'Afternoon'
       when extract(hour from ft.transaction_time) < 21 then 'Evening'
       else 'Night' end                     as time_of_day
FROM scout.fact_transactions ft
LEFT JOIN scout.fact_transaction_items fti
  ON ft.transaction_id = fti.transaction_id
GROUP BY
  ft.transaction_id, ft.store_id, ft.customer_id, ft.campaign_id,
  ft.transaction_date, ft.transaction_time, ft.total_amount,
  ft.discount_amount, ft.tax_amount, ft.payment_method,
  ft.status, ft.source_file, ft.created_at;

-- Grant access to the view
grant select on scout.v_gold_transactions_flat to dash_ro, anon, authenticated;