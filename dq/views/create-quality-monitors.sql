-- Scout Edge: Data Quality Monitoring Views
-- Addresses TBWA requirement for quality metrics and monitoring

create schema if not exists suqi;

-- Item-level quality metrics
create materialized view if not exists suqi.item_quality as
select
  count(*)::bigint                                   as items_total,
  round(100.0*avg((i.brand_name is null)::int),2)    as brand_missing_pct,
  round(100.0*avg((i.category_name is null)::int),2) as category_missing_pct,
  round(100.0*avg((i.unit_price is null)::int),2)    as price_missing_pct,
  round(100.0*avg(((i.confidence is null) or (i.confidence<0.6))::int),2) as low_confidence_pct,
  round(avg(i.confidence)*100,2) as avg_confidence,
  count(distinct i.detection_method) as detection_methods_used
from public.scout_gold_transaction_items i;

-- Transaction-level quality metrics
create materialized view if not exists suqi.txn_quality as
select
  count(*)::bigint as tx_total,
  round(100.0*avg((t.gender is null or t.gender='unknown')::int),2) as demographics_missing_pct,
  round(100.0*avg((t.request_type is null)::int),2)                 as request_type_missing_pct,
  round(100.0*avg((t.transaction_amount is null)::int),2)           as amount_missing_pct,
  round(100.0*avg((t.suggestion_offered is not null)::int),2)       as suggestion_rate,
  round(100.0*avg((t.suggestion_accepted = true)::int),2)           as suggestion_acceptance_rate,
  count(distinct t.store_id) as active_stores
from public.scout_gold_transactions t;

-- Consolidated quality summary
create materialized view if not exists suqi.data_quality_summary as
select
  now() as report_timestamp,
  (select tx_total from suqi.txn_quality)              as transactions,
  (select items_total from suqi.item_quality)          as items,
  (select brand_missing_pct from suqi.item_quality)    as brand_missing_pct,
  (select category_missing_pct from suqi.item_quality) as category_missing_pct,
  (select price_missing_pct from suqi.item_quality)    as price_missing_pct,
  (select demographics_missing_pct from suqi.txn_quality) as demographics_missing_pct,
  (select low_confidence_pct from suqi.item_quality)   as low_confidence_pct,
  (select avg_confidence from suqi.item_quality)       as avg_confidence_score,
  (select active_stores from suqi.txn_quality)         as active_stores;

-- Daily quality trends
create materialized view if not exists suqi.daily_quality_trends as
select 
  date(t.ts_utc at time zone 'Asia/Manila') as date,
  count(distinct t.transaction_id) as transactions,
  count(i.id) as items,
  round(100.0*avg((i.brand_name is null)::int),2) as brand_missing_pct,
  round(100.0*avg((i.unit_price is null)::int),2) as price_missing_pct,
  round(avg(i.confidence)*100,2) as avg_confidence,
  round(100.0*avg((t.gender is null or t.gender='unknown')::int),2) as demo_missing_pct
from public.scout_gold_transactions t
join public.scout_gold_transaction_items i on t.transaction_id = i.transaction_id
where t.ts_utc >= current_date - interval '30 days'
group by date
order by date desc;

-- Create indexes for better performance
create index if not exists idx_quality_confidence on public.scout_gold_transaction_items(confidence);
create index if not exists idx_quality_brand on public.scout_gold_transaction_items(brand_name) where brand_name is null;
create index if not exists idx_quality_ts on public.scout_gold_transactions(ts_utc);

-- Refresh function (can be scheduled)
create or replace function suqi.refresh_quality_views()
returns void as $$
begin
  refresh materialized view concurrently suqi.item_quality;
  refresh materialized view concurrently suqi.txn_quality;
  refresh materialized view concurrently suqi.data_quality_summary;
  refresh materialized view concurrently suqi.daily_quality_trends;
end;
$$ language plpgsql;

-- Optional: Schedule refresh every 30 mins if pg_cron is available
do $$
begin
  if exists (select 1 from pg_extension where extname='pg_cron') then
    perform cron.schedule('refresh_suqi_quality', '*/30 * * * *', 'select suqi.refresh_quality_views()');
  end if;
end$$;

-- Quick quality check query
select * from suqi.data_quality_summary;