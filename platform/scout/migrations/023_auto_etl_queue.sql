-- ============================================================================
-- 023_auto_etl_queue.sql  |  Queue-driven ETL for Storage uploads
-- ============================================================================
begin;

create schema if not exists scout;

-- 1) Queue & DLQ -------------------------------------------------------------
create table if not exists scout.etl_queue (
  id            bigserial primary key,
  bucket_id     text          not null,
  name          text          not null, -- storage path
  size_bytes    bigint        not null default 0,
  mime_type     text,
  sha256_hex    text,                    -- optional checksum for idempotency
  status        text          not null default 'QUEUED', -- QUEUED|WORKING|DONE|ERROR
  attempts      int           not null default 0,
  last_error    text,
  enqueued_at   timestamptz   not null default now(),
  started_at    timestamptz,
  finished_at   timestamptz,
  constraint uq_queue unique (bucket_id, name)
);

create table if not exists scout.etl_failures (
  id           bigserial primary key,
  bucket_id    text not null,
  name         text not null,
  error_msg    text not null,
  attempts     int  not null,
  failed_at    timestamptz not null default now()
);

-- 2) Watermarks (already in your repo; create if missing) --------------------
create table if not exists scout.etl_watermarks (
  obj_id       text primary key,              -- storage.objects.id
  processed_at timestamptz not null default now(),
  ok           boolean not null default false,
  msg          text
);

-- 3) Bronze table (if missing) ----------------------------------------------
create table if not exists scout.bronze_edge_raw (
  source_file text not null,
  entry_name  text not null,
  txn_id      text,
  payload     jsonb not null,
  ingested_at timestamptz not null default now(),
  primary key (source_file, entry_name)
);
alter table scout.bronze_edge_raw enable row level security;
do $ begin
  if not exists (select 1 from pg_policies where schemaname='scout' and tablename='bronze_edge_raw') then
    create policy bronze_no_select on scout.bronze_edge_raw for select using (false);
  end if;
end $;

-- 4) Silver table (if missing) ----------------------------------------------
create table if not exists scout.silver_transactions (
  txn_id    text primary key,
  data      jsonb not null,
  loaded_at timestamptz not null default now()
);

-- 5) Transform function (bronze -> silver) ----------------------------------
create or replace function scout.transform_edge_bronze_to_silver()
returns void language plpgsql security definer set search_path=scout,public as $
begin
  insert into scout.silver_transactions (txn_id, data, loaded_at)
  select
    coalesce(b.txn_id, b.payload->>'transaction_id'),
    b.payload,
    now()
  from scout.bronze_edge_raw b
  on conflict (txn_id) do update
    set data = excluded.data, loaded_at = excluded.loaded_at;

  -- Optionally refresh materialized gold views here
  -- refresh materialized view concurrently scout.gold_txn_daily;
  -- refresh materialized view concurrently scout.gold_product_mix;
end;
$;

-- 6) Enqueue trigger function on storage.objects -----------------------------
create or replace function scout.enqueue_storage_upload()
returns trigger language plpgsql security definer set search_path=scout,public as $
declare
  v_ext text;
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

  -- Enqueue (idempotent)
  insert into scout.etl_queue(bucket_id, name, size_bytes, mime_type, status)
  values (NEW.bucket_id, NEW.name, NEW.metadata->>'size'::bigint, NEW.metadata->>'mimetype', 'QUEUED')
  on conflict (bucket_id, name) do nothing;

  return null;
end;
$;

drop trigger if exists trg_queue_storage_uploads on storage.objects;
create trigger trg_queue_storage_uploads
after insert on storage.objects
for each row
execute function scout.enqueue_storage_upload();

-- 7) Worker: process one batch safely ---------------------------------------
create or replace function scout.process_etl_queue(p_limit int default 100)
returns table(processed int, errors int) language plpgsql security definer
set search_path = scout, public as $
declare
  r record;
  ok_count int := 0;
  err_count int := 0;
  v_project_ref text := current_setting('request.jwt.claims', true); -- placeholder; ignore if null
begin
  for r in
    select *
    from scout.etl_queue
    where status in ('QUEUED','ERROR') and attempts < 5
    order by enqueued_at
    for update skip locked
    limit p_limit
  loop
    update scout.etl_queue
      set status='WORKING', attempts=attempts+1, started_at=now(), last_error=null
    where id=r.id;

    begin
      -- Call Edge Function to do the heavy work (uses service role inside function)
      perform from supabase_functions.http_request(
        'https://cxzllzyxwpyptfretryc.supabase.co/functions/v1/ingest-bronze',
        'POST',
        jsonb_build_object('Content-Type','application/json'),
        jsonb_build_object('bucket_id', r.bucket_id, 'name', r.name),
        120000
      );

      update scout.etl_queue
        set status='DONE', finished_at=now()
      where id=r.id;

      ok_count := ok_count + 1;
    exception when others then
      err_count := err_count + 1;
      update scout.etl_queue
        set status='ERROR', last_error=substr(sqlerrm,1,1000)
      where id=r.id;

      insert into scout.etl_failures(bucket_id, name, error_msg, attempts)
      values (r.bucket_id, r.name, substr(sqlerrm,1,1000), r.attempts+1);
    end;
  end loop;

  return query select ok_count as processed, err_count as errors;
end;
$;

-- 8) Convenience wrapper -----------------------------------------------------
create or replace function scout.auto_process_etl_pipeline()
returns table(processed int, errors int) language sql security definer
set search_path=scout,public as $
  select * from scout.process_etl_queue(250);
$;

-- 9) Monitoring view ---------------------------------------------------------
create or replace view scout.v_etl_pipeline_monitor as
select
  now() as ts,
  (select count(*) from scout.etl_queue where status='QUEUED') as queued,
  (select count(*) from scout.etl_queue where status='WORKING') as working,
  (select count(*) from scout.etl_queue where status='ERROR') as errors,
  (select count(*) from scout.etl_queue where status='DONE') as done,
  (select count(*) from scout.etl_failures where failed_at > now() - interval '24 hours') as failures_24h
;

-- 10) Optional: pg_cron to auto-run every 2 minutes (commented by default) ---
-- create extension if not exists pg_cron;
-- select cron.schedule('scout_etl_queue_every_2m', '*/2 * * * *', $select scout.process_etl_queue(250);$);

commit;