# Scout Platform - Performance Tuning Runbook
## Version 1.0 | Last Updated: January 2025

---

## **⚡ Performance SLOs & Targets**

| Metric | Target | Current | Alert Threshold | Page Threshold |
|--------|--------|---------|-----------------|----------------|
| **API Response Time (p95)** | < 100ms | 95ms | > 200ms | > 500ms |
| **Query Latency (p95)** | < 2s | 1.8s | > 3s | > 5s |
| **Data Freshness** | < 1hr | 45min | > 2hr | > 4hr |
| **Transaction Throughput** | 10K/sec | 8K/sec | < 5K/sec | < 1K/sec |
| **Error Rate** | < 0.1% | 0.08% | > 0.5% | > 1% |

---

## **🔍 Performance Diagnostics**

### **Step 1: Identify Bottlenecks**

```sql
-- 1. Find slow queries
WITH slow_queries AS (
  SELECT 
    query,
    calls,
    mean_exec_time/1000 as avg_seconds,
    total_exec_time/1000 as total_seconds,
    stddev_exec_time/1000 as stddev_seconds,
    rows/NULLIF(calls,0) as avg_rows
  FROM pg_stat_statements
  WHERE query NOT LIKE '%pg_stat%'
  ORDER BY mean_exec_time DESC
  LIMIT 20
)
SELECT * FROM slow_queries;

-- 2. Check table bloat
WITH bloat AS (
  SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
    ROUND(100 * pg_total_relation_size(schemaname||'.'||tablename) / 
          NULLIF(SUM(pg_total_relation_size(schemaname||'.'||tablename)) 
          OVER (), 0), 2) as pct
  FROM pg_stat_user_tables
  WHERE schemaname = 'scout'
  ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
)
SELECT * FROM bloat;

-- 3. Identify missing indexes
SELECT 
  schemaname,
  tablename,
  attname,
  n_distinct,
  correlation
FROM pg_stats
WHERE schemaname = 'scout'
  AND n_distinct > 100
  AND correlation < 0.1
ORDER BY n_distinct DESC;

-- 4. Cache hit ratio
SELECT 
  sum(heap_blks_hit) / NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0) as cache_hit_ratio
FROM pg_statio_user_tables;
```

### **Step 2: Real-time Monitoring**

```bash
# Database connections
watch -n 1 "psql $DATABASE_URL -c \"
  SELECT state, COUNT(*) 
  FROM pg_stat_activity 
  GROUP BY state 
  ORDER BY COUNT(*) DESC;
\""

# Active queries
watch -n 2 "psql $DATABASE_URL -c \"
  SELECT pid, now() - query_start as duration, query 
  FROM pg_stat_activity 
  WHERE state = 'active' 
    AND query NOT LIKE '%pg_stat_activity%'
  ORDER BY duration DESC 
  LIMIT 5;
\""

# Transaction rate
watch -n 5 "psql $DATABASE_URL -c \"
  SELECT 
    COUNT(*) as transactions_last_5min,
    COUNT(*)/300.0 as tps
  FROM scout.bronze_transactions_raw 
  WHERE created_at > NOW() - INTERVAL '5 minutes';
\""
```

---

## **🚀 Query Optimization Techniques**

### **Technique 1: Index Optimization**

```sql
-- Identify unused indexes
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan,
  pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE schemaname = 'scout'
  AND idx_scan < 100
ORDER BY pg_relation_size(indexrelid) DESC;

-- Create missing indexes for common queries
-- Pattern: WHERE store_id = ? AND date_key = ?
CREATE INDEX CONCURRENTLY idx_transactions_store_date 
ON scout.silver_transactions_cleaned(store_id, date_key) 
WHERE deleted_at IS NULL;

-- Pattern: WHERE region = ? ORDER BY peso_value DESC
CREATE INDEX CONCURRENTLY idx_transactions_region_value 
ON scout.silver_transactions_cleaned(region, peso_value DESC) 
WHERE deleted_at IS NULL;

-- Partial indexes for hot data
CREATE INDEX CONCURRENTLY idx_transactions_recent 
ON scout.silver_transactions_cleaned(created_at DESC) 
WHERE created_at > NOW() - INTERVAL '7 days';

-- BRIN indexes for time-series
CREATE INDEX idx_transactions_created_brin 
ON scout.bronze_transactions_raw 
USING BRIN(created_at) 
WITH (pages_per_range = 128);
```

