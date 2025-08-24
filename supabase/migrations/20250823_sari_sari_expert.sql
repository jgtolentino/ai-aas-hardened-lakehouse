-- ===========================================================
-- Scout v5.2 — Sari-Sari Expert Bot Tables
-- ===========================================================

-- Inferred transactions from partial inputs
create table if not exists scout.inferred_transactions(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  
  -- Input data
  payment_amount decimal(10,2) not null,
  change_given decimal(10,2) not null,
  total_spent decimal(10,2) not null,
  time_of_day text not null,
  
  -- Inference results
  likely_products text[] not null,
  confidence_score decimal(3,2) not null check (confidence_score between 0 and 1),
  
  -- Context
  metadata jsonb default '{}'::jsonb,
  
  -- Analytics
  store_id uuid,
  region_code text,
  inference_model text default 'rules_v1'
);

-- Persona matching results
create table if not exists scout.persona_matches(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  
  -- Persona identification
  persona text not null,
  confidence decimal(3,2) not null check (confidence between 0 and 1),
  characteristics text[] not null,
  
  -- Transaction context
  transaction_context jsonb not null,
  
  -- Analytics
  store_id uuid,
  match_method text default 'behavioral'
);

-- Revenue optimization recommendations
create table if not exists scout.recommendations(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  
  -- Recommendation details
  title text not null,
  revenue_potential decimal(10,2) not null,
  roi text not null,
  timeline text not null,
  action_items text[] not null,
  
  -- Context
  context jsonb default '{}'::jsonb,
  
  -- Tracking
  status text default 'pending' check (status in ('pending', 'accepted', 'rejected', 'implemented')),
  implemented_at timestamptz,
  actual_revenue_gain decimal(10,2),
  
  -- Analytics
  store_id uuid,
  recommendation_type text
);

-- Deep research integration for SKU enrichment
create table if not exists scout.sku_research_queue(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  
  -- Product to research
  product_name text not null,
  brand_name text,
  category text,
  
  -- Research parameters
  research_type text not null default 'price_check',
  priority int default 5,
  sources text[] default array['shopee', 'lazada', 'puregold'],
  
  -- Status tracking
  status text default 'queued' check (status in ('queued', 'processing', 'completed', 'failed')),
  started_at timestamptz,
  completed_at timestamptz,
  
  -- Results
  scraped_data jsonb,
  error_message text,
  retry_count int default 0
);

-- Aggregated insights for dashboard
create materialized view scout.sari_sari_insights as
with daily_stats as (
  select
    date_trunc('day', created_at) as date,
    count(*) as inference_count,
    avg(confidence_score) as avg_confidence,
    count(distinct persona) as unique_personas
  from scout.inferred_transactions it
  join scout.persona_matches pm on it.created_at = pm.created_at
  where it.created_at >= current_date - interval '30 days'
  group by 1
),
recommendation_stats as (
  select
    date_trunc('day', created_at) as date,
    count(*) as recommendations_generated,
    sum(revenue_potential) as total_revenue_potential,
    count(case when status = 'implemented' then 1 end) as recommendations_implemented
  from scout.recommendations
  where created_at >= current_date - interval '30 days'
  group by 1
)
select
  ds.date,
  ds.inference_count,
  ds.avg_confidence,
  ds.unique_personas,
  rs.recommendations_generated,
  rs.total_revenue_potential,
  rs.recommendations_implemented,
  rs.recommendations_implemented::decimal / nullif(rs.recommendations_generated, 0) as implementation_rate
from daily_stats ds
left join recommendation_stats rs on ds.date = rs.date
order by ds.date desc;

-- Create indexes for performance
create index idx_inferred_transactions_created on scout.inferred_transactions(created_at desc);
create index idx_inferred_transactions_store on scout.inferred_transactions(store_id) where store_id is not null;
create index idx_persona_matches_persona on scout.persona_matches(persona);
create index idx_recommendations_status on scout.recommendations(status);
create index idx_sku_research_status on scout.sku_research_queue(status) where status in ('queued', 'processing');

-- RLS policies
alter table scout.inferred_transactions enable row level security;
alter table scout.persona_matches enable row level security;
alter table scout.recommendations enable row level security;
alter table scout.sku_research_queue enable row level security;

-- Read access for authenticated users
create policy inferred_transactions_read on scout.inferred_transactions
  for select using (true);

create policy persona_matches_read on scout.persona_matches
  for select using (true);

create policy recommendations_read on scout.recommendations
  for select using (true);

create policy sku_research_read on scout.sku_research_queue
  for select using (true);

-- Write access only for service role (Edge Functions)
create policy inferred_transactions_write on scout.inferred_transactions
  for insert using (auth.role() = 'service_role');

create policy persona_matches_write on scout.persona_matches
  for insert using (auth.role() = 'service_role');

create policy recommendations_write on scout.recommendations
  for all using (auth.role() = 'service_role');

create policy sku_research_write on scout.sku_research_queue
  for all using (auth.role() = 'service_role');

-- Function to process SKU research queue
create or replace function scout.process_sku_research_queue()
returns void
language plpgsql
security definer
as $$
declare
  v_job record;
begin
  -- Get next queued job
  select * into v_job
  from scout.sku_research_queue
  where status = 'queued'
  order by priority desc, created_at asc
  limit 1
  for update skip locked;
  
  if v_job.id is null then
    return;
  end if;
  
  -- Mark as processing
  update scout.sku_research_queue
  set status = 'processing',
      started_at = now()
  where id = v_job.id;
  
  -- Trigger Edge Function for actual scraping
  -- This would call the isko-worker or similar
  perform net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/isko-worker',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.supabase_service_key'),
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'job_id', v_job.id,
      'product_name', v_job.product_name,
      'sources', v_job.sources
    )
  );
end;
$$;

-- Grant permissions
grant select on scout.inferred_transactions to authenticated;
grant select on scout.persona_matches to authenticated;
grant select on scout.recommendations to authenticated;
grant select on scout.sku_research_queue to authenticated;
grant select on scout.sari_sari_insights to authenticated;

grant execute on function scout.process_sku_research_queue() to authenticated;