-- supabase/migrations/20250812_silver_dq_health.sql
set search_path = scout, public;

-- 1) Daily DQ summary (transactions + items)
create or replace view scout.silver_dq_daily_summary as
with tx as (
  select
    date,
    store_id,
    sum(dq_missing_ts)::int       as tx_missing_ts,
    sum(dq_missing_tz)::int       as tx_missing_tz,
    sum(dq_missing_store)::int    as tx_missing_store,
    count(*)::int                 as tx_rows
  from scout.silver_transactions_clean
  group by 1,2
),
it as (
  select
    t.date,
    s.store_id,
    sum(dq_missing_product)::int  as it_missing_product,
    sum(dq_bad_qty)::int          as it_bad_qty,
    sum(dq_unknown_uom)::int      as it_unknown_uom,
    sum(dq_bad_price)::int        as it_bad_price,
    sum(dq_bad_net)::int          as it_bad_net,
    sum(dq_bad_conf)::int         as it_bad_conf,
    count(*)::int                 as it_rows
  from scout.silver_transaction_items_clean i
  join scout.silver_transactions_clean t using (txn_id)
  join scout.stores s on s.id = t.store_id
  group by 1,2
),
merged as (
  select
    coalesce(tx.date, it.date) as date,
    coalesce(tx.store_id, it.store_id) as store_id,
    coalesce(tx.tx_rows,0) as tx_rows,
    coalesce(it.it_rows,0) as it_rows,
    coalesce(tx.tx_missing_ts,0)      as tx_missing_ts,
    coalesce(tx.tx_missing_tz,0)      as tx_missing_tz,
    coalesce(tx.tx_missing_store,0)   as tx_missing_store,
    coalesce(it.it_missing_product,0) as it_missing_product,
    coalesce(it.it_bad_qty,0)         as it_bad_qty,
    coalesce(it.it_unknown_uom,0)     as it_unknown_uom,
    coalesce(it.it_bad_price,0)       as it_bad_price,
    coalesce(it.it_bad_net,0)         as it_bad_net,
    coalesce(it.it_bad_conf,0)        as it_bad_conf
  from tx full join it on tx.date=it.date and tx.store_id=it.store_id
),
scored as (
  select
    m.*,
    -- weighted issue count (tune weights if needed)
    (m.tx_missing_ts*3 + m.tx_missing_tz*2 + m.tx_missing_store*3
     + m.it_missing_product*3 + m.it_bad_qty*2 + m.it_unknown_uom*1
     + m.it_bad_price*2 + m.it_bad_net*2 + m.it_bad_conf*1) as issue_weight,
    greatest(m.tx_rows + m.it_rows,1) as total_rows
  from merged m
)
select
  s.date,
  s.store_id,
  st.region_id, st.city_id, st.barangay_id,
  s.tx_rows, s.it_rows,
  s.tx_missing_ts, s.tx_missing_tz, s.tx_missing_store,
  s.it_missing_product, s.it_bad_qty, s.it_unknown_uom, s.it_bad_price, s.it_bad_net, s.it_bad_conf,
  -- Health index: 100 - normalized issue score
  greatest(0, least(100, round(100 - 100.0 * s.issue_weight / s.total_rows, 2))) as dq_health_index,
  case
    when 100 - 100.0 * s.issue_weight / s.total_rows >= 90 then 'good'
    when 100 - 100.0 * s.issue_weight / s.total_rows >= 75 then 'warn'
    else 'bad'
  end as dq_health_bucket
from scored s
left join scout.stores st on st.id = s.store_id;

-- 2) Top issues (last 7 days) for quick triage
create or replace view scout.silver_dq_top_issues as
select
  issue, store_id,
  sum(cnt) as total_hits,
  min(date) as first_seen,
  max(date) as last_seen
from (
  select date, store_id, 'tx_missing_ts'  as issue, tx_missing_ts  as cnt from scout.silver_dq_daily_summary
  union all select date, store_id, 'tx_missing_tz' , tx_missing_tz  from scout.silver_dq_daily_summary
  union all select date, store_id, 'tx_missing_store', tx_missing_store from scout.silver_dq_daily_summary
  union all select date, store_id, 'it_missing_product', it_missing_product from scout.silver_dq_daily_summary
  union all select date, store_id, 'it_bad_qty', it_bad_qty from scout.silver_dq_daily_summary
  union all select date, store_id, 'it_unknown_uom', it_unknown_uom from scout.silver_dq_daily_summary
  union all select date, store_id, 'it_bad_price', it_bad_price from scout.silver_dq_daily_summary
  union all select date, store_id, 'it_bad_net', it_bad_net from scout.silver_dq_daily_summary
  union all select date, store_id, 'it_bad_conf', it_bad_conf from scout.silver_dq_daily_summary
) x
where date >= current_date - interval '7 days'
group by 1,2
order by total_hits desc nulls last
limit 100;

-- 3) Public API aliases
create or replace view public.silver_dq_daily_summary_api as
  select * from scout.silver_dq_daily_summary;
create or replace view public.silver_dq_top_issues_api as
  select * from scout.silver_dq_top_issues;

revoke all on public.silver_dq_daily_summary_api, public.silver_dq_top_issues_api from public, anon;
grant  select on public.silver_dq_daily_summary_api, public.silver_dq_top_issues_api to authenticated;

-- 4) RPC for dashboards (filterable)
create or replace function scout.get_dq_health(
  p_date_from date,
  p_date_to   date,
  p_store_id  integer default null
)
returns table(
  date date, store_id int, region_id int, city_id int, barangay_id int,
  dq_health_index numeric, dq_health_bucket text,
  tx_rows int, it_rows int,
  tx_missing_ts int, tx_missing_tz int, tx_missing_store int,
  it_missing_product int, it_bad_qty int, it_unknown_uom int, it_bad_price int, it_bad_net int, it_bad_conf int
)
language sql
security invoker
set search_path = scout, public
as $$
  select
    d.date, d.store_id, d.region_id, d.city_id, d.barangay_id,
    d.dq_health_index, d.dq_health_bucket,
    d.tx_rows, d.it_rows,
    d.tx_missing_ts, d.tx_missing_tz, d.tx_missing_store,
    d.it_missing_product, d.it_bad_qty, d.it_unknown_uom, d.it_bad_price, d.it_bad_net, d.it_bad_conf
  from scout.silver_dq_daily_summary d
  where d.date between p_date_from and p_date_to
    and (p_store_id is null or d.store_id = p_store_id)
  order by d.date desc, d.store_id;
$$;

revoke execute on function scout.get_dq_health(date,date,integer) from public, anon;
grant  execute on function scout.get_dq_health(date,date,integer) to authenticated;