-- Scout Edge: Brand Coverage and Quality Reports
-- Quick queries to assess brand resolution effectiveness

-- 1. Brand Universe Summary
select * from scout.v_brand_universe_summary;

-- 2. Top 50 Brands by Coverage
select * from scout.v_brand_coverage limit 50;

-- 3. Top 50 Unrecognized Brand Observations
select * from scout.v_brands_unrecognized limit 50;

-- 4. Brand Performance (Last 30 Days)
select * from scout.v_brand_performance limit 50;

-- 5. Brand Resolution Effectiveness
with stats as (
  select 
    count(*) as total_items,
    count(brand_name) as items_with_brand,
    count(*) filter (where confidence >= 0.60) as high_confidence_items,
    count(brand_name) filter (where confidence >= 0.60) as high_conf_with_brand
  from public.scout_gold_transaction_items
  where transaction_id in (
    select transaction_id 
    from public.scout_gold_transactions 
    where ts_utc >= current_date - interval '7 days'
  )
)
select 
  total_items,
  items_with_brand,
  round(100.0 * items_with_brand / nullif(total_items, 0), 2) as brand_coverage_pct,
  high_confidence_items,
  round(100.0 * high_conf_with_brand / nullif(high_confidence_items, 0), 2) as high_conf_brand_coverage_pct
from stats;

-- 6. Detection Method vs Brand Coverage
select 
  detection_method,
  count(*) as items,
  count(brand_name) as with_brand,
  round(100.0 * count(brand_name) / count(*), 2) as brand_coverage_pct,
  round(avg(confidence), 3) as avg_confidence
from public.scout_gold_transaction_items
group by detection_method
order by items desc;

-- 7. Brand Variant Effectiveness
with variant_hits as (
  select 
    v.brand,
    v.variant_raw,
    count(distinct i.id) as matches
  from scout.v_variant_index v
  join public.scout_gold_transaction_items i
    on scout.norm_brand(i.brand_name) = v.brand
       or scout.norm_brand(i.product_name) like '%' || v.variant_norm || '%'
       or scout.norm_brand(i.local_name) like '%' || v.variant_norm || '%'
  group by v.brand, v.variant_raw
)
select 
  brand,
  variant_raw as variant,
  matches
from variant_hits
order by matches desc
limit 50;

-- 8. Daily Brand Coverage Trend
select 
  date(t.ts_utc at time zone 'Asia/Manila') as date,
  count(i.id) as total_items,
  count(i.brand_name) as items_with_brand,
  round(100.0 * count(i.brand_name) / count(i.id), 2) as brand_coverage_pct,
  count(distinct i.brand_name) as unique_brands
from public.scout_gold_transactions t
join public.scout_gold_transaction_items i using (transaction_id)
where t.ts_utc >= current_date - interval '14 days'
group by date
order by date desc;

-- 9. Store-Level Brand Coverage
select 
  t.store_id,
  count(i.id) as total_items,
  count(i.brand_name) as items_with_brand,
  round(100.0 * count(i.brand_name) / count(i.id), 2) as brand_coverage_pct,
  count(distinct i.brand_name) as unique_brands,
  max(t.ts_utc) as last_transaction
from public.scout_gold_transactions t
join public.scout_gold_transaction_items i using (transaction_id)
where t.ts_utc >= current_date - interval '7 days'
group by t.store_id
order by total_items desc
limit 20;

-- 10. Category vs Brand Coverage
select 
  coalesce(category_name, 'Unknown') as category,
  count(*) as items,
  count(brand_name) as with_brand,
  round(100.0 * count(brand_name) / count(*), 2) as brand_coverage_pct,
  array_agg(distinct brand_name order by brand_name) 
    filter (where brand_name is not null) as brands
from public.scout_gold_transaction_items
group by category_name
order by items desc;