### **Technique 2: Query Rewriting**

```sql
-- BEFORE: Subquery in SELECT (N+1 problem)
SELECT 
  s.store_id,
  s.store_name,
  (SELECT COUNT(*) FROM scout.silver_transactions_cleaned t 
   WHERE t.store_id = s.store_id) as transaction_count
FROM scout.dim_store s;

-- AFTER: JOIN with aggregation
SELECT 
  s.store_id,
  s.store_name,
  COALESCE(t.transaction_count, 0) as transaction_count
FROM scout.dim_store s
LEFT JOIN (
  SELECT store_id, COUNT(*) as transaction_count
  FROM scout.silver_transactions_cleaned
  GROUP BY store_id
) t ON s.store_id = t.store_id;

-- BEFORE: Multiple CTEs
WITH daily_sales AS (...),
     weekly_sales AS (...),
     monthly_sales AS (...)
SELECT * FROM daily_sales 
UNION ALL SELECT * FROM weekly_sales 
UNION ALL SELECT * FROM monthly_sales;

-- AFTER: Single scan with conditional aggregation
SELECT 
  date_key,
  SUM(CASE WHEN date_key = CURRENT_DATE THEN peso_value END) as daily_sales,
  SUM(CASE WHEN date_key >= CURRENT_DATE - 7 THEN peso_value END) as weekly_sales,
  SUM(CASE WHEN date_key >= CURRENT_DATE - 30 THEN peso_value END) as monthly_sales
FROM scout.silver_transactions_cleaned
WHERE date_key >= CURRENT_DATE - 30
GROUP BY date_key;
```

### **Technique 3: Materialized View Management**

```sql
-- Create materialized views for expensive aggregations
CREATE MATERIALIZED VIEW scout.mv_store_daily_metrics AS
SELECT 
  store_id,
  date_key,
  COUNT(*) as transaction_count,
  SUM(peso_value) as total_revenue,
  AVG(peso_value) as avg_transaction,
  COUNT(DISTINCT customer_id) as unique_customers
FROM scout.silver_transactions_cleaned
GROUP BY store_id, date_key
WITH DATA;

-- Create indexes on materialized views
CREATE INDEX idx_mv_store_metrics_date 
ON scout.mv_store_daily_metrics(date_key);

-- Refresh strategy
-- Option 1: Concurrent refresh (no locks, but slower)
REFRESH MATERIALIZED VIEW CONCURRENTLY scout.mv_store_daily_metrics;

-- Option 2: Fast refresh with swap
BEGIN;
CREATE MATERIALIZED VIEW scout.mv_store_daily_metrics_new AS
SELECT ... FROM scout.silver_transactions_cleaned ...;
DROP MATERIALIZED VIEW scout.mv_store_daily_metrics;
ALTER MATERIALIZED VIEW scout.mv_store_daily_metrics_new 
  RENAME TO mv_store_daily_metrics;
COMMIT;

-- Automated refresh schedule
CREATE OR REPLACE FUNCTION refresh_materialized_views()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_daily_aggregates;
  REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_regional_performance;
  REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_customer_insights;
END;
$$ LANGUAGE plpgsql;

-- Schedule via pg_cron
SELECT cron.schedule('refresh-views', '0 */2 * * *', 
  'SELECT refresh_materialized_views();');
```

---

## **💾 Storage Optimization**

### **Table Partitioning**

```sql
-- Convert large tables to partitioned tables
-- 1. Create partitioned table
CREATE TABLE scout.silver_transactions_partitioned (
  LIKE scout.silver_transactions_cleaned INCLUDING ALL
) PARTITION BY RANGE (date_key);

-- 2. Create partitions
CREATE TABLE scout.silver_transactions_y2024m01 
  PARTITION OF scout.silver_transactions_partitioned
  FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE scout.silver_transactions_y2024m02 
  PARTITION OF scout.silver_transactions_partitioned
  FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- 3. Migrate data
INSERT INTO scout.silver_transactions_partitioned
SELECT * FROM scout.silver_transactions_cleaned;

-- 4. Swap tables
BEGIN;
ALTER TABLE scout.silver_transactions_cleaned RENAME TO silver_transactions_old;
ALTER TABLE scout.silver_transactions_partitioned RENAME TO silver_transactions_cleaned;
COMMIT;

-- 5. Auto-partition creation
CREATE OR REPLACE FUNCTION create_monthly_partition()
RETURNS void AS $$
DECLARE
  partition_date DATE;
  partition_name TEXT;
BEGIN
  partition_date := DATE_TRUNC('month', CURRENT_DATE + INTERVAL '1 month');
  partition_name := 'silver_transactions_y' || 
                    TO_CHAR(partition_date, 'YYYY') || 
                    'm' || TO_CHAR(partition_date, 'MM');
  
  EXECUTE format('CREATE TABLE IF NOT EXISTS scout.%I 
    PARTITION OF scout.silver_transactions_cleaned
    FOR VALUES FROM (%L) TO (%L)',
    partition_name,
    partition_date,
    partition_date + INTERVAL '1 month'
  );
END;
$$ LANGUAGE plpgsql;
```

