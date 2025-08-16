create table if not exists public.scout_gold_transactions (
  id bigserial primary key,
  transaction_id text unique not null,
  store_id text not null,
  tz_offset_min int not null,
  ts_utc timestamptz not null,
  tx_start_ts timestamptz not null,
  tx_end_ts timestamptz not null,
  request_type text not null check (request_type in ('branded','unbranded','point','indirect')),
  request_mode text not null check (request_mode in ('verbal','pointing','indirect')),
  payment_method text not null check (payment_method in ('cash','gcash','maya','credit','other')),
  gender text check (gender in ('male','female','unknown')),
  age_bracket text check (age_bracket in ('18-24','25-34','35-44','45-54','55+','unknown')),
  region_id int null, city_id int null, barangay_id int null,
  suggestion_offered boolean null, suggestion_accepted boolean null,
  asked_brand_id int null, final_brand_id int null,
  transaction_amount numeric null, price_source text null,
  raw jsonb not null
);

create table if not exists public.scout_gold_transaction_items (
  id bigserial primary key,
  transaction_id text not null references public.scout_gold_transactions(transaction_id) on delete cascade,
  category_id int null, category_name text not null,
  brand_id int null, brand_name text null,
  product_name text not null,
  local_name text null,
  qty int not null check (qty > 0),
  unit text not null default 'pc',
  unit_price numeric null,
  total_price numeric null,
  detection_method text not null check (detection_method in ('stt','vision','ocr','hybrid')),
  confidence numeric not null check (confidence >= 0 and confidence <= 1)
);

-- optional explainability sink
create table if not exists public.edge_decision_trace (
  id bigserial primary key,
  transaction_id text not null,
  trace jsonb not null,
  created_at timestamptz not null default now()
);

-- speedups
create index if not exists idx_tx_ts on public.scout_gold_transactions (ts_utc);
create index if not exists idx_tx_store on public.scout_gold_transactions (store_id);
create index if not exists idx_item_tx on public.scout_gold_transaction_items (transaction_id);