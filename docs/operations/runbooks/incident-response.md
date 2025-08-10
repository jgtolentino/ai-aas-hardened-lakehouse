# Scout Platform - Incident Response Runbook
## Version 1.0 | Last Updated: January 2025

---

## **🚨 Incident Severity Levels**

| Level | Definition | Response Time | Examples | Escalation |
|-------|------------|---------------|----------|------------|
| **SEV1** | Complete outage | < 15 min | Database down, API unreachable | CTO + On-call |
| **SEV2** | Major degradation | < 30 min | 50% queries failing, data lag > 2hr | Tech Lead + On-call |
| **SEV3** | Minor degradation | < 2 hr | Single store affected, slow queries | On-call engineer |
| **SEV4** | Low impact | < 8 hr | UI glitch, non-critical alert | Next business day |

---

## **📋 Incident Response Checklist**

### **DETECT (0-5 minutes)**
```bash
# 1. Verify incident via monitoring
curl -X GET https://cxzllzyxwpyptfretryc.supabase.co/functions/v1/health

# 2. Check Prometheus alerts
kubectl get pods -n monitoring | grep prometheus

# 3. Review error logs
supabase logs --project-ref cxzllzyxwpyptfretryc --tail 100

# 4. Check database status
psql $DATABASE_URL -c "SELECT NOW(), COUNT(*) FROM scout.silver_transactions_cleaned WHERE created_at > NOW() - INTERVAL '5 minutes';"
```

### **TRIAGE (5-15 minutes)**
```yaml
Questions to Answer:
  1. What is the error rate? (Check Grafana)
  2. How many users affected? (Query active sessions)
  3. Is data being lost? (Check bronze layer inserts)
  4. Which component failed? (Review dependency chain)
  
Immediate Actions:
  - [ ] Post in #incidents Slack channel
  - [ ] Create incident ticket
  - [ ] Assign incident commander
  - [ ] Start incident timeline doc
```

### **MITIGATE (15-30 minutes)**

#### **Scenario 1: Database Connection Exhausted**
```bash
# Symptoms: "too many connections" errors
# Resolution:
psql $DATABASE_URL -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle' AND state_change < NOW() - INTERVAL '10 minutes';"

# Restart connection pooler
kubectl rollout restart deployment/pgbouncer -n scout

# Verify recovery
watch -n 5 "psql $DATABASE_URL -c 'SELECT COUNT(*) FROM pg_stat_activity;'"
```

#### **Scenario 2: Edge Function Timeout**
```bash
# Symptoms: 504 Gateway Timeout
# Resolution:
# 1. Check function logs
supabase functions logs ingest-transaction --tail 50

# 2. Redeploy with increased timeout
supabase functions deploy ingest-transaction \
  --project-ref cxzllzyxwpyptfretryc \
  --timeout 30

# 3. Clear backlog
psql $DATABASE_URL -c "DELETE FROM scout.bronze_ingestion_batches WHERE status = 'pending' AND created_at < NOW() - INTERVAL '1 hour';"
```

#### **Scenario 3: Data Pipeline Failure**
```bash
# Symptoms: Gold views not updating
# Resolution:
# 1. Check dbt status
kubectl logs -n scout deployment/dbt-cron --tail 100

# 2. Manually trigger refresh
dbt run --models +gold_business_metrics --target prod

# 3. Refresh materialized views
psql $DATABASE_URL << EOF
REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_daily_aggregates;
REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_regional_performance;
EOF

# 4. Verify data freshness
psql $DATABASE_URL -c "SELECT MAX(updated_at) FROM scout.gold_business_metrics;"
```

