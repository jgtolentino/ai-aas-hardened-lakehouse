-- Quality Sentinel: Stub DB functions for health monitoring
-- Provides safe stubs until ground truth + confusion matrices are ready

create schema if not exists suqi;

-- KPIs by observed predictions (no ground truth yet)
create or replace view suqi.v_brand_kpis as
select
  coalesce(event_data->>'brand_name','(unknown)') as brand_name,
  count(*) as mentions,
  round(avg( nullif(event_data->>'confidence_calibrated','')::numeric )::numeric,3) as avg_conf
from scout.bronze_events
where event_type='brand.mention'
group by 1
order by mentions desc;

-- System health summary the sentinel can poll
create or replace function suqi.system_health_check()
returns table(check_name text, status text, value numeric, threshold numeric, details text)
language sql stable as $
  with base as (
    select
      count(*) filter (where event_type='brand.mention' and ingested_at> now()-interval '24 hours') as mentions_24h,
      avg(nullif(event_data->>'confidence_calibrated','')::numeric) filter (where event_type='brand.mention' and ingested_at> now()-interval '24 hours') as avg_conf_24h
    from scout.bronze_events
  )
  select 'mentions_24h','ok', coalesce(mentions_24h,0)::numeric, 1::numeric, 'brand.mention events in last 24h'
  from base
  union all
  select 'avg_conf_24h', case when coalesce(avg_conf_24h,0)>=0.7 then 'ok' else 'warn' end,
         coalesce(avg_conf_24h,0), 0.7, 'target >= 0.70'
  from base;
$;

-- Drift detector placeholder (returns empty set until you add store signals)
create or replace function suqi.detect_store_drift()
returns table(store_code text, window text, baseline numeric, observed numeric, drift_score numeric, detail text)
language sql stable as $
  select null::text, '24h', null::numeric, null::numeric, null::numeric, 'not implemented'
  where false;
$;