### **Vacuum & Analyze**

```bash
#!/bin/bash
# save as vacuum_maintenance.sh

# Full VACUUM on weekends
if [ $(date +%u) -eq 6 ]; then
  psql $DATABASE_URL << EOF
  VACUUM FULL ANALYZE scout.bronze_transactions_raw;
  VACUUM FULL ANALYZE scout.silver_transactions_cleaned;
  REINDEX SCHEMA scout;
EOF
else
  # Regular VACUUM on weekdays
  psql $DATABASE_URL << EOF
  VACUUM ANALYZE scout.bronze_transactions_raw;
  VACUUM ANALYZE scout.silver_transactions_cleaned;
  VACUUM ANALYZE scout.gold_business_metrics;
EOF
fi

# Update table statistics
psql $DATABASE_URL -c "ANALYZE;"
```

---

## **🔧 Application-Level Optimization**

### **Connection Pooling**

```yaml
# pgbouncer configuration
[databases]
scout = host=db.supabase.co port=5432 dbname=postgres

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
min_pool_size = 10
reserve_pool_size = 5
reserve_pool_timeout = 5
max_db_connections = 100
```

### **Caching Strategy**

```typescript
// Redis caching layer
import Redis from 'ioredis';

const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: 6379,
  maxRetriesPerRequest: 3,
});

// Cache frequently accessed data
async function getCachedStoreMetrics(storeId: string) {
  const cacheKey = `metrics:store:${storeId}`;
  
  // Try cache first
  const cached = await redis.get(cacheKey);
  if (cached) return JSON.parse(cached);
  
  // Fetch from database
  const metrics = await db.query(`
    SELECT * FROM scout.gold_store_performance
    WHERE store_id = $1
  `, [storeId]);
  
  // Cache for 5 minutes
  await redis.setex(cacheKey, 300, JSON.stringify(metrics));
  
  return metrics;
}

// Implement cache warming
async function warmCache() {
  const stores = await db.query(`
    SELECT store_id FROM scout.dim_store
    WHERE is_active = true
  `);
  
  for (const store of stores) {
    await getCachedStoreMetrics(store.store_id);
  }
}

// Schedule cache warming
setInterval(warmCache, 5 * 60 * 1000); // Every 5 minutes
```

### **Query Result Caching**

```sql
-- Create query result cache table
CREATE TABLE scout.query_cache (
  cache_key VARCHAR(255) PRIMARY KEY,
  query_hash VARCHAR(64),
  result JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  hit_count INTEGER DEFAULT 0
);

-- Function to get cached results
CREATE OR REPLACE FUNCTION get_cached_query(
  p_query TEXT,
  p_ttl INTERVAL DEFAULT '5 minutes'
) RETURNS JSONB AS $$
DECLARE
  v_cache_key VARCHAR(255);
  v_result JSONB;
BEGIN
  v_cache_key := MD5(p_query);
  
  -- Check cache
  SELECT result INTO v_result
  FROM scout.query_cache
  WHERE cache_key = v_cache_key
    AND expires_at > NOW();
  
  IF FOUND THEN
    -- Update hit count
    UPDATE scout.query_cache 
    SET hit_count = hit_count + 1
    WHERE cache_key = v_cache_key;
    
    RETURN v_result;
  END IF;
  
  -- Execute query and cache
  EXECUTE p_query INTO v_result;
  
  INSERT INTO scout.query_cache (cache_key, query_hash, result, expires_at)
  VALUES (v_cache_key, MD5(p_query), v_result, NOW() + p_ttl)
  ON CONFLICT (cache_key) 
  DO UPDATE SET 
    result = EXCLUDED.result,
    expires_at = EXCLUDED.expires_at,
    created_at = NOW();
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql;
```

