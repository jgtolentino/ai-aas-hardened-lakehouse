with checks(name, ok) as (
  values
    ('schema_scout'               , exists (select 1 from information_schema.schemata where schema_name='scout')),
    ('table_agents'               , to_regclass('scout.agents') is not null),
    ('table_session_history'      , to_regclass('scout.session_history') is not null),
    ('table_events'               , to_regclass('scout.events') is not null),
    ('table_knowledge_base'       , to_regclass('scout.knowledge_base') is not null),
    ('policy_agents_tenant_rw'    , exists (select 1 from pg_policies where schemaname='scout' and tablename='agents' and policyname='tenant_rw' or policyname='tenant_read_write')),
    ('policy_sessions_tenant_rw'  , exists (select 1 from pg_policies where schemaname='scout' and tablename='session_history' and policyname='tenant_rw' or policyname='tenant_read_write')),
    ('policy_events_tenant_rw'    , exists (select 1 from pg_policies where schemaname='scout' and tablename='events' and policyname='tenant_rw' or policyname='tenant_read_write')),
    ('policy_kb_tenant_rw'        , exists (select 1 from pg_policies where schemaname='scout' and tablename='knowledge_base' and policyname='tenant_rw' or policyname='tenant_read_write')),
    ('rpc_upsert_event'           , exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='scout' and proname='upsert_event'))
)
select * from checks
union all
select 'ALL_OK', bool_and(ok) from checks;
