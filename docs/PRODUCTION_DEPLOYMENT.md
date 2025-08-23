# Production Deployment Guide

## Cutover Checklist

This checklist ensures the system is production-ready with all security and performance requirements met.

### Database Migration

1. **Apply the production fixes migration**:
   ```bash
   supabase db push --linked
   # or
   psql $DATABASE_URL -f supabase/migrations/20240118000001_fix_production_blockers.sql
   ```

2. **Run validation script**:
   ```bash
   psql $DATABASE_URL -f scripts/validate_production_readiness.sql
   ```

   Expected output:
   - `security_definer_count`: 0
   - `canonical_search_exists`: true
   - `compat_wrapper_exists`: true
   - `mv_refresh_helper_exists`: true
   - `platform_gating_exists`: true
   - `jwt_validation_exists`: true

### Environment Configuration

1. **Set up environment variables**:
   ```bash
   cp .env.example .env.local
   # Edit .env.local with your values
   ```

2. **Enable DB orchestration mode**:
   ```bash
   SUQI_CHAT_MODE=db  # Uses database orchestrator
   ```

### Bruno API Tests

1. **Run platform gating tests**:
   ```bash
   bruno run platform/cloud-wire/bruno/scout-analytics/04_docs_cannot_sql.bru
   bruno run platform/cloud-wire/bruno/scout-analytics/05_analytics_can_readonly_sql.bru
   ```

   Expected:
   - Docs platform: 401/403/422 (denied)
   - Analytics platform: 200 OK

### Telemetry Configuration

The system uses **server-official** telemetry mode:
- Client emits: `Suqi.*`, `AskSuqi.*` events
- Server aliases to: `Scout.*` for backward compatibility
- No double-counting in analytics

### Performance Monitoring

1. **Check p95 latencies**:
   ```sql
   select * from public.get_suqi_performance_metrics();
   ```

   Targets:
   - p95_response_time_ms < 2000
   - cache_hit_rate > 0.3
   - total_queries_24h > 0

2. **Monitor MV refresh**:
   ```sql
   select * from cron.job_run_details 
   where command like '%refresh_filter_mvs%'
   order by start_time desc limit 10;
   ```

### Security Verification

1. **JWT enforcement test**:
   ```bash
   # Try to spoof tenant_id (should fail)
   curl -X POST $SUPABASE_URL/rest/v1/rpc/ask_suqi_query \
     -H "Authorization: Bearer $TOKEN" \
     -d '{"question":"test","p_tenant_id":"spoofed"}'
   ```

2. **Platform gating test**:
   ```bash
   # Docs platform with SQL (should fail)
   curl -X POST $SUPABASE_URL/rest/v1/rpc/ask_suqi_query \
     -H "Authorization: Bearer $TOKEN" \
     -H "x-platform: docs" \
     -d '{"question":"SELECT * FROM users"}'
   ```

### Frontend Deployment

1. **Update dependencies**:
   ```bash
   npm install
   npm run build
   ```

2. **Verify telemetry**:
   - Check browser console for PostHog events
   - Ensure only `Suqi.*` events are sent
   - No duplicate `Scout.*` events from client

3. **Test RAG fallback**:
   - Temporarily rename `search_ai_corpus` function
   - Verify app falls back to `vector_search_ai_corpus`
   - Restore function name

### Production Checklist

- [ ] ✅ Wrapper for `vector_search_ai_corpus` → `search_ai_corpus` in place
- [ ] ✅ `ask_suqi_query()` enforces JWT = params (or ignores params)
- [ ] ✅ Audit shows **no SECURITY DEFINER** RPCs
- [ ] ✅ `refresh_filter_mvs()` exists; pg_cron job succeeds
- [ ] ✅ One telemetry aliasing path only (server-official)
- [ ] ✅ Bruno policy tests: Docs-deny, Analytics-allow
- [ ] ✅ Superset link-out reproduces filters
- [ ] ✅ p95s logged in `get_suqi_performance_metrics()` meet targets

### Rollback Plan

If issues arise:

1. **Revert to Node orchestration**:
   ```bash
   SUQI_CHAT_MODE=node
   ```

2. **Disable platform gating** (emergency):
   ```sql
   -- Remove platform check temporarily
   create or replace function public.ask_suqi_query(...)
   -- Remove the platform check section
   ```

3. **Restore legacy function names**:
   ```sql
   -- Swap primary/alias if needed
   alter function search_ai_corpus rename to search_ai_corpus_new;
   alter function vector_search_ai_corpus rename to search_ai_corpus;
   ```

### Monitoring Post-Deployment

1. **Set up alerts**:
   ```sql
   -- High latency alert
   select count(*) from scout.query_cache
   where created_at > now() - interval '1 hour'
     and (response->>'response_time_ms')::numeric > 5000;
   ```

2. **Track error rates**:
   ```sql
   select date_trunc('hour', created_at) as hour,
          count(*) filter (where event_name = 'Suqi.Error') as errors,
          count(*) as total_events,
          count(*) filter (where event_name = 'Suqi.Error')::float / nullif(count(*), 0) as error_rate
   from scout.event_log
   where created_at > now() - interval '24 hours'
   group by 1
   order by 1 desc;
   ```

3. **Cache performance**:
   ```sql
   select * from public.get_suqi_performance_metrics();
   ```

## Support

For issues:
1. Check logs: `supabase functions logs ask_suqi_query`
2. Run validation: `scripts/validate_production_readiness.sql`
3. Review telemetry: PostHog dashboard for `Suqi.*` events