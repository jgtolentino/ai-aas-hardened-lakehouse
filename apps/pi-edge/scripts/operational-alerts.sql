-- Scout Edge: Operational Alerts and Monitoring
-- Functions for threshold-based alerting

-- Alert function for low recall/precision
create or replace function suqi.check_brand_metrics(
  min_recall numeric default 0.70,
  min_precision numeric default 0.70,
  min_f1 numeric default 0.70
) returns table(
  brand text,
  metric_type text,
  metric_value numeric,
  threshold numeric,
  severity text
) as $$
begin
  return query
  select 
    k.brand,
    'recall'::text as metric_type,
    k.recall as metric_value,
    min_recall as threshold,
    case 
      when k.recall < min_recall * 0.8 then 'critical'
      when k.recall < min_recall then 'high'
      else 'medium'
    end::text as severity
  from suqi.v_brand_kpis k
  where k.recall < min_recall
    and k.brand not in ('UNK', 'NULL')
  
  union all
  
  select 
    k.brand,
    'precision'::text,
    k.precision,
    min_precision,
    case 
      when k.precision < min_precision * 0.8 then 'critical'
      when k.precision < min_precision then 'high'
      else 'medium'
    end::text
  from suqi.v_brand_kpis k
  where k.precision < min_precision
    and k.brand not in ('UNK', 'NULL')
  
  union all
  
  select 
    k.brand,
    'f1_score'::text,
    k.f1_score,
    min_f1,
    case 
      when k.f1_score < min_f1 * 0.8 then 'critical'
      when k.f1_score < min_f1 then 'high'
      else 'medium'
    end::text
  from suqi.v_brand_kpis k
  where k.f1_score < min_f1
    and k.brand not in ('UNK', 'NULL')
  
  order by severity desc, metric_value asc;
end;
$$ language plpgsql;

-- Store drift detection
create or replace function suqi.detect_store_drift(
  lookback_days int default 7,
  min_accuracy numeric default 0.80
) returns table(
  store_id text,
  current_accuracy numeric,
  previous_accuracy numeric,
  accuracy_drop numeric,
  severity text
) as $$
begin
  return query
  with current_week as (
    select 
      store_id,
      avg(accuracy_pct) as accuracy
    from suqi.v_store_accuracy
    where date >= current_date - interval '3 days'
    group by store_id
  ),
  previous_week as (
    select 
      store_id,
      avg(accuracy_pct) as accuracy
    from suqi.v_store_accuracy
    where date between current_date - lookback_days - 3 and current_date - lookback_days
    group by store_id
  )
  select 
    c.store_id,
    round(c.accuracy, 2) as current_accuracy,
    round(p.accuracy, 2) as previous_accuracy,
    round(p.accuracy - c.accuracy, 2) as accuracy_drop,
    case
      when c.accuracy < min_accuracy * 0.7 then 'critical'
      when c.accuracy < min_accuracy then 'high'
      when p.accuracy - c.accuracy > 10 then 'medium'
      else 'low'
    end::text as severity
  from current_week c
  join previous_week p using (store_id)
  where c.accuracy < min_accuracy
     or (p.accuracy - c.accuracy) > 5
  order by severity desc, accuracy_drop desc;
end;
$$ language plpgsql;

-- Comprehensive health check
create or replace function suqi.system_health_check()
returns table(
  check_name text,
  status text,
  metric numeric,
  threshold numeric,
  details text
) as $$
begin
  return query
  
  -- Macro F1 check
  select 
    'macro_f1'::text,
    case when suqi.get_macro_f1() >= 0.70 then 'ok' else 'alert' end,
    suqi.get_macro_f1(),
    0.70,
    format('Current macro F1: %s', suqi.get_macro_f1())
  
  union all
  
  -- Brand coverage check
  select 
    'brand_coverage'::text,
    case when s.brand_missing_pct <= 20 then 'ok' else 'alert' end,
    100 - s.brand_missing_pct,
    80.0,
    format('Brand coverage: %s%%', round(100 - s.brand_missing_pct, 2))
  from suqi.data_quality_summary s
  
  union all
  
  -- Price capture check
  select 
    'price_capture'::text,
    case when s.price_missing_pct <= 20 then 'ok' else 'alert' end,
    100 - s.price_missing_pct,
    80.0,
    format('Price capture: %s%%', round(100 - s.price_missing_pct, 2))
  from suqi.data_quality_summary s
  
  union all
  
  -- Store count check
  select 
    'active_stores'::text,
    case when count(distinct store_id) >= 10 then 'ok' else 'alert' end,
    count(distinct store_id)::numeric,
    10.0,
    format('%s stores active in last 24h', count(distinct store_id))
  from public.scout_gold_transactions
  where ts_utc >= now() - interval '24 hours'
  
  union all
  
  -- Data freshness check
  select 
    'data_freshness'::text,
    case 
      when extract(epoch from (now() - max(ts_utc))) < 3600 then 'ok' 
      else 'alert' 
    end,
    extract(epoch from (now() - max(ts_utc)))::numeric / 60,
    60.0,
    format('Last transaction: %s minutes ago', 
      round(extract(epoch from (now() - max(ts_utc)))::numeric / 60))
  from public.scout_gold_transactions;
end;
$$ language plpgsql;

-- Create notification function for external integration
create or replace function suqi.send_alert_notification(
  alert_type text,
  severity text,
  message text,
  details jsonb default '{}'
) returns void as $$
begin
  -- Log to alert table
  insert into suqi.alert_log (alert_type, severity, message, metrics)
  values (alert_type, severity, message, details);
  
  -- Send postgres notification (external service listens)
  perform pg_notify('suqi_alerts', 
    jsonb_build_object(
      'type', alert_type,
      'severity', severity,
      'message', message,
      'details', details,
      'timestamp', now()
    )::text
  );
end;
$$ language plpgsql;