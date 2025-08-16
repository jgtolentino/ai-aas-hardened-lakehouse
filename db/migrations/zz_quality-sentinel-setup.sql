-- Scout Edge: Quality Sentinel Database Setup
-- Incident tracking and RPC functions for the edge function

create schema if not exists suqi;

-- Incident log table
create table if not exists suqi.incident_log (
  id bigserial primary key,
  incident_key text not null unique,
  severity text not null check (severity in ('low','med','high','crit')),
  summary text not null,
  details jsonb not null,
  clickup_task_id text null,
  github_issue_number int null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz null
);

-- RPC function to get quality summary
create or replace function public.suqi_get_quality_summary()
returns json language sql security definer as $$
  select to_json((
    select q from (
      select
        coalesce((select brand_missing_pct from suqi.data_quality_summary), 0) as brand_missing_pct,
        coalesce((select price_missing_pct from suqi.data_quality_summary), 0) as price_missing_pct,
        coalesce((select demographics_missing_pct from suqi.data_quality_summary), 0) as demographics_missing_pct,
        coalesce((select low_confidence_pct from suqi.data_quality_summary), 0) as low_confidence_pct
    ) q
  ));
$$;

-- RPC function to get today's confusion matrix
create or replace function public.suqi_get_confusion_today()
returns table(run_date date, actual_brand text, predicted_brand text, n bigint)
language sql security definer as $$
  select run_date, actual_brand, predicted_brand, n
  from suqi.brand_confusion_matrix
  where run_date = date_trunc('day', now())::date;
$$;

-- RPC function to get macro F1
create or replace function public.get_macro_f1()
returns numeric language sql security definer as $$
  select coalesce(suqi.get_macro_f1(), 0);
$$;

-- Grant permissions for edge function
grant usage on schema suqi to anon, authenticated;
grant select on suqi.incident_log to anon, authenticated;
grant insert, update on suqi.incident_log to anon, authenticated;

-- Create public views for PostgREST access
create or replace view public.suqi_incident_log as 
select * from suqi.incident_log;

create or replace view public.suqi_data_quality_summary as 
select * from suqi.data_quality_summary;

-- Grant view access
grant select on public.suqi_incident_log to anon, authenticated;
grant select on public.suqi_data_quality_summary to anon, authenticated;