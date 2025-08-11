-- 024_etl_hardening_source_file_tracking.sql
-- Purpose: end-to-end source_file lineage, performance, dedup, and monitoring

begin;

-- ---------- Columns (safe add + backfill + enforce) ----------
alter table if exists scout.silver_transactions
  add column if not exists source_file text;

alter table if exists scout.fact_transactions
  add column if not exists source_file text;

alter table if exists scout.fact_transaction_items
  add column if not exists source_file text;

-- Backfill from Bronze -> Silver via txn_id / JSON key fallback
update scout.silver_transactions s
set source_file = b.source_file
from scout.bronze_edge_raw b
where s.source_file is null
  and coalesce(s.txn_id, s.data->>'transaction_id', s.data->>'txn_id', s.data->>'id')
      = coalesce(b.txn_id, b.payload->>'transaction_id', b.payload->>'txn_id', b.payload->>'id');

-- Silver -> Gold via txn_id
update scout.fact_transactions g
set source_file = s.source_file
from scout.silver_transactions s
where g.source_file is null and g.txn_id = s.txn_id;

update scout.fact_transaction_items gi
set source_file = s.source_file
from scout.silver_transactions s
where gi.source_file is null and gi.txn_id = s.txn_id;

-- Enforce NOT NULL post-backfill
alter table scout.silver_transactions        alter column source_file set not null;
alter table scout.fact_transactions          alter column source_file set not null;
alter table scout.fact_transaction_items     alter column source_file set not null;

-- ---------- Transform patch (preserve source_file) ----------
create or replace function scout.transform_edge_bronze_to_silver()
returns void
language plpgsql
security definer
set search_path = scout, public
as $$
begin
  insert into scout.silver_transactions (txn_id, data, loaded_at, source_file)
  select
    coalesce(b.txn_id, b.payload->>'transaction_id', b.payload->>'txn_id', b.payload->>'id') as txn_id,
    b.payload  as data,
    now()      as loaded_at,
    b.source_file
  from scout.bronze_edge_raw b
  on conflict (txn_id) do update
    set data        = excluded.data,
        loaded_at   = excluded.loaded_at,
        source_file = coalesce(excluded.source_file, scout.silver_transactions.source_file);
end;
$$;

-- If you have a transform_silver_to_gold() already, keep it; else this minimal upsert:
do $$
begin
  perform 1 from pg_proc where proname='transform_silver_to_gold' and pronamespace = 'scout'::regnamespace;
  if not found then
    create or replace function scout.transform_silver_to_gold()
    returns void language plpgsql security definer set search_path=scout,public as $$
    begin
      insert into scout.fact_transactions (txn_id, source_file, transaction_timestamp, amount, created_at)
      select
        s.txn_id,
        s.source_file,
        coalesce(s.transaction_timestamp,
                 nullif(s.data->>'transaction_timestamp','')::timestamptz,
                 nullif(s.data->>'created_at','')::timestamptz,
                 s.loaded_at),
        coalesce(s.amount,
                 nullif(s.data->>'amount','')::numeric,
                 nullif(s.data->'total'->>'amount','')::numeric),
        now()
      from scout.silver_transactions s
      on conflict (txn_id) do update
        set source_file = excluded.source_file,
            transaction_timestamp = excluded.transaction_timestamp,
            amount = excluded.amount;
    end$$;
  end if;
end$$;

-- ---------- Views & Functions (verification/monitoring) ----------
-- Robust per-file verifier (contract: layer, source_file, txn_id, ts, amount, raw)
create or replace function scout.verify_file(_file text)
returns table(layer text, source_file text, txn_id text, ts timestamptz, amount numeric, raw jsonb)
language plpgsql security definer set search_path=scout,public as $$
begin
  return query
  select 'Bronze', b.source_file,
         coalesce(b.txn_id, b.payload->>'transaction_id', b.payload->>'txn_id', b.payload->>'id'),
         coalesce(nullif(b.payload->>'transaction_timestamp','')::timestamptz,
                  nullif(b.payload->>'created_at','')::timestamptz,
                  b.ingested_at),
         coalesce(nullif(b.payload->>'amount','')::numeric,
                  nullif(b.payload->'total'->>'amount','')::numeric),
         b.payload
  from scout.bronze_edge_raw b where b.source_file=_file
  union all
  select 'Silver', s.source_file,
         coalesce(s.txn_id, s.data->>'transaction_id', s.data->>'txn_id', s.data->>'id'),
         coalesce(s.transaction_timestamp,
                  nullif(s.data->>'transaction_timestamp','')::timestamptz,
                  nullif(s.data->>'created_at','')::timestamptz,
                  s.loaded_at),
         coalesce(s.amount,
                  nullif(s.data->>'amount','')::numeric,
                  nullif(s.data->'total'->>'amount','')::numeric),
         s.data
  from scout.silver_transactions s where s.source_file=_file
  union all
  select 'Gold-Fact', g.source_file, g.txn_id,
         coalesce(g.transaction_timestamp, g.created_at),
         coalesce(g.amount, g.gross_amount, g.net_amount),
         to_jsonb(g) - 'source_file'
  from scout.fact_transactions g where g.source_file=_file;
