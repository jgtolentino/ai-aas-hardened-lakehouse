-- Scout Edge: Brand Confusion Matrix Infrastructure
-- Tracks prediction accuracy and drives operational improvements

-- Create schema if not exists
create schema if not exists suqi;

-- Ground truth table for labeled data
create table if not exists suqi.ground_truth_brands (
  id bigserial primary key,
  transaction_id text not null,
  item_id bigint not null,
  actual_brand text not null,
  confidence numeric default 1.0,
  source text default 'manual', -- manual, receipt, audit
  created_at timestamptz default now(),
  unique(transaction_id, item_id)
);

-- Predictions table (mirrors production data)
create table if not exists suqi.brand_predictions (
  id bigserial primary key,
  transaction_id text not null,
  item_id bigint not null,
  predicted_brand text,
  confidence numeric,
  detection_method text,
  created_at timestamptz default now(),
  unique(transaction_id, item_id)
);

-- Confusion matrix results
create table if not exists suqi.brand_confusion_matrix (
  run_date date not null,
  actual_brand text not null,
  predicted_brand text not null,
  n bigint not null default 0,
  primary key (run_date, actual_brand, predicted_brand)
);

-- Function to compute confusion matrix
create or replace function suqi.compute_brand_confusion(window_interval interval default '24 hours')
returns void as $$
declare
  run_dt date := date_trunc('day', now())::date;
begin
  -- Clear today's matrix
  delete from suqi.brand_confusion_matrix where run_date = run_dt;
  
  -- Insert confusion matrix
  insert into suqi.brand_confusion_matrix (run_date, actual_brand, predicted_brand, n)
  select 
    run_dt,
    coalesce(g.actual_brand, 'NULL') as actual_brand,
    coalesce(p.predicted_brand, 'NULL') as predicted_brand,
    count(*) as n
  from suqi.ground_truth_brands g
  join suqi.brand_predictions p 
    on g.transaction_id = p.transaction_id 
    and g.item_id = p.item_id
  where p.created_at >= now() - window_interval
  group by g.actual_brand, p.predicted_brand;
  
  -- Add UNK handling for open-set detection
  insert into suqi.brand_confusion_matrix (run_date, actual_brand, predicted_brand, n)
  select 
    run_dt,
    'UNK' as actual_brand,
    coalesce(p.predicted_brand, 'NULL') as predicted_brand,
    count(*) as n
  from suqi.brand_predictions p
  left join suqi.ground_truth_brands g 
    on g.transaction_id = p.transaction_id 
    and g.item_id = p.item_id
  where g.id is null
    and p.created_at >= now() - window_interval
  group by p.predicted_brand
  on conflict (run_date, actual_brand, predicted_brand) 
  do update set n = excluded.n;
end;
$$ language plpgsql;

-- Sync predictions from production data
create or replace function suqi.sync_brand_predictions()
returns void as $$
begin
  insert into suqi.brand_predictions (transaction_id, item_id, predicted_brand, confidence, detection_method)
  select 
    i.transaction_id,
    i.id as item_id,
    scout.norm_brand(i.brand_name) as predicted_brand,
    i.confidence,
    i.detection_method
  from public.scout_gold_transaction_items i
  left join suqi.brand_predictions p 
    on i.transaction_id = p.transaction_id 
    and i.id = p.item_id
  where p.id is null
    and i.transaction_id in (
      select transaction_id 
      from public.scout_gold_transactions 
      where ts_utc >= now() - interval '48 hours'
    )
  on conflict (transaction_id, item_id) do nothing;
end;
$$ language plpgsql;

-- Create indexes
create index if not exists idx_gt_tx_item on suqi.ground_truth_brands(transaction_id, item_id);
create index if not exists idx_pred_tx_item on suqi.brand_predictions(transaction_id, item_id);
create index if not exists idx_pred_created on suqi.brand_predictions(created_at);
create index if not exists idx_confusion_date on suqi.brand_confusion_matrix(run_date);