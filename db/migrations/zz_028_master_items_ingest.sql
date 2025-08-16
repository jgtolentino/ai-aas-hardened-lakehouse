-- Scout Edge: Master Items Catalog Tables and Ingest
-- Central repository for all scraped SKUs

-- Minimal target tables (adjust if you already have richer ones)
create table if not exists scout.master_items (
  item_id bigserial primary key,
  source_id uuid,
  source_url text,
  brand_name text,
  product_name text,
  product_category text,
  pack_size_value numeric,
  pack_size_unit text,
  list_price numeric,
  currency text default 'PHP',
  content_sha256 text,
  observed_at timestamptz default now(),
  unique (source_id, source_url, brand_name, product_name, pack_size_value, pack_size_unit)
);

-- Indexes for master items
create index if not exists ix_master_items_brand on scout.master_items(brand_name);
create index if not exists ix_master_items_observed on scout.master_items(observed_at);
create index if not exists ix_master_items_source on scout.master_items(source_id);
create index if not exists ix_master_items_sha on scout.master_items(content_sha256) where content_sha256 is not null;

-- Simple ingest RPC (expects normalized array from isko-scraper)
create or replace function scout.ingest_master_items(p_items jsonb)
returns int language plpgsql as $$
declare r jsonb; n int:=0;
begin
  for r in select * from jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) loop
    insert into scout.master_items(
      source_id, source_url, brand_name, product_name, product_category,
      pack_size_value, pack_size_unit, list_price, currency, content_sha256
    )
    values (
      (r->>'source_id')::uuid,
      r->>'url',
      r->>'brand_name',
      r->>'product_name',
      r->>'product_category',
      nullif(r->>'pack_size_value','')::numeric,
      r->>'pack_size_unit',
      nullif(r->>'price','')::numeric,
      coalesce(r->>'currency','PHP'),
      r->>'content_sha256'
    )
    on conflict do nothing;
    n := n + 1;
  end loop;
  return n;
end$$;

-- View for recent catalog updates
create or replace view scout.v_master_items_recent as
select 
  item_id,
  brand_name,
  product_name,
  product_category,
  pack_size_value || ' ' || coalesce(pack_size_unit,'') as pack_size,
  list_price,
  currency,
  source_url,
  observed_at
from scout.master_items
where observed_at > now() - interval '24 hours'
order by observed_at desc;