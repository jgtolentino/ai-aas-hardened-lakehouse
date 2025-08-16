\set ON_ERROR_STOP on
create schema if not exists deep_research;
create schema if not exists scout;

create table if not exists deep_research.sources(
  source_id uuid primary key default gen_random_uuid(),
  code text unique,
  name text not null,
  base_url text not null,
  country text default 'PH',
  category text,
  start_urls jsonb,
  selectors jsonb,
  expected_skus int,
  notes text,
  created_at timestamptz default now()
);

create table if not exists deep_research.jobs(
  job_id bigserial primary key,
  url text not null unique,
  region text,
  source text,
  status text default 'queued', -- queued|running|done|error|blocked
  last_error text,
  created_at timestamptz default now(),
  started_at timestamptz,
  finished_at timestamptz
);

create table if not exists deep_research.pages(
  page_id uuid primary key default gen_random_uuid(),
  source_id uuid references deep_research.sources(source_id) on delete set null,
  url text unique not null,
  fetched_at timestamptz,
  status int,
  html_hash text,
  payload jsonb,
  extract jsonb,
  region text,
  created_at timestamptz default now()
);

create table if not exists scout.brand_catalog(
  brand_id bigserial primary key,
  brand_name text not null,
  norm_name text generated always as (regexp_replace(lower(brand_name),'[^a-z0-9]+','','g')) stored unique,
  company text,
  category text,
  synonyms text[] default '{}',
  logo_url text,
  wikidata_qid text unique,
  off_brand_id text,
  created_at timestamptz default now()
);

create table if not exists scout.product_catalog(
  product_id bigserial primary key,
  brand_id bigint references scout.brand_catalog(brand_id) on delete set null,
  product_name text not null,
  norm_name text generated always as (regexp_replace(lower(product_name),'[^a-z0-9]+','','g')) stored,
  category text,
  is_tobacco boolean default false,
  off_code text unique,
  wikidata_qid text,
  created_at timestamptz default now()
);

create table if not exists scout.sku(
  sku_id bigserial primary key,
  product_id bigint references scout.product_catalog(product_id) on delete cascade,
  pack text,
  size_value numeric,
  size_unit text,
  variant text,
  upc text,
  image_url text,
  gtin text unique,
  created_at timestamptz default now()
);

create table if not exists scout.price_snapshot(
  snapshot_id bigserial primary key,
  sku_id bigint references scout.sku(sku_id) on delete cascade,
  region text,
  currency text default 'PHP',
  price numeric,
  availability text,
  url text,
  collected_at timestamptz default now(),
  is_srp boolean default false
);

create table if not exists scout.price_history(
  sku_id bigint references scout.sku(sku_id) on delete cascade,
  region text,
  day date,
  median_price numeric,
  min_price numeric,
  max_price numeric,
  sample_size int,
  primary key (sku_id, region, day)
);

create table if not exists scout.product_source(
  product_id bigint references scout.product_catalog(product_id) on delete cascade,
  source_code text,
  first_seen timestamptz default now(),
  primary key (product_id, source_code)
);

create table if not exists scout.brand_alias(
  alias text primary key,
  brand_id bigint references scout.brand_catalog(brand_id) on delete cascade
);

create or replace function scout.parse_pack(p text)
returns table(size_value numeric, size_unit text, pack text) language sql as $
  select
    (regexp_match(lower(p), '([0-9]+(\.[0-9]+)?)\s*(l|ml|g|kg|s)'))[1]::numeric,
    (regexp_match(lower(p), '([0-9]+(\.[0-9]+)?)\s*(l|ml|g|kg|s)'))[3],
    (regexp_match(lower(p), '(sachet|softpack|bottle|can|stick|pack|cup|pouch)'))[1]
$;

create or replace function scout.norm_gtin(p text) returns text language sql immutable as $
  select left(regexp_replace(coalesce(p,''), '\D', '', 'g'), 14)
$;

create or replace function scout.resolve_brand_id(p_name text)
returns bigint language sql stable as $
  with cand as (
    select brand_id, 1.0 as score from scout.brand_catalog
     where norm_name = regexp_replace(lower(p_name),'[^a-z0-9]+','','g')
    union all
    select a.brand_id, 0.95 as score from scout.brand_alias a
     where regexp_replace(lower(p_name),'[^a-z0-9]+','','g') = regexp_replace(lower(a.alias),'[^a-z0-9]+','','g')
    union all
    select brand_id, similarity(norm_name, regexp_replace(lower(p_name),'[^a-z0-9]+','','g')) as score
      from scout.brand_catalog
     where similarity(norm_name, regexp_replace(lower(p_name),'[^a-z0-9]+','','g')) >= 0.75
  )
  select brand_id from cand order by score desc limit 1;
$;

create or replace procedure scout.rollup_price_history(p_day date default current_date)
language sql as $
insert into scout.price_history(sku_id, region, day, median_price, min_price, max_price, sample_size)
select sku_id, coalesce(region,'PH'), p_day,
       percentile_cont(0.5) within group (order by price),
       min(price), max(price), count(*)
from scout.price_snapshot
where collected_at::date = p_day and price is not null
group by 1,2
on conflict (sku_id, region, day) do update
set median_price = excluded.median_price,
    min_price = excluded.min_price,
    max_price = excluded.max_price,
    sample_size = excluded.sample_size;
$;