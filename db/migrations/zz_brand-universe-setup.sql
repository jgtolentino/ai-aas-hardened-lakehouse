-- Scout Edge: Brand Universe and Coverage Views
-- Unifies all brand sources into a single intelligent system

-- Extensions for normalization & fuzzy matching
create extension if not exists unaccent;
create extension if not exists pg_trgm;

-- 1) Brand Normalizer Function
create schema if not exists scout;
create or replace function scout.norm_brand(s text)
returns text language sql immutable as $$
  select nullif(regexp_replace(
    upper(unaccent(trim(coalesce(s,'')))),
    '[^A-Z0-9 ]',' ','g'
  ),'')
$$;

-- 2) Brand Universe (union of all known sources)
create or replace view scout.v_brand_universe as
with stt as (
  select distinct scout.norm_brand(brand) as brand,
         'stt_dict'::text as source
  from scout.stt_brand_dictionary
), cat as (
  select distinct scout.norm_brand(brand_name) as brand,
         'catalog'::text as source
  from suqi.ph_brand_catalog
), obs as (
  select distinct scout.norm_brand(brand_name) as brand,
         'observed'::text as source
  from public.scout_gold_transaction_items
  where brand_name is not null
), all_sources as (
  select * from stt union all select * from cat union all select * from obs
)
select brand,
       array_agg(distinct source order by source) as sources,
       (brand is not null) as valid
from all_sources
where brand is not null and brand <> ''
group by brand
order by brand;

-- 3) Variant Index (from STT dictionary)
create or replace view scout.v_variant_index as
select
  scout.norm_brand(brand)   as brand,
  scout.norm_brand(variant) as variant_norm,
  variant                   as variant_raw
from scout.stt_brand_dictionary
where variant is not null;

-- 4) Brand Coverage vs Events/Items
create or replace view scout.v_brand_coverage as
with items as (
  select
    scout.norm_brand(brand_name) as brand,
    count(*)                      as item_count,
    count(*) filter (where confidence >= 0.60) as item_count_reliable,
    max(ts.ts_utc)                as last_seen
  from public.scout_gold_transaction_items i
  join public.scout_gold_transactions ts using (transaction_id)
  group by 1
)
select
  u.brand,
  coalesce(i.item_count,0)          as item_count,
  coalesce(i.item_count_reliable,0) as item_count_reliable,
  i.last_seen,
  u.sources
from scout.v_brand_universe u
left join items i on i.brand = u.brand
order by item_count desc nulls last, brand;

-- 5) Unrecognized Brands View
create or replace view scout.v_brands_unrecognized as
with obs as (
  select scout.norm_brand(brand_name) as brand_obs,
         count(*) as n
  from public.scout_gold_transaction_items
  group by 1
)
select o.brand_obs as observed_value, o.n
from obs o
left join scout.v_brand_universe u on u.brand = o.brand_obs
where (o.brand_obs is null) or (u.brand is null)
order by n desc nulls last, observed_value;

-- 6) Brand Universe Summary
create or replace view scout.v_brand_universe_summary as
select
  count(*) as brands_total,
  count(*) filter (where 'observed' = any(sources)) as brands_observed,
  count(*) filter (where 'catalog'  = any(sources)) as brands_catalog,
  count(*) filter (where 'stt_dict' = any(sources)) as brands_stt_dict
from scout.v_brand_universe;

-- 7) Brand Performance Metrics
create or replace view scout.v_brand_performance as
select 
  b.brand,
  count(distinct i.transaction_id) as transactions,
  sum(i.qty) as units_sold,
  sum(i.total_price) as revenue,
  avg(i.confidence) as avg_confidence,
  count(distinct t.store_id) as stores,
  array_agg(distinct i.detection_method) as detection_methods
from scout.v_brand_universe b
join public.scout_gold_transaction_items i 
  on scout.norm_brand(i.brand_name) = b.brand
join public.scout_gold_transactions t 
  on i.transaction_id = t.transaction_id
where t.ts_utc >= current_date - interval '30 days'
group by b.brand
order by revenue desc nulls last;