---

## **📈 Performance Monitoring Dashboard**

```sql
-- Create performance monitoring view
CREATE OR REPLACE VIEW scout.v_performance_metrics AS
WITH query_stats AS (
  SELECT 
    'slow_queries' as metric,
    COUNT(*) as value
  FROM pg_stat_statements
  WHERE mean_exec_time > 2000
),
cache_stats AS (
  SELECT 
    'cache_hit_ratio' as metric,
    ROUND(100.0 * sum(heap_blks_hit) / 
          NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0), 2) as value
  FROM pg_statio_user_tables
),
connection_stats AS (
  SELECT 
    'active_connections' as metric,
    COUNT(*) as value
  FROM pg_stat_activity
  WHERE state = 'active'
),
data_freshness AS (
  SELECT 
    'data_lag_minutes' as metric,
    EXTRACT(EPOCH FROM (NOW() - MAX(created_at)))/60 as value
  FROM scout.bronze_transactions_raw
)
SELECT * FROM query_stats
UNION ALL SELECT * FROM cache_stats
UNION ALL SELECT * FROM connection_stats
UNION ALL SELECT * FROM data_freshness;

-- Query to check all metrics
SELECT 
  metric,
  value,
  CASE 
    WHEN metric = 'slow_queries' AND value > 10 THEN '⚠️ HIGH'
    WHEN metric = 'cache_hit_ratio' AND value < 90 THEN '⚠️ LOW'
    WHEN metric = 'active_connections' AND value > 50 THEN '⚠️ HIGH'
    WHEN metric = 'data_lag_minutes' AND value > 60 THEN '⚠️ HIGH'
    ELSE '✅ OK'
  END as status
FROM scout.v_performance_metrics;
```

---

## **⚡ Quick Performance Wins**

| Action | Impact | Effort | Command |
|--------|--------|--------|---------|
| **Add missing indexes** | High | Low | `CREATE INDEX CONCURRENTLY ...` |
| **Update table statistics** | Medium | Low | `ANALYZE scout.table_name;` |
| **Increase work_mem** | Medium | Low | `SET work_mem = '256MB';` |
| **Enable parallel queries** | High | Low | `SET max_parallel_workers_per_gather = 4;` |
| **Vacuum bloated tables** | High | Medium | `VACUUM FULL table_name;` |
| **Refresh materialized views** | High | Low | `REFRESH MATERIALIZED VIEW CONCURRENTLY ...` |
| **Implement connection pooling** | High | Medium | Deploy pgbouncer |
| **Add Redis caching** | High | Medium | Deploy Redis cluster |

---

## **🚨 Emergency Performance Recovery**

```bash
#!/bin/bash
# save as emergency_performance_fix.sh

echo "🚨 Starting emergency performance recovery..."

# 1. Kill all long-running queries
psql $DATABASE_URL << EOF
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'active' 
  AND query_start < NOW() - INTERVAL '5 minutes'
  AND query NOT LIKE '%pg_stat_activity%';
EOF

# 2. Reset connections
psql $DATABASE_URL -c "SELECT pg_stat_reset();"

# 3. Emergency vacuum
psql $DATABASE_URL -c "VACUUM ANALYZE scout.silver_transactions_cleaned;"

# 4. Rebuild critical indexes
psql $DATABASE_URL << EOF
REINDEX INDEX CONCURRENTLY scout.idx_transactions_store_date;
REINDEX INDEX CONCURRENTLY scout.idx_transactions_region_date;
EOF

# 5. Clear query cache
psql $DATABASE_URL -c "TRUNCATE scout.query_cache;"

# 6. Restart connection pooler
kubectl rollout restart deployment/pgbouncer -n scout

echo "✅ Emergency recovery complete!"
```

---

## **📚 Related Documentation**

- [Incident Response](./incident-response.md)
- [Database Maintenance](../database/maintenance.md)
- [Monitoring Guide](../monitoring/guide.md)
- [Capacity Planning](../capacity/planning.md)

---

## **Version History**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-01-15 | Platform Team | Initial runbook |

---

*Update this runbook with new optimization techniques discovered during operations.*
