-- ============================================================================
-- 024_etl_hardening.sql  |  Hardening for ETL Queue System
-- ============================================================================
begin;

-- Add size limit guard to enqueue function (max 200MB)
create or replace function scout.enqueue_storage_upload()
returns trigger language plpgsql security definer set search_path=scout,public as $
declare
  v_ext text;
  v_size_bytes bigint;
begin
  -- Only bucket/path of interest
  if NEW.bucket_id <> 'scout-ingest' then
    return null;
  end if;

  -- Only desired prefixes
  if position('edge-inbox/' in NEW.name) <> 1 and position('email-attachments/' in NEW.name) <> 1 then
    return null;
  end if;

  -- Only .json or .zip
  v_ext := lower(split_part(NEW.name, '.', array_length(string_to_array(NEW.name,'.'),1)));
  if v_ext not in ('json','zip') then
    return null;
  end if;

  -- Size limit check (200MB)
  v_size_bytes := coalesce((NEW.metadata->>'size')::bigint, 0);
  if v_size_bytes > 200 * 1024 * 1024 then
    insert into scout.etl_failures(bucket_id, name, error_msg, attempts)
    values (NEW.bucket_id, NEW.name, 'File too large: ' || v_size_bytes || ' bytes (max 200MB)', 0);
    return null;
  end if;

  -- Enqueue (idempotent)
  insert into scout.etl_queue(bucket_id, name, size_bytes, mime_type, status)
  values (NEW.bucket_id, NEW.name, v_size_bytes, NEW.metadata->>'mimetype', 'QUEUED')
  on conflict (bucket_id, name) do nothing;

  return null;
end;
$;

-- Add index for queue processing performance
create index if not exists idx_etl_queue_status_enqueued 
on scout.etl_queue(status, enqueued_at) 
where status in ('QUEUED', 'ERROR');

-- Add index for monitoring queries
create index if not exists idx_etl_failures_failed_at 
on scout.etl_failures(failed_at desc);

-- Enhanced monitoring view with more metrics
create or replace view scout.v_etl_pipeline_monitor as
select
  now() as ts,
  (select count(*) from scout.etl_queue where status='QUEUED') as queued,
  (select count(*) from scout.etl_queue where status='WORKING') as working,
  (select count(*) from scout.etl_queue where status='ERROR') as errors,
  (select count(*) from scout.etl_queue where status='DONE') as done,
  (select count(*) from scout.etl_failures where failed_at > now() - interval '24 hours') as failures_24h,
  (select count(*) from scout.etl_queue where status='ERROR' and attempts >= 5) as dead_letter,
  (select avg(extract(epoch from (finished_at - started_at))) 
   from scout.etl_queue 
   where status='DONE' and finished_at > now() - interval '1 hour') as avg_processing_seconds,
  (select sum(size_bytes)/1024/1024 
   from scout.etl_queue 
   where status='DONE' and finished_at > now() - interval '24 hours') as mb_processed_24h
;

-- Function to manually retry failed items
create or replace function scout.retry_failed_etl(p_name text default null)
returns table(reset_count int) language plpgsql security definer
set search_path=scout,public as $
declare
  v_count int;
begin
  if p_name is not null then
    -- Retry specific file
    update scout.etl_queue
    set status = 'QUEUED', attempts = 0, last_error = null
    where name = p_name and status = 'ERROR'
    returning 1 into v_count;
  else
    -- Retry all failed items with < 5 attempts
    update scout.etl_queue
    set status = 'QUEUED', attempts = 0, last_error = null
    where status = 'ERROR' and attempts < 5
    returning 1 into v_count;
  end if;
  
  return query select coalesce(sum(v_count), 0)::int as reset_count;
end;
$;

-- Function to move dead letter items to DLQ bucket
create or replace function scout.quarantine_dead_letters()
returns table(quarantined int) language plpgsql security definer
set search_path=scout,public as $
declare
  r record;
  v_count int := 0;
begin
  -- This function would ideally call an Edge Function to move files
  -- For now, just mark them
  for r in 
    select * from scout.etl_queue 
    where status = 'ERROR' and attempts >= 5
  loop
    insert into scout.etl_failures(bucket_id, name, error_msg, attempts)
    values (r.bucket_id, r.name, 'Moved to DLQ after 5 attempts: ' || r.last_error, r.attempts);
    
    update scout.etl_queue
    set status = 'QUARANTINED'
    where id = r.id;
    
    v_count := v_count + 1;
  end loop;
  
  return query select v_count as quarantined;
end;
$;

-- Grant permissions
grant execute on function scout.process_etl_queue(int) to service_role;
grant execute on function scout.auto_process_etl_pipeline() to authenticated;
grant select on scout.v_etl_pipeline_monitor to authenticated;

commit;