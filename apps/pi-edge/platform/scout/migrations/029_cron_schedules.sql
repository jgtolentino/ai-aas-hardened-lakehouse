-- Scout Edge: Cron Schedules for Automated Operations
-- Requires pg_cron extension

-- Enable pg_cron if not already enabled
create extension if not exists pg_cron;

-- Hourly: schedule recrawl for due pages
select cron.schedule(
  'scout-recrawl-hourly',
  '15 * * * *', 
  $$select scout.schedule_recrawl()$$
);

-- Nightly: cleanup old jobs
select cron.schedule(
  'scout-cleanup-nightly',
  '10 2 * * *', 
  $$select scout.cleanup_old_jobs()$$
);

-- Every 6 hours: check for stuck running jobs (>2 hours)
select cron.schedule(
  'scout-unstick-jobs',
  '25 */6 * * *',
  $$
  update scout.scraping_jobs 
  set status='queued', 
      locked_by=null, 
      locked_at=null,
      note=coalesce(note,'') || ' | unstuck'
  where status='running' 
    and locked_at < now() - interval '2 hours'
  $$
);

-- View to check cron jobs
create or replace view scout.v_cron_jobs as
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
where jobname like 'scout-%'
order by jobname;