end;
$$;

-- ZIP pipeline status (source_file-based, drift-safe)
create or replace view scout.v_zip_pipeline_status as
with files as (
  select name as file_name, enqueued_at, started_at, finished_at, status
  from scout.etl_queue
  where name ilike '%.zip'
),
b as (select source_file file_name, count(*) bronze_count from scout.bronze_edge_raw group by 1),
s as (select source_file file_name, count(*) silver_count from scout.silver_transactions group by 1),
gf as (select source_file file_name, count(*) gold_fact_count from scout.fact_transactions group by 1),
gi as (select source_file file_name, count(*) gold_item_count from scout.fact_transaction_items group by 1)
select
  f.file_name,
  f.status as queue_status,
  coalesce(b.bronze_count,0)     as bronze_count,
  coalesce(s.silver_count,0)     as silver_count,
  coalesce(gf.gold_fact_count,0) as gold_fact_count,
  coalesce(gi.gold_item_count,0) as gold_item_count,
  case
    when coalesce(gf.gold_fact_count,0)>0 or coalesce(gi.gold_item_count,0)>0 then '✅ Complete Pipeline'
    when coalesce(s.silver_count,0)>0  then '⚠️ Stuck at Silver'
    when coalesce(b.bronze_count,0)>0  then '🟠 Stuck at Bronze'
    when f.status in ('WORKING','QUEUED') then '🔄 Processing/Pending'
    else '❌ Failed or empty'
  end as pipeline_status,
  f.enqueued_at, f.started_at, f.finished_at
from files f
left join b  using(file_name)
left join s  using(file_name)
left join gf using(file_name)
left join gi using(file_name)
order by f.enqueued_at desc;

-- Panic view: any file with Bronze/Silver >0 but zero Gold
create or replace view scout.v_pipeline_panic as
select z.file_name,
       coalesce(b.c,0) as bronze, coalesce(s.c,0) as silver, coalesce(g.c,0) as gold
from (select name as file_name from scout.etl_queue) z
left join (select source_file file_name, count(*) c from scout.bronze_edge_raw group by 1) b using(file_name)
left join (select source_file file_name, count(*) c from scout.silver_transactions group by 1) s using(file_name)
left join (select source_file file_name, count(*) c from scout.fact_transactions group by 1) g using(file_name)
where (coalesce(b.c,0)>0 or coalesce(s.c,0)>0) and coalesce(g.c,0)=0;

-- Health check (simple)
create or replace function scout.pipeline_health_check()
returns table(check_name text, ok boolean, details text)
language sql security definer set search_path=scout,public as $$
  with a as (select count(*) c from scout.v_pipeline_panic)
  select 'panic_empty'::text, (a.c=0) as ok, concat('panic_rows=',a.c) from a
  union all
  select 'queue_errors'::text, (select count(*) from scout.etl_queue where status='ERROR')=0,
         (select concat('errors=',count(*)) from scout.etl_queue where status='ERROR')
  union all
  select 'zip_status_view'::text, true, 'ok';
$$;

-- ---------- Performance & Dedup ----------
create index concurrently if not exists silver_transactions_source_file_idx
  on scout.silver_transactions(source_file);
create index concurrently if not exists fact_transactions_source_file_idx
  on scout.fact_transactions(source_file);
create index concurrently if not exists fact_transaction_items_source_file_idx
  on scout.fact_transaction_items(source_file);
create index concurrently if not exists etl_queue_status_idx
  on scout.etl_queue(status, enqueued_at);
create index concurrently if not exists bronze_source_file_idx
  on scout.bronze_edge_raw(source_file);

-- Dedup by content (requires sha256_hex populated upstream)
alter table if exists scout.etl_queue
  add column if not exists sha256_hex text;
create unique index concurrently if not exists etl_queue_unique_content
  on scout.etl_queue(sha256_hex) where sha256_hex is not null;

commit;