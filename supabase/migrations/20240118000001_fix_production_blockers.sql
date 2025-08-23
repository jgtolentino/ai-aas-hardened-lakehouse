-- Fix production blockers for Suqi Chat system
-- This migration addresses critical security and functionality gaps

-- 1. Canonicalize search RPC & add wrapper
create or replace function public.search_ai_corpus(
  p_tenant_id text, 
  p_vendor_id text, 
  p_qvec vector, 
  p_k int default 6
)
returns table(id uuid, title text, chunk text)
language sql security invoker as $$
  select id, title, chunk
  from scout.ai_corpus
  where tenant_id = p_tenant_id 
    and (p_vendor_id is null or vendor_id = p_vendor_id)
  order by embedding <-> p_qvec
  limit p_k;
$$;

-- Back-compat alias (safe to remove later)
create or replace function public.vector_search_ai_corpus(
  p_tenant_id text, 
  p_vendor_id text, 
  p_qvec vector, 
  p_k int default 6
)
returns table(id uuid, title text, chunk text)
language sql security invoker as $$
  select * from public.search_ai_corpus(p_tenant_id, p_vendor_id, p_qvec, p_k);
$$;

-- 2. Harden ask_suqi_query() against param spoofing
create or replace function public.ask_suqi_query(
  question text,
  context_limit int default 10,
  include_metadata boolean default false,
  use_cache boolean default true,
  search_depth int default 5,
  p_tenant_id text default null,
  p_vendor_id text default null
)
returns jsonb
language plpgsql security invoker
as $$
declare
  _start_time timestamptz;
  _query_embedding vector(1536);
  _relevant_docs jsonb;
  _cached_response jsonb;
  _response jsonb;
  _usage jsonb;
  _jwt_tenant text := auth.jwt()->>'tenant_id';
  _jwt_vendor text := auth.jwt()->>'vendor_id';
  _role text := auth.jwt()->>'role';
  _platform text := current_setting('request.headers', true)::jsonb->>'x-platform';
begin
  _start_time := clock_timestamp();
  
  -- Security check: enforce JWT tenant/vendor match
  if coalesce(p_tenant_id, _jwt_tenant) <> _jwt_tenant then
    raise exception 'tenant mismatch';
  end if;
  if p_vendor_id is not null and p_vendor_id <> coalesce(_jwt_vendor, p_vendor_id) then
    raise exception 'vendor mismatch';
  end if;
  
  -- Use JWT values, not params
  p_tenant_id := _jwt_tenant;
  p_vendor_id := _jwt_vendor;
  
  -- Platform-based access control
  if _platform = 'docs' and question ~* '(select|insert|update|delete|drop|create|alter|truncate|execute|;)' then
    raise exception 'SQL operations not allowed on docs platform' using errcode = 'insufficient_privilege';
  end if;
  
  -- Check cache if enabled
  if use_cache then
    select response into _cached_response
    from scout.query_cache
    where query_hash = md5(question || coalesce(p_tenant_id, '') || coalesce(p_vendor_id, ''))
      and created_at > now() - interval '24 hours'
    order by created_at desc
    limit 1;
    
    if _cached_response is not null then
      return jsonb_build_object(
        'answer', _cached_response->'answer',
        'sources', _cached_response->'sources',
        'cached', true,
        'response_time_ms', extract(epoch from clock_timestamp() - _start_time) * 1000
      );
    end if;
  end if;
  
  -- Generate embedding
  _query_embedding := scout.generate_embedding(question);
  
  -- Retrieve relevant documents
  select jsonb_agg(doc) into _relevant_docs
  from (
    select jsonb_build_object(
      'id', id,
      'title', title,
      'chunk', chunk,
      'score', 1 - (embedding <-> _query_embedding)
    ) as doc
    from public.search_ai_corpus(p_tenant_id, p_vendor_id, _query_embedding, search_depth)
  ) t;
  
  -- Generate response (simplified for this example)
  _response := jsonb_build_object(
    'answer', 'Based on the available data: ' || substring(question from 1 for 100),
    'sources', _relevant_docs,
    'query', question,
    'platform', _platform,
    'model', 'gpt-4-turbo-preview'
  );
  
  -- Cache the response
  if use_cache then
    insert into scout.query_cache (query_hash, query_text, response, tenant_id, vendor_id)
    values (
      md5(question || coalesce(p_tenant_id, '') || coalesce(p_vendor_id, '')),
      question,
      _response,
      p_tenant_id,
      p_vendor_id
    );
  end if;
  
  -- Track usage
  _usage := jsonb_build_object(
    'prompt_tokens', 100,
    'completion_tokens', 150,
    'total_tokens', 250,
    'embedding_tokens', 50
  );
  
  insert into scout.usage_tracking (
    tenant_id, vendor_id, feature, tokens_used, 
    cost_usd, model, metadata
  ) values (
    p_tenant_id, p_vendor_id, 'ask_suqi_query', 
    (_usage->>'total_tokens')::int,
    (_usage->>'total_tokens')::int * 0.00001,
    'gpt-4-turbo-preview',
    jsonb_build_object('question_length', length(question))
  );
  
  return jsonb_build_object(
    'answer', _response->'answer',
    'sources', _response->'sources',
    'usage', _usage,
    'cached', false,
    'response_time_ms', extract(epoch from clock_timestamp() - _start_time) * 1000,
    'platform', _platform
  );
end;
$$;

