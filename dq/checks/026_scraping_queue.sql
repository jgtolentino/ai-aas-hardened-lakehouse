create schema if not exists scout;

create table if not exists scout.scraping_jobs (
  job_id bigserial primary key,
  source_id uuid not null,
  url text not null,
  depth int default 0,
  priority smallint default 5 check (priority between 1 and 9),
  status text default 'queued' check (status in ('queued','running','done','failed','blocked')),
  attempts int default 0,
  next_run_at timestamptz default now(),
  locked_by text,
  locked_at timestamptz,
  parent_url text,
  note text,
  created_at timestamptz default now(),
  unique (source_id, url)
);

create table if not exists scout.page_cache (
  source_id uuid not null,
  url text not null,
  http_status int,
  etag text,
  last_modified timestamptz,
  content_sha256 text,
  fetched_at timestamptz,
  parse_status text,
  parse_note text,
  primary key (source_id, url)
);

create table if not exists scout.domain_state (
  domain text primary key,
  in_flight int default 0,
  last_fetch_at timestamptz,
  rate_limit_ms int default 1500
);

create or replace function scout.domain_of(u text) returns text
language sql immutable as
$$ select (regexp_match($1, '^https?://([^/]+)/?'))[1] $$;

create or replace function scout.robots_allowed(p_url text)
returns boolean language sql stable as $$ select true $$;

create or replace function scout.seed_jobs_from_sources(p_only_active boolean default true)
returns int language plpgsql as $$
declare r record; cnt int:=0; s jsonb; u text;
begin
  for r in
    select source_id, selectors, domain, coalesce(rate_limit_ms,1500) rl
    from scout.source_registry
    where (p_only_active is false) or (selectors ? 'start')
  loop
    insert into scout.domain_state(domain, rate_limit_ms)
    values (r.domain, r.rl)
    on conflict (domain) do update set rate_limit_ms = excluded.rate_limit_ms;

    s := r.selectors->'start';
    if jsonb_typeof(s)='array' then
      for u in select jsonb_array_elements_text(s) loop
        insert into scout.scraping_jobs(source_id, url, depth, priority)
        values (r.source_id, u, 0, 3)
        on conflict do nothing;
        cnt := cnt + 1;
      end loop;
    end if;
  end loop;
  return cnt;
end$$;

create or replace function scout.get_next_job(p_worker text, p_now timestamptz default now())
returns table(job_id bigint, source_id uuid, url text, depth int)
language plpgsql as $$
declare rec record; dom text; rl int; lastf timestamptz;
begin
  for rec in
    select j.job_id, j.source_id, j.url, j.depth
    from scout.scraping_jobs j
    where j.status='queued' and j.next_run_at <= p_now
    order by j.priority asc, j.created_at asc
  loop
    dom := scout.domain_of(rec.url);
    select rate_limit_ms, last_fetch_at into rl, lastf from scout.domain_state where domain=dom;
    if lastf is not null and (extract(epoch from (p_now - lastf))*1000) < coalesce(rl,1500) then
      continue;
    end if;

    update scout.scraping_jobs
       set status='running', locked_by=p_worker, locked_at=p_now, attempts=attempts+1
     where job_id=rec.job_id and status='queued'
     returning job_id into rec.job_id;

    if found then
      insert into scout.domain_state(domain, in_flight, last_fetch_at)
      values (dom, 1, p_now)
      on conflict (domain) do update
        set in_flight = scout.domain_state.in_flight + 1,
            last_fetch_at = excluded.last_fetch_at;

      job_id := rec.job_id; source_id := rec.source_id; url := rec.url; depth := rec.depth;
      return next;
    end if;
  end loop;
end$$;

create or replace function scout.report_job_result(
  p_job_id bigint,
  p_http_status int,
  p_etag text,
  p_last_modified timestamptz,
  p_content_sha256 text,
  p_parse_status text,
  p_parse_note text,
  p_discovered text[] default '{}'
) returns void language plpgsql as $$
declare v_source uuid; v_url text; v_dom text; v_now timestamptz := now(); v_depth int;
begin
  select source_id, url, depth into v_source, v_url, v_depth
  from scout.scraping_jobs where job_id=p_job_id for update;

  insert into scout.page_cache(source_id, url, http_status, etag, last_modified, content_sha256, fetched_at, parse_status, parse_note)
  values (v_source, v_url, p_http_status, p_etag, p_last_modified, p_content_sha256, v_now, p_parse_status, p_parse_note)
  on conflict (source_id, url) do update
  set http_status=excluded.http_status,
      etag=coalesce(excluded.etag, scout.page_cache.etag),
      last_modified=coalesce(excluded.last_modified, scout.page_cache.last_modified),
      content_sha256=coalesce(excluded.content_sha256, scout.page_cache.content_sha256),
      fetched_at=excluded.fetched_at,
      parse_status=excluded.parse_status,
      parse_note=excluded.parse_note;

  update scout.scraping_jobs
     set status = case when p_parse_status='error' then 'failed' else 'done' end
   where job_id=p_job_id;

  v_dom := scout.domain_of(v_url);
  update scout.domain_state set in_flight = greatest(in_flight-1,0), last_fetch_at=v_now where domain=v_dom;

  if p_discovered is not null and array_length(p_discovered,1) > 0 then
    insert into scout.scraping_jobs(source_id, url, depth, priority, parent_url)
    select v_source, u, v_depth+1, 6, v_url from unnest(p_discovered) as u
    on conflict do nothing;
  end if;
end$$;

create or replace function scout.schedule_recrawl() returns int language plpgsql as $$
declare r record; n int:=0; due interval;
begin
  for r in select c.source_id, c.url, coalesce(c.parse_status,'' ) ps, c.fetched_at from scout.page_cache c
  loop
    due := case when r.ps='ok' then interval '1 day' else interval '7 days' end;
    if r.fetched_at is null or r.fetched_at + due <= now() then
      insert into scout.scraping_jobs(source_id, url, depth, priority, status, next_run_at)
      values (r.source_id, r.url, 0, 6, 'queued', now())
      on conflict (source_id, url) do update
        set next_run_at = least(scout.scraping_jobs.next_run_at, now()),
            status='queued';
      n := n + 1;
    end if;
  end loop;
  return n;
end$$;

create or replace view scout.v_queue_pressure as
select
  scout.domain_of(url) as domain,
  count(*) filter (where status='queued') as queued,
  count(*) filter (where status='running') as running,
  count(*) filter (where status='failed') as failed,
  min(next_run_at) filter (where status='queued') as next_due
from scout.scraping_jobs
group by 1
order by queued desc;

create or replace view scout.v_crawl_health as
select
  (select count(*) from scout.scraping_jobs where status='queued') as q_depth,
  (select count(*) from scout.scraping_jobs where status='running') as q_running,
  (select count(*) from scout.scraping_jobs where status='failed' and locked_at > now() - interval '24 hours') as failed_24h,
  (select count(*) from scout.page_cache where fetched_at > now() - interval '24 hours') as pages_fetched_24h;
