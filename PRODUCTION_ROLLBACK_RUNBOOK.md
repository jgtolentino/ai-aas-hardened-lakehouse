# Scout v5.2 - Production Rollback & Recovery Runbook 🚨

## 🆘 Emergency Procedures

### Quick Actions (60-Second Response)

#### 🛑 **STOP INGESTION** (Critical Issues)
```sql
-- Immediately pause all ingestion processing
SELECT scout.control_ingestion('pause');

-- Verify ingestion is stopped
SELECT * FROM scout.control_ingestion('status');
```

#### 🔍 **ASSESS DAMAGE** (Health Check)
```sql
-- Check pipeline health
SELECT * FROM scout.v_ingest_freshness;

-- Check for critical alerts
SELECT * FROM scout.v_quality_alerts WHERE severity = 'critical';

-- Review data quality report
SELECT * FROM scout.data_quality_report(1); -- Last 1 hour
```

#### 📊 **QUARANTINE DATA** (Suspect Transactions)
```sql
-- Move suspect data to Dead Letter Queue
INSERT INTO scout.bronze_events_dlq (
    original_payload, error_code, error_message, source_system
)
SELECT 
    event_data,
    'QUARANTINE',
    'Emergency quarantine during incident response',
    source_system
FROM scout.bronze_events
WHERE ingested_at >= '[INCIDENT_START_TIME]'::timestamptz;

-- Delete from main processing tables
DELETE FROM scout.bronze_events 
WHERE ingested_at >= '[INCIDENT_START_TIME]'::timestamptz;
```

## 🔧 Recovery Procedures

### Scenario 1: Data Quality Issues

#### Problem: Bad transaction data causing math violations
```sql
-- 1. Identify affected time window
SELECT MIN(processed_at), MAX(processed_at), COUNT(*)
FROM scout.silver_transactions
WHERE total_amount < 0 OR item_count <= 0;

-- 2. Quarantine affected transactions
INSERT INTO scout.bronze_events_dlq (
    original_payload, error_code, error_message
)
SELECT 
    jsonb_build_object('transaction_id', transaction_id),
    'INVALID_AMOUNTS',
    'Negative amounts detected',
    'data_quality'
FROM scout.silver_transactions
WHERE total_amount < 0;

-- 3. Clean up silver data
DELETE FROM scout.silver_line_items 
WHERE transaction_id IN (
    SELECT transaction_id FROM scout.silver_transactions 
    WHERE total_amount < 0
);

DELETE FROM scout.silver_transactions WHERE total_amount < 0;

-- 4. Resume ingestion
SELECT scout.control_ingestion('resume');
```

### Scenario 2: ETL Processing Stuck

#### Problem: Bronze → Silver processing stopped/delayed
```sql
-- 1. Check for stuck advisory locks
SELECT * FROM pg_locks WHERE locktype = 'advisory' AND NOT granted;

-- 2. Kill stuck processes (if found)
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE query LIKE '%load_silver_from_bronze%' 
  AND state = 'active'
  AND query_start < now() - interval '10 minutes';

-- 3. Clear advisory locks (nuclear option)
SELECT pg_advisory_unlock_all();

-- 4. Restart ETL processing
SELECT scout.load_silver_from_bronze(1000);
```

### Scenario 3: Time Window Reprocessing

#### Problem: Need to reprocess specific time period
```sql
-- 1. Reprocess Bronze events for time window
SELECT scout.reprocess_bronze_window(
    '2025-08-24 14:00:00+08'::timestamptz,
    '2025-08-24 16:00:00+08'::timestamptz,
    2000  -- batch size
);

-- 2. Verify reprocessing results
SELECT 
    COUNT(*) as reprocessed_transactions,
    MIN(processed_at) as earliest_processed,
    MAX(processed_at) as latest_processed
FROM scout.silver_transactions
WHERE processed_at >= now() - interval '1 hour';
```

### Scenario 4: Gold Layer Refresh Issues

