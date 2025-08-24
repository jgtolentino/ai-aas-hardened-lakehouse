-- ===========================================================
-- Scout v5.2 — Natural Language to SQL Feature
-- ===========================================================

-- Table to store saved NL queries
create table if not exists scout.saved_nl_queries(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id text not null default 'system',
  natural_language text not null,
  generated_sql text not null,
  explanation text,
  visualization text,
  is_favorite boolean default false,
  execution_count int default 0,
  last_executed_at timestamptz,
  tags text[] default '{}',
  metadata jsonb default '{}'::jsonb
);

-- Index for fast lookups
create index if not exists idx_saved_queries_user on scout.saved_nl_queries(user_id);
create index if not exists idx_saved_queries_favorite on scout.saved_nl_queries(is_favorite) where is_favorite = true;
create index if not exists idx_saved_queries_created on scout.saved_nl_queries(created_at desc);

-- Query execution history
create table if not exists scout.nl_query_history(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  query_id uuid references scout.saved_nl_queries(id) on delete set null,
  user_id text not null default 'system',
  natural_language text not null,
  generated_sql text not null,
  execution_time_ms int,
  row_count int,
  error_message text,
  success boolean not null default true
);

create index if not exists idx_query_history_user on scout.nl_query_history(user_id);
create index if not exists idx_query_history_created on scout.nl_query_history(created_at desc);

-- Common query templates for suggestions
create table if not exists scout.query_templates(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  category text not null,
  title text not null,
  natural_language text not null,
  sql_template text not null,
  parameters jsonb default '[]'::jsonb,
  visualization text,
  usage_count int default 0,
  is_active boolean default true
);

-- Seed some common query templates
insert into scout.query_templates(category, title, natural_language, sql_template, visualization) values
('revenue', 'Top Brands by Revenue', 
 'Show me top 10 brands by revenue last month',
 'select b.brand_name, sum(g.revenue) as total_revenue
  from scout.gold_sales_daily g
  join masterdata.brands b on b.id = g.brand_id
  where g.date >= current_date - interval ''30 days''
  group by b.brand_name
  order by total_revenue desc
  limit 10',
 'bar'),

('growth', 'Product Growth Rate',
 'Which products had the highest growth rate?',
 'with periods as (
    select 
      product_id,
      sum(case when date >= current_date - interval ''30 days'' then revenue else 0 end) as current_period,
      sum(case when date < current_date - interval ''30 days'' and date >= current_date - interval ''60 days'' then revenue else 0 end) as previous_period
    from scout.gold_sales_daily
    where date >= current_date - interval ''60 days''
    group by product_id
  )
  select 
    p.product_name,
    periods.current_period,
    periods.previous_period,
    case 
      when periods.previous_period > 0 then 
        round(((periods.current_period - periods.previous_period) / periods.previous_period) * 100, 2)
      else 100
    end as growth_rate_pct
  from periods
  join masterdata.products p on p.id = periods.product_id
  where periods.current_period > 0 or periods.previous_period > 0
  order by growth_rate_pct desc
  limit 20',
 'table'),

('patterns', 'Weekday vs Weekend Sales',
 'Compare weekday vs weekend sales patterns',
 'select 
    case 
      when extract(isodow from date) in (6,7) then ''Weekend''
      else ''Weekday''
    end as day_type,
    count(distinct date) as days,
    sum(revenue) as total_revenue,
    avg(revenue) as avg_daily_revenue,
    sum(qty) as total_quantity
  from scout.gold_sales_daily
  where date >= current_date - interval ''30 days''
  group by day_type
  order by day_type',
 'bar'),

('basket', 'Average Basket Size by Region',
 'What''s the average basket size by region?',
 'select 
    r.region_name,
    count(distinct t.transaction_id) as transaction_count,
    avg(t.basket_size) as avg_basket_size,
    avg(t.total_amount) as avg_transaction_value
  from scout.gold_transactions t
  join geo.regions r on r.region_code = t.region_code
  where t.date >= current_date - interval ''30 days''
  group by r.region_name
  order by avg_basket_size desc',
 'bar'),

('share', 'Brand Market Share Trend',
 'Show brand market share trend over time',
 'select 
    date,
    brand_id,
    share
  from scout.gold_brand_share_daily
  where date >= current_date - interval ''90 days''
    and brand_id in (
      select brand_id 
      from scout.gold_brand_share_daily 
      where date = current_date - 1
      order by share desc 
      limit 5
    )
  order by date, share desc',
 'line')
on conflict do nothing;

-- RLS policies
alter table scout.saved_nl_queries enable row level security;
create policy saved_queries_user_access on scout.saved_nl_queries
  for all using (user_id = auth.uid()::text or user_id = 'system');

alter table scout.nl_query_history enable row level security;
create policy query_history_user_access on scout.nl_query_history
  for all using (user_id = auth.uid()::text or user_id = 'system');

alter table scout.query_templates enable row level security;
create policy templates_read_all on scout.query_templates
  for select using (is_active = true);

-- Grant permissions
grant select on scout.saved_nl_queries to authenticated;
grant insert on scout.saved_nl_queries to authenticated;
grant update on scout.saved_nl_queries to authenticated;

grant select on scout.nl_query_history to authenticated;
grant insert on scout.nl_query_history to authenticated;

grant select on scout.query_templates to authenticated;

-- Helper function to log query execution
create or replace function scout.log_nl_query_execution(
  p_natural_language text,
  p_sql text,
  p_execution_time_ms int,
  p_row_count int,
  p_error_message text default null,
  p_query_id uuid default null
)
returns uuid
language plpgsql
security definer
as $$
declare
  v_history_id uuid;
begin
  insert into scout.nl_query_history(
    query_id,
    user_id,
    natural_language,
    generated_sql,
    execution_time_ms,
    row_count,
    error_message,
    success
  ) values (
    p_query_id,
    coalesce(auth.uid()::text, 'system'),
    p_natural_language,
    p_sql,
    p_execution_time_ms,
    p_row_count,
    p_error_message,
    p_error_message is null
  ) returning id into v_history_id;
  
  -- Update execution count if it's a saved query
  if p_query_id is not null then
    update scout.saved_nl_queries
    set execution_count = execution_count + 1,
        last_executed_at = now()
    where id = p_query_id;
  end if;
  
  return v_history_id;
end;
$$;

grant execute on function scout.log_nl_query_execution(text, text, int, int, text, uuid) to authenticated;