#### **Scenario 4: Query Performance Degradation**
```sql
-- Symptoms: Queries > 5 seconds
-- Resolution:
-- 1. Identify slow queries
SELECT 
    query,
    calls,
    mean_exec_time,
    total_exec_time
FROM pg_stat_statements 
WHERE mean_exec_time > 5000
ORDER BY mean_exec_time DESC
LIMIT 10;

-- 2. Kill long-running queries
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'active' 
  AND query_start < NOW() - INTERVAL '5 minutes'
  AND query NOT LIKE '%pg_stat_activity%';

-- 3. Rebuild critical indexes
REINDEX TABLE CONCURRENTLY scout.silver_transactions_cleaned;
REINDEX TABLE CONCURRENTLY scout.dim_store;
REINDEX TABLE CONCURRENTLY scout.dim_product;

-- 4. Update statistics
ANALYZE scout.silver_transactions_cleaned;
VACUUM ANALYZE scout.gold_business_metrics;
```

#### **Scenario 5: API Rate Limiting**
```bash
# Symptoms: 429 Too Many Requests
# Resolution:
# 1. Check current rate limit status
curl -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/rpc/get_rate_limit_status

# 2. Temporarily increase limits
psql $DATABASE_URL -c "UPDATE scout.api_rate_limits SET requests_per_hour = 20000 WHERE api_key = 'default';"

# 3. Implement emergency caching
redis-cli SET "emergency_cache:enabled" "true" EX 3600

# 4. Notify heavy users
SELECT email, COUNT(*) as requests 
FROM scout.api_usage_analytics 
WHERE created_at > NOW() - INTERVAL '1 hour'
GROUP BY email 
ORDER BY requests DESC 
LIMIT 10;
```

### **RECOVER (30-60 minutes)**

```bash
# 1. Verify all systems operational
make status

# 2. Run smoke tests
make run-bruno-tests

# 3. Check data consistency
psql $DATABASE_URL << EOF
-- Bronze to Silver consistency
SELECT 
    (SELECT COUNT(*) FROM scout.bronze_transactions_raw) as bronze_count,
    (SELECT COUNT(*) FROM scout.silver_transactions_cleaned) as silver_count,
    (SELECT COUNT(*) FROM scout.bronze_transactions_raw) - 
    (SELECT COUNT(*) FROM scout.silver_transactions_cleaned) as delta;
EOF

# 4. Clear error queues
psql $DATABASE_URL -c "UPDATE scout.etl_alerts SET acknowledged = true WHERE created_at < NOW();"

# 5. Resume normal operations
kubectl scale deployment/scout-api --replicas=3
```

---

## **🔄 Post-Incident Process**

### **Within 24 Hours**
1. **Update incident timeline**
   ```markdown
   ## Incident #2025-001
   - **Detected**: 2025-01-15 10:30 UTC
   - **Mitigated**: 2025-01-15 10:45 UTC  
   - **Resolved**: 2025-01-15 11:00 UTC
   - **Impact**: 15 minutes partial outage, 1,200 failed transactions
   - **Root Cause**: Connection pool exhaustion
   ```

2. **Calculate impact metrics**
   ```sql
   -- Lost transactions
   SELECT COUNT(*) FROM scout.bronze_transactions_raw 
   WHERE created_at BETWEEN '2025-01-15 10:30' AND '2025-01-15 11:00'
   AND status = 'failed';
   
   -- Affected stores
   SELECT COUNT(DISTINCT store_id) FROM scout.system_alerts
   WHERE created_at BETWEEN '2025-01-15 10:30' AND '2025-01-15 11:00';
   ```

3. **Send stakeholder notification**
   - Executive summary
   - Customer impact
   - Resolution steps
   - Prevention measures

### **Within 48 Hours**
1. **Conduct blameless postmortem**
2. **Create JIRA tickets for action items**
3. **Update monitoring thresholds**
4. **Schedule GameDay for scenario**

---

## **📞 Escalation Matrix**

| Role | Name | Phone | Slack | When to Call |
|------|------|-------|-------|--------------|
| On-Call Engineer | Rotation | See PagerDuty | @oncall | First responder |
| Tech Lead | John Doe | +63-xxx-xxxx | @johndoe | SEV1-2 incidents |
| Platform Lead | Jane Smith | +63-xxx-xxxx | @janesmith | Database issues |
| CTO | Mike Johnson | +63-xxx-xxxx | @mikej | SEV1 or PR crisis |
| Customer Success | Sarah Lee | +63-xxx-xxxx | @sarahlee | Customer communication |

