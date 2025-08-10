-- MV refresh with advisory lock + audit trail
create table if not exists scout.gold_refresh_audit(
  id bigserial primary key,
  mv text not null,
  refreshed_at timestamptz not null default now()
);

create or replace function scout.refresh_gold()
returns void
language plpgsql
as $$
begin
  -- prevent concurrent storms
  if pg_try_advisory_lock(787878, 1) then
    begin
      refresh materialized view concurrently scout.gold_txn_daily;
      insert into scout.gold_refresh_audit(mv) values ('gold_txn_daily');
    exception when undefined_table then
      null;
    end;
    begin
      refresh materialized view concurrently scout.gold_basket_patterns;
      insert into scout.gold_refresh_audit(mv) values ('gold_basket_patterns');
    exception when undefined_table then
      null;
    end;
    begin
      refresh materialized view concurrently scout.gold_substitution_flows;
      insert into scout.gold_refresh_audit(mv) values ('gold_substitution_flows');
    exception when undefined_table then
      null;
    end;
    begin
      refresh materialized view concurrently scout.gold_request_behavior;
      insert into scout.gold_refresh_audit(mv) values ('gold_request_behavior');
    exception when undefined_table then
      null;
    end;
    begin
      refresh materialized view concurrently scout.gold_demographics;
      insert into scout.gold_refresh_audit(mv) values ('gold_demographics');
    exception when undefined_table then
      null;
    end;
    perform pg_advisory_unlock(787878, 1);
  end if;
end $$;