#### Problem: Materialized views not refreshing
```sql
-- 1. Check refresh status
SELECT * FROM scout.v_gold_freshness;

-- 2. Manual refresh with monitoring
SELECT scout.refresh_gold_platinum();

-- 3. If refresh fails, check dependencies
REFRESH MATERIALIZED VIEW scout.gold_daily_metrics;
REFRESH MATERIALIZED VIEW scout.gold_region_choropleth;
```

## 📋 Incident Response Checklist

### Phase 1: Detection & Assessment (0-5 minutes)
- [ ] **Alert received** - identify incident type and severity
- [ ] **Run health check** - `SELECT * FROM scout.v_ingest_freshness;`
- [ ] **Check data quality** - `SELECT * FROM scout.data_quality_report(1);`
- [ ] **Assess impact scope** - number of affected transactions/time window
- [ ] **Notify stakeholders** if critical business impact

### Phase 2: Immediate Containment (5-15 minutes)
- [ ] **Stop ingestion** if data integrity issues - `SELECT scout.control_ingestion('pause');`
- [ ] **Quarantine suspect data** to Dead Letter Queue
- [ ] **Document incident timeline** and symptoms observed
- [ ] **Preserve evidence** - export relevant logs and data samples

### Phase 3: Root Cause Analysis (15-45 minutes)
- [ ] **Analyze pipeline logs** - check ETL performance metrics
- [ ] **Review recent changes** - deployments, configuration updates
- [ ] **Check external dependencies** - upstream data sources, API changes
- [ ] **Identify fix** required - code change, configuration, or data correction

### Phase 4: Recovery & Validation (45+ minutes)
- [ ] **Apply fix** - deploy correction or data repair
- [ ] **Reprocess affected data** using time window functions
- [ ] **Run acceptance gate** - `scripts/ci/accept_streaming_gate.sh`
- [ ] **Resume ingestion** - `SELECT scout.control_ingestion('resume');`
- [ ] **Monitor recovery** - watch metrics for 30 minutes post-recovery

### Phase 5: Post-Incident (2+ hours)
- [ ] **Document root cause** and resolution steps
- [ ] **Update monitoring** to prevent similar incidents
- [ ] **Schedule retrospective** with team
- [ ] **Update runbook** with lessons learned

## 🚨 Emergency Contacts & Escalation

### Severity Levels

#### 🔴 **Critical** (Immediate Response)
- **Impact**: Data corruption, pipeline completely down, customer-facing outage
- **Response Time**: < 5 minutes
- **Escalation**: Incident commander + engineering team + stakeholders

#### 🟡 **High** (Urgent Response) 
- **Impact**: Significant delay in data processing, quality issues affecting analysis
- **Response Time**: < 30 minutes
- **Escalation**: On-call engineer + team lead

#### 🟢 **Medium** (Standard Response)
- **Impact**: Minor delays, non-critical quality issues
- **Response Time**: < 2 hours
- **Escalation**: Standard support during business hours

### Communication Templates

#### Critical Incident Notification
```
🚨 CRITICAL: Scout v5.2 Pipeline Incident
Status: [INVESTIGATING/MITIGATING/RESOLVED]
Impact: [Brief description of business impact]
ETA: [Estimated time to resolution]
Actions: [What we're doing to fix it]

Next Update: [Timestamp]
Incident Commander: [Name]
```

## 🔧 Pre-built Recovery Scripts

### Script 1: Emergency Pipeline Reset
```bash
#!/bin/bash
# File: scripts/emergency_pipeline_reset.sh

# Stop all processing
psql "$PGURI" -c "SELECT scout.control_ingestion('pause');"

# Clear stuck locks
psql "$PGURI" -c "SELECT pg_advisory_unlock_all();"

# Restart ETL processing  
psql "$PGURI" -c "SELECT scout.load_silver_from_bronze(500);"

# Resume ingestion
psql "$PGURI" -c "SELECT scout.control_ingestion('resume');"

echo "Pipeline reset complete"
```

