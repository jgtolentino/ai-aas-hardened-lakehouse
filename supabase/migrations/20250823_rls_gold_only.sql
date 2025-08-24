-- ===========================================================
-- Scout v5.2 — RLS Gold-Only Access
-- ===========================================================

-- Revoke all default permissions on scout schema
revoke all on schema scout from public, anon, authenticated;

-- Grant usage on scout schema to authenticated
grant usage on schema scout to authenticated;

-- Function to check if a table is a gold table
create or replace function scout.is_gold_table(table_name text)
returns boolean
language sql
immutable
as $$
  select table_name like 'gold_%';
$$;

-- Grant SELECT on all current gold tables
do $$
declare
  r record;
begin
  for r in 
    select tablename 
    from pg_tables 
    where schemaname = 'scout' 
    and tablename like 'gold_%'
  loop
    execute format('grant select on scout.%I to authenticated', r.tablename);
  end loop;
end $$;

-- Grant SELECT on specific allowed tables
grant select on scout.agent_feed to authenticated;
grant select on scout.platinum_monitors to authenticated;

-- Create policy function for future tables
create or replace function scout.enforce_gold_only_access()
returns event_trigger
language plpgsql
as $$
declare
  r record;
begin
  for r in select * from pg_event_trigger_ddl_commands()
  loop
    if r.object_type = 'table' and r.schema_name = 'scout' then
      -- Extract table name from object identity
      if r.object_identity like 'scout.gold_%' then
        execute format('grant select on %s to authenticated', r.object_identity);
      elsif r.object_identity in ('scout.agent_feed', 'scout.platinum_monitors') then
        execute format('grant select on %s to authenticated', r.object_identity);
      else
        -- Revoke access from non-gold tables
        execute format('revoke all on %s from authenticated', r.object_identity);
      end if;
    end if;
  end loop;
end;
$$;

-- Create event trigger to enforce gold-only access on new tables
drop event trigger if exists enforce_gold_only_trigger;
create event trigger enforce_gold_only_trigger
on ddl_command_end
when tag in ('CREATE TABLE', 'CREATE TABLE AS')
execute function scout.enforce_gold_only_access();

-- RLS Policies for agent_feed (already enabled in core migration)
drop policy if exists agent_feed_authenticated_read on scout.agent_feed;
create policy agent_feed_authenticated_read 
on scout.agent_feed 
for select 
to authenticated
using (true);

-- RLS Policies for platinum_monitors  
drop policy if exists monitors_authenticated_read on scout.platinum_monitors;
create policy monitors_authenticated_read
on scout.platinum_monitors
for select
to authenticated  
using (true);

-- No INSERT/UPDATE/DELETE for authenticated on any scout tables
-- (service role can still write)

-- Grant execute on allowed RPCs
grant execute on function scout.rpc_feed_list(int) to authenticated;
grant execute on function scout.exec(text) to authenticated;
grant execute on function scout.get_products_needing_isko(int) to authenticated;

-- Create a health check function for Gold access
create or replace function scout.check_gold_access()
returns jsonb
language plpgsql
security definer
as $$
declare
  result jsonb = '[]'::jsonb;
  r record;
begin
  -- List all tables authenticated can access in scout schema
  for r in
    select 
      c.relname as table_name,
      has_table_privilege('authenticated', c.oid, 'SELECT') as can_select,
      has_table_privilege('authenticated', c.oid, 'INSERT') as can_insert,
      has_table_privilege('authenticated', c.oid, 'UPDATE') as can_update,
      has_table_privilege('authenticated', c.oid, 'DELETE') as can_delete
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'scout'
    and c.relkind = 'r'
    order by c.relname
  loop
    result = result || jsonb_build_object(
      'table', r.table_name,
      'permissions', jsonb_build_object(
        'select', r.can_select,
        'insert', r.can_insert,
        'update', r.can_update,
        'delete', r.can_delete
      ),
      'is_gold', r.table_name like 'gold_%',
      'is_allowed', r.table_name like 'gold_%' or r.table_name in ('agent_feed', 'platinum_monitors')
    );
  end loop;
  
  return result;
end;
$$;

grant execute on function scout.check_gold_access() to authenticated;