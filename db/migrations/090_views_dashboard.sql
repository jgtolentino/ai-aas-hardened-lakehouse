\set ON_ERROR_STOP on
create or replace view scout.v_snowball_dashboard as
with jobs as (
  select coalesce(source,'<none>') as source_code,
         count(*) filter (where status='queued')  as queued,
         count(*) filter (where status='running') as running,
         count(*) filter (where status='done')    as done,
         count(*) filter (where status='error')   as error,
         count(*) filter (where status='blocked') as blocked
  from deep_research.jobs
  group by 1
),
cat as (
  select ps.source_code,
         count(distinct b.brand_id)  as brands,
         count(distinct p.product_id) as products,
         count(distinct s.sku_id)     as skus
  from scout.product_source ps
  join scout.product_catalog p on p.product_id = ps.product_id
  join scout.brand_catalog   b on b.brand_id   = p.brand_id
  left join scout.sku        s on s.product_id = p.product_id
  group by 1
)
select
  s.code as source_code,
  s.name as source_name,
  coalesce(s.category,'') as category,
  coalesce(j.queued,0)  as queued,
  coalesce(j.running,0) as running,
  coalesce(j.done,0)    as done,
  coalesce(j.error,0)   as error,
  coalesce(j.blocked,0) as blocked,
  coalesce(c.brands,0)  as brands,
  coalesce(c.products,0) as products,
  coalesce(c.skus,0)     as skus
from deep_research.sources s
left join jobs j on j.source_code = s.code
left join cat  c on c.source_code = s.code
order by s.code;

create or replace view scout.v_snowball_overall as
select
  (select count(*) from deep_research.jobs where status='queued')  as jobs_queued,
  (select count(*) from deep_research.jobs where status='running') as jobs_running,
  (select count(*) from deep_research.jobs where status='done')    as jobs_done,
  (select count(*) from deep_research.jobs where status='error')   as jobs_error,
  (select count(*) from deep_research.jobs where status='blocked') as jobs_blocked,
  (select count(distinct brand_id)   from scout.brand_catalog)     as brands,
  (select count(distinct product_id) from scout.product_catalog)   as products,
  (select count(distinct sku_id)     from scout.sku)               as skus;