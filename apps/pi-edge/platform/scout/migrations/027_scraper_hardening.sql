-- Scout Edge: Production Hardening for SKU Scraper
-- Indexes, exponential backoff, poison queue, TTL cleanup

-- === Indexes (queue throughput & cache lookups) ===
create index if not exists ix_jobs_status_next on scout.scraping_jobs(status, next_run_at);
create index if not exists ix_jobs_priority_created on scout.scraping_jobs(priority, created_at)
  where status='queued';
create index if not exists ix_jobs_locked on scout.scraping_jobs(status, locked_at)
  where status='running';
create index if not exists ix_cache_fetch on scout.page_cache(fetched_at);
create index if not exists ix_cache_sha on scout.page_cache(content_sha256) where content_sha256 is not null;

-- === Exponential backoff for transient fails (429/503) ===
create or replace function scout.fail_with_backoff(p_job_id bigint, p_reason text)
returns void language plpgsql as $$
declare v_attempts int;
begin
  update scout.scraping_jobs
     set status='failed',
         note=left(coalesce(note,'') || ' | ' || coalesce(p_reason,''), 500),
         attempts=attempts+1,
         next_run_at = now() + ((2 ^ least(attempts,6))::text || ' minutes')::interval
   where job_id=p_job_id;

  select attempts into v_attempts from scout.scraping_jobs where job_id=p_job_id;
  if v_attempts >= 6 then
    update scout.scraping_jobs
       set status='blocked',
           note=left(coalesce(note,'') || ' | quarantined after '||v_attempts||' attempts', 500)
     where job_id=p_job_id;
  end if;
end$$;

-- === TTL cleanup (done/failed older than 30 days) ===
create or replace function scout.cleanup_old_jobs()
returns int language plpgsql as $$
declare n int;
begin
  delete from scout.scraping_jobs
   where status in ('done','failed') and locked_at < now() - interval '30 days';
  get diagnostics n = row_count;
  return n;
end$$;

-- === Safety: prevent double-run on the same job_id ===
create or replace function scout.guard_running_once() returns trigger language plpgsql as $$
begin
  if new.status='running' then
    if exists (
      select 1 from scout.scraping_jobs
      where job_id<>new.job_id and status='running' and url=new.url
    ) then
      raise exception 'another running job for %', new.url;
    end if;
  end if;
  return new;
end$$;

drop trigger if exists trg_guard_running_once on scout.scraping_jobs;
create trigger trg_guard_running_once before update on scout.scraping_jobs
for each row when (old.status='queued' and new.status='running')
execute procedure scout.guard_running_once();