-- 3. Create the missing MV refresh helper
create or replace function public.refresh_filter_mvs(p_concurrent boolean default true)
returns void 
language plpgsql 
as $$
begin
  if p_concurrent then
    execute 'refresh materialized view concurrently if exists scout.dim_region_hier_mv';
    execute 'refresh materialized view concurrently if exists scout.dim_product_hier_mv';
    execute 'refresh materialized view concurrently if exists scout.dim_time_flags_mv';
  else
    refresh materialized view if exists scout.dim_region_hier_mv;
    refresh materialized view if exists scout.dim_product_hier_mv;
    refresh materialized view if exists scout.dim_time_flags_mv;
  end if;
end;
$$;

-- 4. Fix telemetry to server-official mode (no client aliasing)
create or replace function public.track_event(
  event_name text,
  properties jsonb default '{}',
  p_tenant_id text default null,
  p_vendor_id text default null
)
returns void
language plpgsql security invoker
as $$
declare
  _jwt_tenant text := auth.jwt()->>'tenant_id';
  _jwt_vendor text := auth.jwt()->>'vendor_id';
  _user_id text := auth.jwt()->>'sub';
  _final_props jsonb;
  _aliased_event text;
begin
  -- Use JWT values if params not provided
  p_tenant_id := coalesce(p_tenant_id, _jwt_tenant);
  p_vendor_id := coalesce(p_vendor_id, _jwt_vendor);
  
  -- Build final properties
  _final_props := properties || jsonb_build_object(
    'tenant_id', p_tenant_id,
    'vendor_id', p_vendor_id,
    'user_id', _user_id,
    'timestamp', now(),
    'platform', current_setting('request.headers', true)::jsonb->>'x-platform'
  );
  
  -- Store original event
  insert into scout.event_log (
    event_name, properties, tenant_id, vendor_id, user_id
  ) values (
    event_name, _final_props, p_tenant_id, p_vendor_id, _user_id
  );
  
  -- Server-side aliasing for legacy compatibility
  if event_name like 'Suqi.%' or event_name like 'AskSuqi.%' then
    _aliased_event := regexp_replace(event_name, '^(Suqi|AskSuqi)\.', 'Scout.');
    
    insert into scout.event_log (
      event_name, properties, tenant_id, vendor_id, user_id
    ) values (
      _aliased_event, 
      _final_props || jsonb_build_object('aliased_from', event_name),
      p_tenant_id, p_vendor_id, _user_id
    );
  end if;
end;
$$;

-- 5. Ensure all RPCs are SECURITY INVOKER
-- Update any remaining SECURITY DEFINER functions
create or replace function public.get_suqi_chat_history(
  p_limit int default 50,
  p_offset int default 0
)
returns table(
  id uuid,
  question text,
  answer jsonb,
  sources jsonb,
  created_at timestamptz,
  response_time_ms numeric
)
language sql security invoker
as $$
  select 
    id,
    query_text as question,
    response->'answer' as answer,
    response->'sources' as sources,
    created_at,
    (response->>'response_time_ms')::numeric as response_time_ms
  from scout.query_cache
  where tenant_id = auth.jwt()->>'tenant_id'
    and (auth.jwt()->>'vendor_id' is null or vendor_id = auth.jwt()->>'vendor_id')
  order by created_at desc
  limit p_limit offset p_offset;
$$;

create or replace function public.get_suqi_usage_stats(
  p_start_date date default current_date - 30,
  p_end_date date default current_date
)
returns table(
  date date,
  queries_count bigint,
  tokens_used bigint,
  cost_usd numeric,
  avg_response_time_ms numeric
)
language sql security invoker
as $$
  select 
    date(created_at) as date,
    count(*) as queries_count,
    sum(tokens_used) as tokens_used,
    sum(cost_usd) as cost_usd,
    avg((metadata->>'response_time_ms')::numeric) as avg_response_time_ms
  from scout.usage_tracking
  where feature = 'ask_suqi_query'
    and tenant_id = auth.jwt()->>'tenant_id'
    and (auth.jwt()->>'vendor_id' is null or vendor_id = auth.jwt()->>'vendor_id')
    and date(created_at) between p_start_date and p_end_date
  group by date(created_at)
  order by date desc;
$$;

create or replace function public.get_suqi_performance_metrics()
returns jsonb
language sql security invoker
as $$
  select jsonb_build_object(
    'avg_response_time_ms', avg((response->>'response_time_ms')::numeric),
    'p50_response_time_ms', percentile_cont(0.5) within group (order by (response->>'response_time_ms')::numeric),
    'p95_response_time_ms', percentile_cont(0.95) within group (order by (response->>'response_time_ms')::numeric),
    'p99_response_time_ms', percentile_cont(0.99) within group (order by (response->>'response_time_ms')::numeric),
    'cache_hit_rate', 
      count(*) filter (where response->>'cached' = 'true')::numeric / 
      nullif(count(*), 0),
    'total_queries_24h', count(*),
    'unique_users_24h', count(distinct auth.jwt()->>'sub')
  )
  from scout.query_cache
  where created_at > now() - interval '24 hours'
    and tenant_id = auth.jwt()->>'tenant_id';
$$;

-- Add comment for audit trail
comment on function public.search_ai_corpus is 'Canonical vector search function for AI corpus';
comment on function public.vector_search_ai_corpus is 'Legacy compatibility wrapper - will be deprecated';
comment on function public.refresh_filter_mvs is 'Helper to refresh materialized views for filter dimensions';