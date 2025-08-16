-- Scout Edge: Operational Kill-Switches & Controls

-- Function to pause/throttle a domain
create or replace function scout.throttle_domain(p_domain text, p_rate_limit_ms int default 60000)
returns void language plpgsql as $$
begin
  update scout.domain_state 
  set rate_limit_ms = p_rate_limit_ms 
  where domain = p_domain;
  
  if not found then
    insert into scout.domain_state(domain, rate_limit_ms)
    values (p_domain, p_rate_limit_ms);
  end if;
  
  raise notice 'Domain % throttled to %ms between requests', p_domain, p_rate_limit_ms;
end$$;

-- Function to quarantine all jobs for a source
create or replace function scout.quarantine_source(p_source_id uuid, p_reason text default 'ops quarantine')
returns int language plpgsql as $$
declare n int;
begin
  update scout.scraping_jobs
     set status='blocked', 
         note=left(coalesce(note,'')||' | '||p_reason, 500)
   where source_id=p_source_id 
     and status='queued';
  
  get diagnostics n = row_count;
  
  raise notice 'Quarantined % jobs for source %', n, p_source_id;
  return n;
end$$;

-- Function to release quarantined jobs
create or replace function scout.release_quarantine(p_source_id uuid default null, p_domain text default null)
returns int language plpgsql as $$
declare n int;
begin
  if p_source_id is not null then
    update scout.scraping_jobs
       set status='queued',
           note=left(coalesce(note,'')||' | released', 500),
           next_run_at=now()
     where source_id=p_source_id
       and status='blocked';
  elsif p_domain is not null then
    update scout.scraping_jobs
       set status='queued',
           note=left(coalesce(note,'')||' | released', 500),
           next_run_at=now()
     where scout.domain_of(url) = p_domain
       and status='blocked';
  else
    raise exception 'Must specify either source_id or domain';
  end if;
  
  get diagnostics n = row_count;
  return n;
end$$;

-- Emergency stop all running jobs
create or replace function scout.emergency_stop()
returns int language plpgsql as $$
declare n int;
begin
  update scout.scraping_jobs
     set status='queued',
         locked_by=null,
         locked_at=null,
         note=coalesce(note,'')||' | emergency stop'
   where status='running';
  
  get diagnostics n = row_count;
  
  -- Also throttle all domains to prevent immediate restart
  update scout.domain_state set rate_limit_ms = 300000; -- 5 minutes
  
  raise notice 'Emergency stop: % jobs halted, all domains throttled to 5min', n;
  return n;
end$$;

-- View for operational controls status
create or replace view scout.v_operational_status as
select
  -- Throttled domains
  (select count(*) from scout.domain_state where rate_limit_ms > 10000) as throttled_domains,
  (select array_agg(domain || ':' || rate_limit_ms || 'ms' order by rate_limit_ms desc) 
   from scout.domain_state where rate_limit_ms > 10000) as throttled_list,
  
  -- Quarantined sources
  (select count(distinct source_id) from scout.scraping_jobs where status='blocked') as quarantined_sources,
  
  -- System pressure
  (select count(*) from scout.scraping_jobs where status='queued') as total_queued,
  (select count(*) from scout.scraping_jobs where status='running') as total_running,
  (select count(distinct scout.domain_of(url)) from scout.scraping_jobs where status='running') as active_domains;

-- Helper function to inspect a specific job
create or replace function scout.inspect_job(p_job_id bigint)
returns table(
  job_id bigint,
  source_id uuid,
  url text,
  domain text,
  status text,
  attempts int,
  created_at timestamptz,
  locked_at timestamptz,
  next_run_at timestamptz,
  note text,
  last_fetch timestamptz,
  parse_status text,
  items_found int
) language sql as $$
  select 
    j.job_id,
    j.source_id,
    j.url,
    scout.domain_of(j.url) as domain,
    j.status,
    j.attempts,
    j.created_at,
    j.locked_at,
    j.next_run_at,
    j.note,
    c.fetched_at as last_fetch,
    c.parse_status,
    (select count(*) from scout.master_items m where m.source_url = j.url) as items_found
  from scout.scraping_jobs j
  left join scout.page_cache c on j.source_id = c.source_id and j.url = c.url
  where j.job_id = p_job_id;
$$;