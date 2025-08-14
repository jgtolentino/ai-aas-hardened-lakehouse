-- Scout Edge Ingest: Minimal schema + validator
-- Supports brand.mention events with confidence gating ≥ 0.60

-- Prereqs
create extension if not exists pgcrypto;

-- Bronze event store (idempotent)
create table if not exists scout.bronze_events (
  event_id uuid primary key default gen_random_uuid(),
  event_type text not null,
  event_ts  timestamptz not null default now(),
  source_system text,
  event_data jsonb not null,
  event_hash bytea unique,          -- sha256 for idempotency
  ingested_at timestamptz not null default now()
);

-- Validator + ingestor for edge payloads
create or replace function scout.ingest_event(p jsonb)
returns table(accepted boolean, reason text) language plpgsql as $
declare t text; conf numeric;
begin
  t := coalesce(p->>'type','');
  if t = '' then return query select false, 'missing type'; return; end if;

  -- Minimal contract for brand.mention
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

-- Quick health view
create or replace view scout.v_edge_ingest_24h as
select
  count(*)                             as events_24h,
  count(*) filter (where event_type='brand.mention') as brand_mentions_24h,
  round(avg( nullif(event_data->>'confidence_calibrated','')::numeric )::numeric,3) as avg_conf_24h
from scout.bronze_events
where ingested_at > now() - interval '24 hours';