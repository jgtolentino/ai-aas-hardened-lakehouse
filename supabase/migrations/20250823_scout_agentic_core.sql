-- ===========================================================
-- Scout v5.2 — Agentic Core (Platinum + Feed + Isko hooks)
-- ===========================================================
set check_function_bodies = off;
create schema if not exists scout;
create schema if not exists deep_research;

-- Monitors catalog
create table if not exists scout.platinum_monitors(
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  title text not null,
  definition_sql text not null,
  is_enabled boolean not null default true,
  created_at timestamptz not null default now()
);

-- Monitor events
create table if not exists scout.platinum_monitor_events(
  id uuid primary key default gen_random_uuid(),
  monitor_id uuid not null references scout.platinum_monitors(id) on delete cascade,
  event_time timestamptz not null default now(),
  severity text not null check (severity in ('info','warn','crit')),
  payload jsonb not null default '{}'::jsonb
);
create index if not exists idx_plat_events_time on scout.platinum_monitor_events(event_time desc);

-- Agent action ledger (append-only)
create table if not exists scout.platinum_agent_action_ledger(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  actor text not null default 'agent/scout',
  action_type text not null,
  payload jsonb not null,
  approval_status text not null default 'pending' check (approval_status in ('pending','approved','rejected')),
  approved_by text,
  approved_at timestamptz
);

-- Unified Agent Feed
create table if not exists scout.agent_feed(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  event_type text not null, -- monitor|contract|isko|system
  severity text not null default 'info' check (severity in ('info','warn','crit')),
  summary text not null,
  details jsonb not null default '{}'::jsonb,
  status text not null default 'new' check (status in ('new','read','archived'))
);
create index if not exists idx_agent_feed_time on scout.agent_feed(created_at desc);

-- Minimal Gold-only exposure rule: expose only scout.gold_* (your gold views)
revoke all on schema scout from public;
-- You can selectively grant read to specific gold tables/views in separate migrations.

-- Isko: jobs + summary (hook points)
create table if not exists deep_research.sku_jobs(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  brand_id uuid,
  product_id uuid,
  url text,
  status text not null default 'queued' check (status in ('queued','running','success','failed')),
  attempts int not null default 0,
  last_error text
);
create index if not exists idx_sku_jobs_status on deep_research.sku_jobs(status);

create table if not exists deep_research.sku_summary(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  brand_id uuid,
  product_id uuid,
  brand_name text,
  product_name text,
  pack_size text,
  price numeric,
  currency text default 'PHP',
  source_url text,
  snapshot jsonb not null default '{}'::jsonb
);

-- Simple RPCs for feed & monitors
create or replace function scout.rpc_feed_list(p_limit int default 50)
returns setof scout.agent_feed
language sql
security definer
as $$ select * from scout.agent_feed order by created_at desc limit greatest(1,least(p_limit,200)); $$;

grant execute on function scout.rpc_feed_list(int) to authenticated;

-- RLS examples (tighten as needed)
alter table scout.agent_feed enable row level security;
create policy agent_feed_read on scout.agent_feed for select using (true);

alter table scout.platinum_monitors enable row level security;
create policy monitors_read on scout.platinum_monitors for select using (true);

-- Seed monitors (definitions are SQL returning rows => events)
insert into scout.platinum_monitors(key,title,definition_sql) values
('demand_spike','Demand Spike (z>3)',
 $$select now() as event_time, 'crit' as severity,
       jsonb_build_object('brand_id', brand_id,'z', z,'qty',qty,'avg',avg_qty,'std',stddev_qty) as payload
   from (
     with w as (
       select brand_id, qty,
              avg(qty) over (partition by brand_id rows between 6 preceding and current row) as avg_qty,
              stddev_pop(qty) over (partition by brand_id rows between 6 preceding and current row) as stddev_qty,
              date
       from scout.gold_sales_daily
       where date >= current_date - interval '60 days'
     )
     select brand_id, qty,
       case when stddev_qty > 0 then (qty-avg_qty)/nullif(stddev_qty,0) else 0 end as z,
       avg_qty, stddev_qty
     from w
   ) s
   where z >= 3.0 $$)
on conflict (key) do nothing;