-- Scout Scraper v0.1.0 - Production Database Setup
-- Minimal surfaces for scout-edge-ingest and quality-sentinel

-- 1.1 Minimal gold tables so scout-edge-ingest stops erroring
create schema if not exists scout;

create table if not exists scout.scout_gold_transactions (
  transaction_id text primary key,
  store_id text,
  ts_utc timestamptz,
  total_amount numeric,
  created_at timestamptz default now()
);

create table if not exists scout.scout_gold_transaction_items (
  id bigserial primary key,
  transaction_id text not null references scout.scout_gold_transactions(transaction_id) on delete cascade,
  brand_name text,
  product_name text,
  qty numeric,
  unit_price numeric,
  line_amount numeric,
  created_at timestamptz default now()
);

create index if not exists ix_gold_txn_ts on scout.scout_gold_transactions(ts_utc);
create index if not exists ix_gold_items_txn on scout.scout_gold_transaction_items(transaction_id);

-- 1.2 Quality sentinel stubs using requested names
create schema if not exists suqi;

-- Bronze events table for brand mentions
create table if not exists scout.bronze_events (
  event_id uuid primary key default gen_random_uuid(),
  event_type text not null,
  event_ts  timestamptz not null default now(),
  source_system text,
  event_data jsonb not null,
  event_hash bytea unique,
  ingested_at timestamptz not null default now()
);

-- Ingest event function
create or replace function scout.ingest_event(p jsonb)
returns table(accepted boolean, reason text) language plpgsql as $
declare t text; conf numeric;
begin
  t := coalesce(p->>'type','');
  if t = '' then return query select false, 'missing type'; return; end if;

  if t = 'brand.mention' then
    if not (p ? 'brand_name') then return query select false, 'missing brand_name'; return; end if;
    if not (p ? 'confidence_calibrated') then return query select false, 'missing confidence_calibrated'; return; end if;
    conf := nullif(p->>'confidence_calibrated','')::numeric;
    if conf is null then return query select false, 'confidence_calibrated not numeric'; return; end if;
    if conf < 0.60 then return query select false, 'below confidence gate (0.60)'; return; end if;
  end if;

  insert into scout.bronze_events(event_type, source_system, event_data, event_hash)
  values (t, p->>'device_id', p, digest(coalesce(p::text,''), 'sha256'))
  on conflict (event_hash) do nothing;

  return query select true, null::text;
end$;

-- Today's coarse quality summary (no GT yet)
create or replace function suqi.suqi_get_quality_summary()
returns json language sql stable as $
  select json_build_object(
    'ok', true,
    'brand_mentions_24h', coalesce((
      select count(*) from scout.bronze_events
      where event_type='brand.mention' and ingested_at> now()-interval '24 hours'
    ),0),
    'avg_conf_24h', round(coalesce((
      select avg(nullif(event_data->>'confidence_calibrated','')::numeric)
      from scout.bronze_events
      where event_type='brand.mention' and ingested_at> now()-interval '24 hours'
    ),0)::numeric, 3)
  );
$;

-- Confusion "today" placeholder (empty until GT exists)
create or replace function suqi.suqi_get_confusion_today()
returns json language sql stable as $
  select json_build_object(
    'ok', true,
    'confusion', json_build_array()
  );
$;

-- Edge ingest 24h view
create or replace view scout.v_edge_ingest_24h as
select
  count(*) as events_24h,
  count(*) filter (where event_type='brand.mention') as brand_mentions_24h,
  round(avg( nullif(event_data->>'confidence_calibrated','')::numeric )::numeric,3) as avg_conf_24h
from scout.bronze_events
where ingested_at > now() - interval '24 hours';

-- Brand KPIs view
create or replace view suqi.v_brand_kpis as
select
  coalesce(event_data->>'brand_name','(unknown)') as brand_name,
  count(*) as mentions,
  round(avg( nullif(event_data->>'confidence_calibrated','')::numeric )::numeric,3) as avg_conf
from scout.bronze_events
where event_type='brand.mention'
group by 1
order by mentions desc;