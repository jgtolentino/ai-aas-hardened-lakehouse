-- Scout Edge: KPI Queries from Confusion Matrix
-- Per-brand recall, precision, F1 scores

-- Per-brand metrics (closed-set)
create or replace view suqi.v_brand_kpis as
with m as (
  select run_date, actual_brand, predicted_brand, n
  from suqi.brand_confusion_matrix
  where run_date = date_trunc('day', now())::date
),
tp as (select actual_brand, sum(n) n from m where actual_brand=predicted_brand group by 1),
fn as (select actual_brand, sum(n) n from m where actual_brand<>predicted_brand group by 1),
fp as (select predicted_brand, sum(n) n from m where actual_brand<>predicted_brand group by 1)
select
  coalesce(t.actual_brand,f1.predicted_brand) as brand,
  coalesce(t.n,0)::bigint as true_positives,
  coalesce(f.n,0)::bigint as false_negatives,
  coalesce(p.n,0)::bigint as false_positives,
  round( (coalesce(t.n,0)::numeric) / nullif(coalesce(t.n,0)+coalesce(f.n,0),0), 4) as recall,
  round( (coalesce(t.n,0)::numeric) / nullif(coalesce(t.n,0)+coalesce(p.n,0),0), 4) as precision,
  round( case
    when (coalesce(t.n,0)=0 or (coalesce(f.n,0)+coalesce(p.n,0)) is null) then 0
    else 2*((coalesce(t.n,0)::numeric)/nullif((coalesce(t.n,0)+coalesce(p.n,0)),0))
            * ((coalesce(t.n,0)::numeric)/nullif((coalesce(t.n,0)+coalesce(f.n,0)),0))
          / nullif(
              ( (coalesce(t.n,0)::numeric)/nullif((coalesce(t.n,0)+coalesce(p.n,0)),0)
              + (coalesce(t.n,0)::numeric)/nullif((coalesce(t.n,0)+coalesce(f.n,0)),0) ),0)
  end, 4) as f1_score
from tp t
full join fn f1 on f1.actual_brand=t.actual_brand
left join fn f on f.actual_brand=t.actual_brand
left join fp p on p.predicted_brand=coalesce(t.actual_brand,f1.actual_brand)
order by f1_score desc nulls last, brand;

-- Open-set detection metrics (UNK handling)
create or replace view suqi.v_openset_metrics as
with m as (
  select run_date, actual_brand, predicted_brand, n
  from suqi.brand_confusion_matrix
  where run_date = date_trunc('day', now())::date
)
select
  sum(case when actual_brand='UNK' and predicted_brand='UNK' then n else 0 end) as true_unknown,
  sum(case when actual_brand='UNK' and predicted_brand<>'UNK' then n else 0 end) as false_brand_on_unknown,
  sum(case when actual_brand<>'UNK' and predicted_brand='UNK' then n else 0 end) as unknown_predicted_on_known,
  sum(case when actual_brand='UNK' then n else 0 end) as total_unknown_actual,
  sum(case when predicted_brand='UNK' then n else 0 end) as total_unknown_predicted
from m;

-- Store-level accuracy trends
create or replace view suqi.v_store_accuracy as
with m as (
  select t.store_id,
         date_trunc('day', t.ts_utc) as date,
         scout.norm_brand(i.brand_name) as predicted,
         scout.norm_brand(coalesce(
           (select actual_brand from suqi.ground_truth_brands g 
            where g.transaction_id = i.transaction_id 
            and g.item_id = i.id),
           i.brand_name
         )) as actual
  from public.scout_gold_transaction_items i
  join public.scout_gold_transactions t using (transaction_id)
  where t.ts_utc >= now() - interval '7 days'
)
select 
  store_id, 
  date,
  count(*) as total_items,
  sum((actual=predicted)::int) as correct,
  sum((actual<>predicted)::int) as incorrect,
  round(100.0*avg((actual=predicted)::int),2) as accuracy_pct
from m
group by store_id, date
order by date desc, accuracy_pct asc;

-- Macro F1 score for alerting
create or replace function suqi.get_macro_f1()
returns numeric as $$
  select round(avg(f1_score), 4)
  from suqi.v_brand_kpis
  where brand <> 'UNK'
$$ language sql;

-- Top brand confusions
create or replace view suqi.v_top_confusions as
select 
  actual_brand,
  predicted_brand,
  n as confusion_count
from suqi.brand_confusion_matrix
where run_date = date_trunc('day', now())::date
  and actual_brand <> predicted_brand
  and actual_brand not in ('UNK', 'NULL')
  and predicted_brand not in ('UNK', 'NULL')
order by n desc
limit 20;