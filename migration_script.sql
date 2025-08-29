-- SCHEMAS (idempotent)
create schema if not exists security;
create schema if not exists ai;

-- EXTENSIONS
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";
create extension if not exists "vector";

-- ADMIN MAPPING: which regions a user can read
create table if not exists security.user_region (
  id bigserial primary key,
  user_id uuid not null,
  region_id text not null,
  created_at timestamptz not null default now(),
  unique (user_id, region_id)
);
alter table security.user_region enable row level security;

-- RLS: users can only see their own mapping rows
do $
begin
  if not exists (select 1 from pg_policies where schemaname='security' and tablename='user_region' and policyname='own_map_select') then
    create policy "own_map_select"
    on security.user_region for select
    using (auth.uid() = user_id);
  end if;
end$;

-- No write policies -> only service role can modify (bypasses RLS).

-- ==== FACT RLS (region-scoped read) ===================================
-- We don't assume table definitions; we guard on existence & column presence.
-- Applies to facts.sales_daily if it exists and has region_id
do $
declare
  t_exists boolean;
  col_exists boolean;
  pol_exists boolean;
begin
  select exists (select 1 from information_schema.tables
                 where table_schema='facts' and table_name='sales_daily') into t_exists;
  if t_exists then
    select exists (select 1 from information_schema.columns
                   where table_schema='facts' and table_name='sales_daily' and column_name='region_id') into col_exists;
    if col_exists then
      execute 'alter table facts.sales_daily enable row level security';
      select exists (select 1 from pg_policies
                     where schemaname='facts' and tablename='sales_daily' and policyname='analyst_region_scope') into pol_exists;
      if not pol_exists then
        execute $p$
          create policy "analyst_region_scope"
          on facts.sales_daily
          for select
          using (exists (
            select 1 from security.user_region ur
            where ur.user_id = auth.uid()
              and ur.region_id = facts.sales_daily.region_id
          ));
        $p$;
      end if;
    end if;
  end if;
end$;

-- (Optional) replicate same pattern for facts.transactions if present
do $
declare
  t_exists boolean;
  col_exists boolean;
  pol_exists boolean;
begin
  select exists (select 1 from information_schema.tables
                 where table_schema='facts' and table_name='transactions') into t_exists;
  if t_exists then
    select exists (select 1 from information_schema.columns
                   where table_schema='facts' and table_name='transactions' and column_name='region_id') into col_exists;
    if col_exists then
      execute 'alter table facts.transactions enable row level security';
      select exists (select 1 from pg_policies
                     where schemaname='facts' and tablename='transactions' and policyname='analyst_region_scope') into pol_exists;
      if not pol_exists then
        execute $p$
          create policy "analyst_region_scope"
          on facts.transactions
          for select
          using (exists (
            select 1 from security.user_region ur
            where ur.user_id = auth.uid()
              and ur.region_id = facts.transactions.region_id
          ));
        $p$;
      end if;
    end if;
  end if;
end$;

-- ==== AI / pgvector ====================================================
create table if not exists ai.insight_chunks(
  id bigserial primary key,
  module text not null,                 -- 'overview'|'mix'|'competitive'...
  content text not null,
  embedding vector(768) not null,
  created_at timestamptz not null default now()
);

-- Indexes (choose one; IVFFLAT needs ANALYZE after populate)
do $
begin
  if not exists (select 1 from pg_indexes where schemaname='ai' and indexname='insight_chunks_embedding_idx') then
    create index insight_chunks_embedding_idx on ai.insight_chunks using ivfflat (embedding vector_cosine_ops) with (lists = 100);
  end if;
  if not exists (select 1 from pg_indexes where schemaname='ai' and indexname='insight_chunks_module_idx') then
    create index insight_chunks_module_idx on ai.insight_chunks (module);
  end if;
end$;

-- RLS for ai.insight_chunks (read for all authenticated; writes by service role only)
alter table ai.insight_chunks enable row level security;
do $
begin
  if not exists (select 1 from pg_policies where schemaname='ai' and tablename='insight_chunks' and policyname='read_all_auth') then
    create policy read_all_auth on ai.insight_chunks for select using (auth.role() = 'authenticated');
  end if;
end$;

-- OPTIONAL: a similarity search helper (safe SELECT)
create or replace function ai.search_insights(q_emb vector(768), m text, k int default 8)
returns table (id bigint, module text, content text, distance float)
language sql stable as $
  select ic.id, ic.module, ic.content, 1 - (ic.embedding <#> q_emb) as distance
  from ai.insight_chunks ic
  where (m is null or ic.module = m)
  order by ic.embedding <#> q_emb
  limit k;
$;
