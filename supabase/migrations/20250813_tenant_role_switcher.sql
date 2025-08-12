-- supabase/migrations/20250813_tenant_role_switcher.sql
set search_path = scout, public, pg_catalog;

-- 1) RLS on memberships: user can read/update only their own rows
alter table if exists scout.tenant_memberships enable row level security;

drop policy if exists tm_read_self on scout.tenant_memberships;
create policy tm_read_self on scout.tenant_memberships
for select to authenticated
using (user_id = auth.uid());

drop policy if exists tm_update_self on scout.tenant_memberships;
create policy tm_update_self on scout.tenant_memberships
for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- 2) RPC: set_default_tenant (self-only)
create or replace function scout.set_default_tenant(p_tenant_id bigint)
returns boolean
language plpgsql
security invoker
set search_path = scout, public
as $
declare
  affected int := 0;
begin
  -- Clear current defaults for this user
  update scout.tenant_memberships
    set is_default = false
  where user_id = auth.uid();

  -- Set the requested tenant as default (only if the user is a member)
  update scout.tenant_memberships
    set is_default = true
  where user_id = auth.uid() and tenant_id = p_tenant_id;

  get diagnostics affected = row_count;
  if affected = 0 then
    raise exception 'You do not belong to tenant %', p_tenant_id;
  end if;

  return true;
end
$;

revoke execute on function scout.set_default_tenant(bigint) from public, anon;
grant  execute on function scout.set_default_tenant(bigint) to authenticated;