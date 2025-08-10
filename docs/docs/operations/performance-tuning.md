# Performance Tuning Guide

## 🚀 Query Optimization

### Identify Slow Queries
```sql
-- Top 10 slowest queries
SELECT 
  query,
  mean_exec_time,
  calls,
  total_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Queries with missing indexes
SELECT 
  schemaname,
  tablename,
  attname,
  n_distinct,
  most_common_vals
FROM pg_stats
WHERE schemaname = 'scout'
  AND n_distinct > 100
  AND NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = pg_stats.schemaname
      AND tablename = pg_stats.tablename
      AND indexdef LIKE '%' || attname || '%'
  );
```

### Index Creation
```sql
-- Transaction performance
CREATE INDEX CONCURRENTLY idx_silver_transactions_store_date 
ON scout.silver_transactions(store_id, date_key);

-- Geographic queries
CREATE INDEX CONCURRENTLY idx_stores_geography 
ON scout.dim_store USING GIST(geography);

-- Time-series optimization
CREATE INDEX CONCURRENTLY idx_transactions_ts_brin 
ON scout.silver_transactions USING BRIN(ts);
```

## 📊 Database Tuning

### PostgreSQL Configuration
```sql
-- Recommended settings for 16GB RAM
ALTER SYSTEM SET shared_buffers = '4GB';
ALTER SYSTEM SET effective_cache_size = '12GB';
ALTER SYSTEM SET maintenance_work_mem = '1GB';
ALTER SYSTEM SET work_mem = '32MB';
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET checkpoint_completion_target = 0.9;

-- Apply changes
SELECT pg_reload_conf();
```

### Connection Pooling
```yaml
# PgBouncer configuration
[databases]
scout = host=localhost port=5432 dbname=scout

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
min_pool_size = 10
reserve_pool_size = 5
reserve_pool_timeout = 3
max_db_connections = 100
```

## ⚡ Caching Strategy

### Materialized Views
```sql
-- Daily aggregations
CREATE MATERIALIZED VIEW scout.mv_daily_revenue AS
SELECT 
  date_key,
  store_id,
  SUM(total_amount) as revenue,
  COUNT(*) as transaction_count
FROM scout.silver_transactions
GROUP BY date_key, store_id;

-- Refresh strategy
CREATE OR REPLACE FUNCTION refresh_materialized_views()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY scout.mv_daily_revenue;
  REFRESH MATERIALIZED VIEW CONCURRENTLY scout.mv_product_performance;
END;
$$ LANGUAGE plpgsql;

-- Schedule refresh
SELECT cron.schedule('refresh-mvs', '0 1 * * *', 'SELECT refresh_materialized_views()');
```

### Redis Caching
```python
# Cache configuration
CACHE_CONFIG = {
    'dashboard_kpis': 300,      # 5 minutes
    'choropleth_data': 3600,    # 1 hour
    'product_rankings': 1800,   # 30 minutes
    'user_segments': 86400      # 24 hours
}

# Cache key patterns
def get_cache_key(metric, filters):
    return f"scout:{metric}:{hash(json.dumps(filters, sort_keys=True))}"
```

## 🔍 Monitoring

### Key Metrics
```bash
# Database connections
watch -n 5 "psql $PGURI -c 'SELECT state, COUNT(*) FROM pg_stat_activity GROUP BY state;'"

# Cache hit ratio
psql $PGURI -c "SELECT sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) as cache_hit_ratio FROM pg_statio_user_tables;"

# Table bloat
psql $PGURI -c "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size FROM pg_tables WHERE schemaname = 'scout' ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;"
```

### Performance Dashboard
- CPU usage < 70%
- Memory usage < 80%
- Disk I/O < 1000 IOPS
- Query response time < 200ms
- Cache hit ratio > 95%
