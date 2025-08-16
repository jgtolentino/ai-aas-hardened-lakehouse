-- Scout Edge: Evaluation Loop Scheduling
-- Automated confusion matrix computation and quality refresh

-- Enable pg_cron if not already
create extension if not exists pg_cron;

-- Schedule hourly confusion matrix update (last 24h)
select cron.schedule(
  'suqi_confusion_hourly', 
  '5 * * * *',
  $$
    -- Sync latest predictions
    select suqi.sync_brand_predictions();
    
    -- Compute confusion matrix
    select suqi.compute_brand_confusion('24 hours');
  $$
);

-- Schedule nightly quality view refresh
select cron.schedule(
  'suqi_quality_refresh', 
  '30 2 * * *',
  $$
    refresh materialized view concurrently suqi.item_quality;
    refresh materialized view concurrently suqi.txn_quality;
    refresh materialized view concurrently suqi.data_quality_summary;
    refresh materialized view concurrently suqi.daily_quality_trends;
  $$
);

-- Schedule daily macro F1 check and alert
select cron.schedule(
  'suqi_f1_daily_check',
  '0 7 * * *',
  $$
    do $$
    declare 
      macro_f1 numeric;
      min_threshold numeric := 0.70;
    begin
      macro_f1 := suqi.get_macro_f1();
      
      if macro_f1 < min_threshold then
        insert into suqi.alert_log (alert_type, severity, message, metrics)
        values (
          'LOW_MACRO_F1',
          'high',
          format('Brand macro F1 score dropped to %s (threshold: %s)', macro_f1, min_threshold),
          jsonb_build_object('macro_f1', macro_f1, 'threshold', min_threshold)
        );
        
        -- Notify via postgres NOTIFY (external listener can forward to Slack/etc)
        perform pg_notify('suqi_alerts', 
          format('LOW_F1:%s', macro_f1)
        );
      end if;
    end$$;
  $$
);

-- Create alert log table
create table if not exists suqi.alert_log (
  id bigserial primary key,
  alert_type text not null,
  severity text not null check (severity in ('low','medium','high','critical')),
  message text not null,
  metrics jsonb,
  created_at timestamptz default now()
);

-- View scheduled jobs
create or replace view suqi.v_scheduled_jobs as
select 
  jobname,
  schedule,
  command,
  nodename,
  nodeport,
  database,
  username,
  active
from cron.job
where jobname like 'suqi_%'
order by jobname;