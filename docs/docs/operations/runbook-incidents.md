# Incident Response Runbook

## 🚨 Severity Levels

| Level | Response Time | Examples |
|-------|--------------|----------|
| **P1 - Critical** | 15 minutes | Complete outage, data loss |
| **P2 - High** | 1 hour | Partial outage, performance degradation |
| **P3 - Medium** | 4 hours | Feature unavailable, non-critical errors |
| **P4 - Low** | 24 hours | Minor bugs, cosmetic issues |

## 📋 Incident Response Checklist

### 1. Initial Response (0-15 minutes)
- [ ] Acknowledge incident in monitoring system
- [ ] Create incident channel in Slack: `#incident-YYYY-MM-DD-description`
- [ ] Assign Incident Commander (IC)
- [ ] Post initial status update

### 2. Assessment (15-30 minutes)
- [ ] Determine impact scope
- [ ] Identify affected services
- [ ] Check monitoring dashboards
- [ ] Review recent deployments

### 3. Communication
- [ ] Update status page
- [ ] Notify stakeholders via email
- [ ] Post updates every 30 minutes

### 4. Resolution
- [ ] Implement fix or rollback
- [ ] Verify resolution
- [ ] Monitor for 30 minutes
- [ ] Update status page

### 5. Post-Mortem
- [ ] Schedule post-mortem meeting
- [ ] Document root cause
- [ ] Create action items
- [ ] Update runbooks

## 🔍 Common Issues

### High API Latency
```bash
# Check Supabase connection pool
psql $PGURI -c "SELECT count(*) FROM pg_stat_activity;"

# Check Edge Function logs
supabase functions logs ingest-transaction --project-ref $PROJECT_REF

# Scale up if needed
kubectl scale deployment api-gateway --replicas=5
```

### Database Connection Errors
```bash
# Check connection count
psql $PGURI -c "SELECT max_conn, used, res_for_super FROM pg_stat_database_conflicts;"

# Kill idle connections
psql $PGURI -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle' AND state_change < NOW() - INTERVAL '10 minutes';"

# Restart connection pooler
kubectl rollout restart deployment pgbouncer
```

### Superset Dashboard Errors
```bash
# Check Superset logs
kubectl logs -l app=superset -n analytics --tail=100

# Clear cache
curl -X POST $SUPERSET_BASE/api/v1/cachekey/invalidate \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-CSRFToken: $CSRF"

# Restart workers
kubectl rollout restart deployment superset-worker
```

## 📞 Escalation Matrix

| Service | Primary | Secondary | Executive |
|---------|---------|-----------|-----------|
| Database | @dbteam | @platform | @cto |
| API | @backend | @platform | @cto |
| Dashboards | @frontend | @analytics | @cpo |
| ML/AI | @datascience | @platform | @cto |

## 🛠️ Useful Commands

### Health Checks
```bash
# API health
curl -s $SUPABASE_URL/functions/v1/health | jq .

# Database health
psql $PGURI -c "SELECT version();"

# Superset health
curl -s $SUPERSET_BASE/health | jq .
```

### Quick Diagnostics
```bash
# Recent errors
kubectl logs -l app=scout --since=1h | grep ERROR

# Resource usage
kubectl top pods -n analytics

# Active queries
psql $PGURI -c "SELECT pid, query, state FROM pg_stat_activity WHERE state != 'idle';"
```
