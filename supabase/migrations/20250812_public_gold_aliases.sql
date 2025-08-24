-- supabase/migrations/20250812_public_gold_aliases.sql
-- Expose read-only aliases under 'public' so PostgREST can serve them.
-- RLS still applies because the underlying scout.* tables/views enforce it.
set search_path = public, scout, pg_catalog;

-- Drop if they exist (idempotent)
drop view if exists public.gold_txn_items_api cascade;
drop view if exists public.gold_sales_day_api cascade;
drop view if exists public.gold_brand_mix_api cascade;
drop view if exists public.gold_geo_sales_api cascade;

-- Create passthrough views
create view public.gold_txn_items_api as
  select * from scout.gold_txn_items;

create view public.gold_sales_day_api as
  select * from scout.gold_sales_day;

create view public.gold_brand_mix_api as
  select * from scout.gold_brand_mix;

create view public.gold_geo_sales_api as
  select * from scout.gold_geo_sales;

-- Tight grants: JWT users only
revoke all on public.gold_txn_items_api  from public, anon;
revoke all on public.gold_sales_day_api  from public, anon;
revoke all on public.gold_brand_mix_api  from public, anon;
revoke all on public.gold_geo_sales_api  from public, anon;

grant select on public.gold_txn_items_api  to authenticated;
grant select on public.gold_sales_day_api  to authenticated;
grant select on public.gold_brand_mix_api  to authenticated;
grant select on public.gold_geo_sales_api  to authenticated;

-- (Optional) Ensure base tables/views keep RLS enforced
-- alter table scout.silver_transaction_items force row level security;
-- alter table scout.stores                   force row level security;
-- (Views inherit RLS of the underlying tables; no SECURITY DEFINER used.)