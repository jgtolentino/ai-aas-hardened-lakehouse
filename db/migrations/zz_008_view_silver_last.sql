-- Latest-value semantics for late/out-of-order events
create or replace view scout.v_silver_last as
select distinct on (id)
  *
from scout.silver_transactions
order by id, ts desc, coalesce(ingested_at, ts) desc;