---

## **🛠️ Emergency Access**

### **Production Database**
```bash
# Read-only access
export READONLY_DB_URL="postgresql://readonly_user@db.cxzllzyxwpyptfretryc.supabase.co:5432/postgres"

# Admin access (USE WITH CAUTION)
export ADMIN_DB_URL="postgresql://postgres@db.cxzllzyxwpyptfretryc.supabase.co:5432/postgres"
```

### **Kubernetes Cluster**
```bash
# Get cluster credentials
gcloud container clusters get-credentials scout-prod --region=asia-southeast1

# Emergency pod access
kubectl exec -it deployment/scout-api -n scout -- /bin/bash
```

### **Bypass Procedures**
```bash
# Disable RLS temporarily (EMERGENCY ONLY)
psql $ADMIN_DB_URL -c "ALTER TABLE scout.silver_transactions_cleaned DISABLE ROW LEVEL SECURITY;"

# Remember to re-enable!
psql $ADMIN_DB_URL -c "ALTER TABLE scout.silver_transactions_cleaned ENABLE ROW LEVEL SECURITY;"
```

---

## **📊 Common Error Patterns**

| Error Message | Likely Cause | Quick Fix |
|--------------|--------------|-----------|
| `FATAL: too many connections` | Connection leak | Restart pgbouncer |
| `ERROR: deadlock detected` | Concurrent updates | Retry with backoff |
| `timeout: context deadline exceeded` | Slow query | Check indexes |
| `ERROR: out of shared memory` | Too many locks | Increase max_locks |
| `PANIC: could not write to log file` | Disk full | Clear old logs |
| `ERROR: duplicate key violation` | Race condition | Use ON CONFLICT |

---

## **✅ Recovery Verification**

```bash
#!/bin/bash
# save as verify_recovery.sh

echo "🔍 Verifying Scout Platform Recovery..."

# 1. API Health
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://cxzllzyxwpyptfretryc.supabase.co/functions/v1/health)
[ "$API_STATUS" = "200" ] && echo "✅ API: Healthy" || echo "❌ API: Unhealthy ($API_STATUS)"

# 2. Database Connectivity  
psql $DATABASE_URL -c "SELECT 1" > /dev/null 2>&1 && echo "✅ Database: Connected" || echo "❌ Database: Disconnected"

# 3. Data Freshness
FRESHNESS=$(psql -t $DATABASE_URL -c "SELECT EXTRACT(EPOCH FROM (NOW() - MAX(created_at)))/60 FROM scout.bronze_transactions_raw;")
[ $(echo "$FRESHNESS < 60" | bc) -eq 1 ] && echo "✅ Data: Fresh (<60 min)" || echo "⚠️ Data: Stale (${FRESHNESS} min)"

# 4. Error Rate
ERROR_COUNT=$(psql -t $DATABASE_URL -c "SELECT COUNT(*) FROM scout.system_alerts WHERE created_at > NOW() - INTERVAL '5 minutes' AND severity = 'ERROR';")
[ "$ERROR_COUNT" -lt "10" ] && echo "✅ Errors: Low ($ERROR_COUNT)" || echo "⚠️ Errors: High ($ERROR_COUNT)"

echo "Recovery verification complete!"
```

---

## **📚 Related Documentation**

- [Performance Tuning Guide](./performance-tuning.md)
- [Disaster Recovery Procedures](../disaster-recovery/RECOVERY_PROCEDURES.md)
- [Deployment Procedures](./deployment-procedures.md)
- [Architecture Overview](../../architecture/SOLUTION_ARCHITECTURE.md)

---

## **Version History**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-01-15 | Platform Team | Initial runbook |

---

*This runbook is a living document. Update it after every incident with new scenarios and solutions.*