### Script 2: Data Quality Cleanup
```bash
#!/bin/bash
# File: scripts/data_quality_cleanup.sh

# Remove transactions with negative amounts
psql "$PGURI" <<EOF
DELETE FROM scout.silver_line_items 
WHERE transaction_id IN (
    SELECT transaction_id FROM scout.silver_transactions 
    WHERE total_amount < 0
);

DELETE FROM scout.silver_transactions WHERE total_amount < 0;
EOF

echo "Data quality cleanup complete"
```

### Script 3: Time Window Recovery
```bash
#!/bin/bash
# File: scripts/recover_time_window.sh

START_TIME="${1:-$(date -d '1 hour ago' '+%Y-%m-%d %H:%M:%S')}"
END_TIME="${2:-$(date '+%Y-%m-%d %H:%M:%S')}"

psql "$PGURI" -c "
SELECT scout.reprocess_bronze_window(
    '$START_TIME'::timestamptz,
    '$END_TIME'::timestamptz,
    1000
);"

echo "Time window recovery complete: $START_TIME to $END_TIME"
```

## 📊 Monitoring Dashboard URLs

### Real-time Monitoring Views
```sql
-- Pipeline Health Dashboard
SELECT * FROM scout.v_ingest_freshness;
SELECT * FROM scout.v_pipeline_throughput;
SELECT * FROM scout.v_etl_performance;

-- Quality Monitoring Dashboard  
SELECT * FROM scout.v_quality_alerts;
SELECT * FROM scout.data_quality_report(24); -- Last 24 hours

-- Product Linking Dashboard
SELECT * FROM scout.v_product_linking_stats;
```

### Key Metrics to Monitor Post-Recovery

#### ✅ **Success Indicators**
- Bronze staleness < 5 minutes
- Silver staleness < 5 minutes  
- Gold staleness < 10 minutes
- Product linking coverage > 95%
- Zero critical quality alerts
- ETL processing < 60 seconds average

#### ❌ **Failure Indicators**
- Any staleness > 15 minutes
- Product linking < 90%
- Critical quality alerts > 0
- ETL processing > 300 seconds
- Advisory locks stuck > 10 minutes

## 🔄 Rollback to Previous Version

### Database Schema Rollback
```sql
-- If new migration caused issues, rollback specific changes
-- (Specific rollback steps depend on migration content)

-- Example: Rollback function changes
DROP FUNCTION IF EXISTS scout.problematic_function();
-- Restore previous version from backup

-- Example: Rollback table changes
ALTER TABLE scout.table_name DROP COLUMN IF EXISTS new_column;
```

### Application Rollback
```bash
# Rollback Edge Function deployment
supabase functions deploy ingest-transaction --no-verify-jwt

# Rollback to previous git commit
git revert HEAD
git push origin main  # Triggers auto-deployment of previous version
```

## 📝 Incident Documentation Template

```markdown
# Incident Report: [YYYY-MM-DD] - [Brief Description]

## Timeline
- **Detection**: [Time] - [How was it detected?]
- **Mitigation Started**: [Time] - [First response action]
- **Root Cause Found**: [Time] - [What was the cause?]
- **Resolved**: [Time] - [How was it fixed?]

## Impact Assessment
- **Duration**: [Total incident time]
- **Data Affected**: [Number of transactions/time period]
- **Business Impact**: [Customer-facing impact]
- **Systems Affected**: [Bronze/Silver/Gold layers]

## Root Cause
[Detailed explanation of what went wrong]

## Resolution
[Detailed steps taken to resolve]

## Prevention
[Changes made to prevent recurrence]

## Follow-up Actions
- [ ] Update monitoring alerts
- [ ] Update this runbook
- [ ] Schedule team retrospective
- [ ] Document lessons learned
```

---
**⚠️ Keep this runbook updated and accessible during incidents!**
**🔄 Review and test procedures quarterly during planned maintenance windows**