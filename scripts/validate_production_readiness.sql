-- Production Readiness Validation Script
-- Run this to verify all blockers are fixed

-- 1. Check for SECURITY DEFINER functions (should return 0 rows)
select 
  n.nspname as schema, 
  p.proname as function_name, 
  p.prosecdef as is_definer
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public')
  and p.proname ~ '^(get_suqi_|ask_suqi_|search_ai_corpus|vector_search_ai_corpus|generate_report|track_event)'
  and p.prosecdef is true;

-- 2. Verify canonical search function exists
select 
  proname as function_name,
  proargtypes::regtype[] as arguments,
  prorettype::regtype as return_type,
  prosecdef as is_definer
from pg_proc
where proname in ('search_ai_corpus', 'vector_search_ai_corpus')
order by proname;

-- 3. Check MV refresh helper exists
select exists(
  select 1 from pg_proc 
  where proname = 'refresh_filter_mvs'
) as refresh_helper_exists;

-- 4. Verify pg_cron job for MV refresh
select 
  jobid,
  schedule,
  command,
  nodename,
  nodeport,
  database,
  username,
  active
from cron.job
where command like '%refresh_filter_mvs%';

-- 5. Check telemetry event aliasing logic
select 
  proname,
  prosrc
from pg_proc
where proname = 'track_event'
limit 1;

-- 6. Verify platform-based access control in ask_suqi_query
select 
  exists(
    select 1 
    from pg_proc 
    where proname = 'ask_suqi_query' 
      and prosrc like '%platform%docs%SQL operations not allowed%'
  ) as has_platform_gating;

-- 7. Check for proper JWT validation in ask_suqi_query
select 
  exists(
    select 1 
    from pg_proc 
    where proname = 'ask_suqi_query' 
      and prosrc like '%tenant mismatch%'
      and prosrc like '%vendor mismatch%'
  ) as has_jwt_validation;

-- 8. Verify performance metrics function
select 
  proname,
  prorettype::regtype as return_type
from pg_proc
where proname = 'get_suqi_performance_metrics';

-- 9. Check query cache structure
select 
  column_name,
  data_type,
  is_nullable
from information_schema.columns
where table_schema = 'scout'
  and table_name = 'query_cache'
order by ordinal_position;

-- 10. Verify AI corpus table with vector column
select 
  column_name,
  data_type,
  udt_name
from information_schema.columns
where table_schema = 'scout'
  and table_name = 'ai_corpus'
  and column_name = 'embedding';

-- Summary Report
select 
  'Production Readiness Checklist' as report,
  json_build_object(
    'security_definer_count', (
      select count(*) from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' 
        and p.proname ~ '^(get_suqi_|ask_suqi_|search_ai_corpus|vector_search_ai_corpus)'
        and p.prosecdef
    ),
    'canonical_search_exists', exists(select 1 from pg_proc where proname = 'search_ai_corpus'),
    'compat_wrapper_exists', exists(select 1 from pg_proc where proname = 'vector_search_ai_corpus'),
    'mv_refresh_helper_exists', exists(select 1 from pg_proc where proname = 'refresh_filter_mvs'),
    'platform_gating_exists', exists(
      select 1 from pg_proc 
      where proname = 'ask_suqi_query' and prosrc like '%platform%docs%'
    ),
    'jwt_validation_exists', exists(
      select 1 from pg_proc 
      where proname = 'ask_suqi_query' and prosrc like '%tenant mismatch%'
    )
  ) as status;