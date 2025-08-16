-- Scout Edge: Health Monitoring & Observability

-- Enhanced crawl health view with more metrics
create or replace view scout.v_crawl_health_detailed as
select
  -- Queue metrics
  (select count(*) from scout.scraping_jobs where status='queued') as q_depth,
  (select count(*) from scout.scraping_jobs where status='running') as q_running,
  (select count(*) from scout.scraping_jobs where status='blocked') as q_blocked,
  (select count(*) from scout.scraping_jobs where status='failed' and locked_at > now() - interval '24 hours') as failed_24h,
  
  -- Cache metrics
  (select count(*) from scout.page_cache where fetched_at > now() - interval '24 hours') as pages_fetched_24h,
  (select count(*) from scout.page_cache where fetched_at > now() - interval '1 hour') as pages_fetched_1h,
  (select count(distinct content_sha256) from scout.page_cache where content_sha256 is not null and fetched_at > now() - interval '24 hours') as unique_content_24h,
  
  -- Master items metrics
  (select count(*) from scout.master_items where observed_at > now() - interval '24 hours') as items_ingested_24h,
  (select count(*) from scout.master_items where observed_at > now() - interval '1 hour') as items_ingested_1h,
  (select count(distinct brand_name) from scout.master_items where observed_at > now() - interval '24 hours') as unique_brands_24h,
  
  -- Performance metrics
  (select avg(extract(epoch from (locked_at - created_at))) from scout.scraping_jobs where status='done' and locked_at > now() - interval '1 hour') as avg_job_duration_seconds,
  (select max(locked_at) from scout.scraping_jobs where status='done') as last_completed_at;

-- Poison/blocked jobs that need review
create or replace view scout.v_blocked_jobs as
select 
  job_id, 
  source_id,
  url, 
  attempts, 
  note,
  locked_at,
  next_run_at
from scout.scraping_jobs 
where status='blocked' 
order by locked_at desc nulls last;

-- Product page churn detection
create or replace view scout.v_content_churn as
select 
  url,
  count(*) as fetch_count,
  count(distinct content_sha256) as unique_versions,
  min(fetched_at) as first_seen,
  max(fetched_at) as last_seen,
  case 
    when count(distinct content_sha256) > 5 then 'high'
    when count(distinct content_sha256) > 2 then 'medium'
    else 'low'
  end as churn_level
from scout.page_cache
where content_sha256 is not null
group by url
having count(*) > 1
order by unique_versions desc;

-- Domain performance
create or replace view scout.v_domain_performance as
select
  scout.domain_of(j.url) as domain,
  count(*) filter (where j.status='done') as completed,
  count(*) filter (where j.status='failed') as failed,
  count(*) filter (where j.status='blocked') as blocked,
  avg(j.attempts) filter (where j.status in ('done','failed','blocked')) as avg_attempts,
  max(d.rate_limit_ms) as rate_limit_ms,
  max(d.last_fetch_at) as last_fetch_at
from scout.scraping_jobs j
left join scout.domain_state d on scout.domain_of(j.url) = d.domain
group by 1
order by failed desc, blocked desc;

-- One-liner dashboard query for ops
create or replace function scout.dashboard_snapshot()
returns table(
  metric text,
  value numeric,
  unit text,
  status text
) language sql as $$
  select 'Queue Depth' as metric, q_depth::numeric as value, 'jobs' as unit,
    case when q_depth > 10000 then 'alert' when q_depth > 5000 then 'warn' else 'ok' end as status
  from scout.v_crawl_health_detailed
  union all
  select 'Running Jobs', q_running::numeric, 'jobs',
    case when q_running = 0 then 'alert' when q_running < 2 then 'warn' else 'ok' end
  from scout.v_crawl_health_detailed
  union all
  select 'Blocked Jobs', q_blocked::numeric, 'jobs',
    case when q_blocked > 100 then 'alert' when q_blocked > 50 then 'warn' else 'ok' end
  from scout.v_crawl_health_detailed
  union all
  select 'Pages/Hour', pages_fetched_1h::numeric, 'pages',
    case when pages_fetched_1h = 0 then 'alert' when pages_fetched_1h < 10 then 'warn' else 'ok' end
  from scout.v_crawl_health_detailed
  union all
  select 'Items/Hour', items_ingested_1h::numeric, 'items',
    case when items_ingested_1h = 0 then 'alert' when items_ingested_1h < 5 then 'warn' else 'ok' end
  from scout.v_crawl_health_detailed
  union all
  select 'Avg Job Time', round(avg_job_duration_seconds::numeric, 1), 'seconds',
    case when avg_job_duration_seconds > 30 then 'alert' when avg_job_duration_seconds > 15 then 'warn' else 'ok' end
  from scout.v_crawl_health_detailed
  order by 
    case status when 'alert' then 1 when 'warn' then 2 else 3 end,
    metric;
$$;