#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/ai-aas-hardened-lakehouse"
cd "$ROOT"

mkdir -p supabase/templates supabase/seed supabase/tests scripts/db

# 001 — Extensions (idempotent)
cat > supabase/templates/001_extensions.sql <<'SQL'
-- Enable common extensions (safe to re-run)
create extension if not exists pgcrypto with schema public;
create extension if not exists pg_trgm with schema public;
create extension if not exists uuid-ossp with schema public;
SQL

# 010 — Schema & tables (idempotent)
cat > supabase/templates/010_schema_scout.sql <<'SQL'
create schema if not exists scout;

create table if not exists scout.agents (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null,
  name       text not null,
  role       text,
  meta       jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists scout.session_history (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null,
  agent_id    uuid references scout.agents(id) on delete set null,
  user_id     uuid,
  started_at  timestamptz not null default now(),
  ended_at    timestamptz,
  transcript  jsonb not null default '[]'::jsonb
);

create table if not exists scout.events (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null,
  session_id  uuid references scout.session_history(id) on delete cascade,
  occurred_at timestamptz not null default now(),
  kind        text not null,
  payload     jsonb not null default '{}'::jsonb
);

create table if not exists scout.knowledge_base (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null,
  key         text not null,
  value       jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now(),
  unique (tenant_id, key)
);

create index if not exists idx_agents_tenant       on scout.agents(tenant_id);
create index if not exists idx_sessions_tenant     on scout.session_history(tenant_id);
create index if not exists idx_events_session      on scout.events(session_id);
create index if not exists idx_kb_tenant_key       on scout.knowledge_base(tenant_id, key);
SQL

# 020 — RLS (tenant isolation with auth.uid())
cat > supabase/templates/020_rls_scout.sql <<'SQL'
alter table scout.agents           enable row level security;
alter table scout.session_history  enable row level security;
alter table scout.events           enable row level security;
alter table scout.knowledge_base   enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='scout' and tablename='agents' and policyname='tenant_rw') then
    create policy tenant_rw on scout.agents
      for all using (tenant_id = auth.uid()) with check (tenant_id = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where schemaname='scout' and tablename='session_history' and policyname='tenant_rw') then
    create policy tenant_rw on scout.session_history
      for all using (tenant_id = auth.uid()) with check (tenant_id = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where schemaname='scout' and tablename='events' and policyname='tenant_rw') then
    create policy tenant_rw on scout.events
      for all using (tenant_id = auth.uid()) with check (tenant_id = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where schemaname='scout' and tablename='knowledge_base' and policyname='tenant_rw') then
    create policy tenant_rw on scout.knowledge_base
      for all using (tenant_id = auth.uid()) with check (tenant_id = auth.uid());
  end if;
end $$;
SQL

# 030 — RPC (example) + grants
cat > supabase/templates/030_function_upsert_event.sql <<'SQL'
create or replace function scout.upsert_event(
  _tenant  uuid,
  _session uuid,
  _kind    text,
  _payload jsonb default '{}'::jsonb
) returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare _id uuid;
begin
  insert into scout.events(tenant_id, session_id, kind, payload)
  values (_tenant, _session, _kind, coalesce(_payload, '{}'::jsonb))
  returning id into _id;
  return _id;
end $$;

-- Least-privilege grants
revoke all on function scout.upsert_event(uuid,uuid,text,jsonb) from public, anon;
grant execute on function scout.upsert_event(uuid,uuid,text,jsonb) to authenticated;
SQL

# 040 — Trigger to touch updated_at
cat > supabase/templates/040_trigger_touch.sql <<'SQL'
create or replace function scout.tg_touch_updated_at()
returns trigger
language plpgsql
as $$ begin
  new.updated_at := now();
  return new;
end $$;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'tg_touch_agents_updated_at') then
    create trigger tg_touch_agents_updated_at
    before update on scout.agents
    for each row execute procedure scout.tg_touch_updated_at();
  end if;
  
  if not exists (select 1 from pg_trigger where tgname = 'tg_touch_kb_updated_at') then
    create trigger tg_touch_kb_updated_at
    before update on scout.knowledge_base
    for each row execute procedure scout.tg_touch_updated_at();
  end if;
end $$;
SQL

# 050 — View for reporting
cat > supabase/templates/050_view_session_event_counts.sql <<'SQL'
create or replace view scout.v_session_event_counts as
select sh.id as session_id,
       sh.tenant_id,
       count(e.*) as event_count,
       min(e.occurred_at) as first_event_at,
       max(e.occurred_at) as last_event_at
from scout.session_history sh
left join scout.events e on e.session_id = sh.id
group by sh.id, sh.tenant_id;

grant select on scout.v_session_event_counts to authenticated;
revoke all on scout.v_session_event_counts from anon;
SQL

# DEV seed (safe upserts; run locally only)
cat > supabase/seed/000_seed_dev.sql <<'SQL'
-- DEV-ONLY SEED. Do NOT run in production.
insert into scout.agents (id, tenant_id, name, role)
values
  ('00000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'backend-architect', 'system')
on conflict (id) do nothing;

insert into scout.session_history (id, tenant_id, agent_id, user_id)
values
  ('00000000-0000-0000-0000-0000000000aa','11111111-1111-1111-1111-111111111111',
   '00000000-0000-0000-0000-000000000001', null)
on conflict (id) do nothing;
SQL

echo "📁 Templates created under supabase/templates (not auto-applied)."
echo "Use Supabase Desktop SQL editor or CLI to run in order:"
ls -1 supabase/templates | sed 's/^/  - /'
