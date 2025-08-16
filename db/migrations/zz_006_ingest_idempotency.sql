-- Idempotent ingest & dedupe protections
create extension if not exists pgcrypto; -- for digest/sha

-- Deterministic event hash (order-insensitive over JSON keys)
create or replace function scout.fn_event_hash(p jsonb)
returns bytea
language sql immutable as $$
  select digest(
    (select jsonb_agg(kv order by kv)::text from jsonb_each(p) kv),
    'sha256'
  )
$$;

-- Source event hash column (nullable during rollout, then set not null)
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema='scout' and table_name='silver_transactions' and column_name='src_event_hash'
  ) then
    alter table scout.silver_transactions add column src_event_hash bytea;
  end if;
end$$;

-- Natural keys & hash uniqueness
create unique index if not exists ux_scout_txn_natural
  on scout.silver_transactions (id, store_id);

create unique index if not exists ux_scout_txn_event_hash
  on scout.silver_transactions (src_event_hash);

-- Ingest upsert helper (optionally used by Edge Function via RPC)
create or replace function scout.ingest_transaction(p jsonb)
returns text
language plpgsql
security definer
as $$
declare v_hash bytea; v_id text;
begin
  v_hash := scout.fn_event_hash(p);
  v_id := (p->>'id');

  -- example required key check
  if v_id is null then
    raise exception 'missing id in event';
  end if;

  insert into scout.silver_transactions(
    id, store_id, ts, time_of_day,
    barangay, city, province, region,
    product_category, brand_name, sku,
    units_per_transaction, peso_value, basket_size,
    request_mode, request_type, suggestion_accepted,
    gender, age_bracket, duration_seconds,
    campaign_influenced, handshake_score, is_tbwa_client,
    payment_method, customer_type, store_type, economic_class,
    src_event_hash
  )
  select
    p->>'id', p->>'store_id', (p->>'timestamp')::timestamptz, (p->>'time_of_day')::scout.time_of_day_t,
    p->>'barangay', p->>'city', p->>'province', p->>'region',
    p->>'product_category', p->>'brand_name', p->>'sku',
    (p->>'units_per_transaction')::int, (p->>'peso_value')::numeric, (p->>'basket_size')::int,
    (p->>'request_mode')::scout.request_mode_t, (p->>'request_type')::scout.request_type_t, (p->>'suggestion_accepted')::bool,
    (p->>'gender')::scout.gender_t, (p->>'age_bracket')::scout.age_bracket_t, (p->>'duration_seconds')::int,
    (p->>'campaign_influenced')::bool, (p->>'handshake_score')::numeric, (p->>'is_tbwa_client')::bool,
    (p->>'payment_method')::scout.payment_method_t, (p->>'customer_type')::scout.customer_type_t, (p->>'store_type')::scout.store_type_t, (p->>'economic_class')::scout.economic_class_t,
    v_hash
  on conflict (id, store_id) do update set
    ts = excluded.ts,
    src_event_hash = excluded.src_event_hash
  returning id into v_id;
  return v_id;
end $$;