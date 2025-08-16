\set ON_ERROR_STOP on
create table if not exists deep_research.enrichment_log (
  id bigserial primary key,
  target_kind text check (target_kind in ('brand','product','sku')) not null,
  target_id bigint not null,
  source text check (source in ('openfoodfacts','wikidata','upcitemdb','brand-model')) not null,
  status text check (status in ('ok','miss','error')) not null,
  message text,
  payload jsonb,
  created_at timestamptz default now()
);