# Choropleth Performance Optimization Guide

This guide provides strategies for optimizing choropleth map performance in Scout Analytics.

## Performance Testing

### 1. Run the SQL Performance Test

```bash
psql -h localhost -U scout_viewer -d scout_analytics -f scripts/test_choropleth_performance.sql
```

This tests:
- Region-level queries (17 regions)
- City/municipality queries (1,600+ areas)
- Spatial join performance
- GeoJSON generation speed

### 2. Run the Python Benchmark

```bash
pip install psycopg2 pandas matplotlib seaborn

python scripts/benchmark_choropleth.py \
  --host localhost \
  --database scout_analytics \
  --user scout_viewer \
  --password viewer_pass \
  --output-dir ./benchmark_results
```

This provides:
- Execution time analysis
- Cache hit ratios
- Data size metrics
- Performance recommendations

## Common Performance Issues and Solutions

### Issue 1: Slow Initial Map Load

**Symptoms:**
- Map takes 5+ seconds to load
- Large GeoJSON payload (>10MB)

**Solutions:**

1. **Use Simplified Geometries**
   ```sql
   -- Already implemented in our setup
   SELECT * FROM scout.geo_adm1_region_gen;  -- Simplified version
   ```

2. **Implement Clustering for Dense Areas**
   ```python
   # In Superset chart config
   params:
     cluster: true
     cluster_max_zoom: 14
     cluster_radius: 50
   ```

3. **Enable Compression**
   ```nginx
   # In nginx/Apache config
   gzip on;
   gzip_types application/json application/geo+json;
   ```

### Issue 2: Slow Aggregation Queries

**Symptoms:**
- Queries with GROUP BY take 3+ seconds
- High CPU usage during aggregation

**Solutions:**

1. **Create Materialized Views**
   ```sql
   -- For frequently accessed date ranges
   CREATE MATERIALIZED VIEW scout.mv_region_choropleth_current AS
   SELECT * FROM scout.gold_region_choropleth 
   WHERE day >= CURRENT_DATE - INTERVAL '30 days';
   
   CREATE UNIQUE INDEX ON scout.mv_region_choropleth_current (region_key, day);
   CREATE INDEX ON scout.mv_region_choropleth_current USING GIST (geom);
   
   -- Refresh daily
   CREATE OR REPLACE FUNCTION scout.refresh_choropleth_mvs()
   RETURNS void AS $$
   BEGIN
     REFRESH MATERIALIZED VIEW CONCURRENTLY scout.mv_region_choropleth_current;
   END;
   $$ LANGUAGE plpgsql;
   ```

2. **Pre-aggregate Common Time Periods**
   ```sql
   -- Weekly and monthly views already created
   SELECT * FROM scout.gold_region_weekly;
   SELECT * FROM scout.gold_region_monthly;
   ```

### Issue 3: Memory Issues with Large Geometries

**Symptoms:**
- Out of memory errors
- Browser crashes on city-level maps

**Solutions:**

1. **Implement Viewport-Based Loading**
   ```javascript
   // In Superset custom JS
   const visibleFeatures = features.filter(f => 
     viewport.contains(f.geometry.coordinates)
   );
   ```

2. **Use Tile-Based Approach**
   ```sql
   -- Create spatial index with smaller grid
   CREATE INDEX idx_geo_citymun_spatial_grid 
   ON scout.geo_adm3_citymun 
   USING GIST (geom) 
   WITH (fillfactor = 100);
   ```

3. **Limit Features by Zoom Level**
   ```python
   # In chart configuration
   js_data_mutator: |
     // Show cities only when zoomed in
     if (viewport.zoom < 8) {
       data = data.filter(d => d.is_city === true);
     }
     return data;
   ```

### Issue 4: Slow Spatial Joins

**Symptoms:**
- Point-in-polygon queries take >1 second
- Store location queries are slow

**Solutions:**

1. **Ensure GIST Indexes Exist**
   ```sql
   -- Check indexes
   SELECT indexname, pg_size_pretty(pg_relation_size(indexrelid))
   FROM pg_stat_user_indexes
   WHERE tablename LIKE 'geo_%' AND indexname LIKE '%geom%';
   ```

2. **Use Bounding Box Pre-filters**
   ```sql
   -- Add bbox check before expensive operations
   SELECT * FROM scout.geo_adm3_citymun
   WHERE geom && ST_MakeEnvelope(120, 14, 122, 16, 4326)  -- Bbox first
     AND ST_Contains(geom, ST_Point(121, 15));           -- Then exact
   ```

## Database Tuning

### PostgreSQL Configuration

Add to `postgresql.conf`:

```ini
# Increase memory for spatial operations
shared_buffers = 2GB
work_mem = 256MB
maintenance_work_mem = 512MB

# Enable parallel queries
max_parallel_workers_per_gather = 4
max_parallel_workers = 8

# Optimize for SSDs
random_page_cost = 1.1
effective_cache_size = 6GB
```

### PostGIS Specific Settings

```sql
-- Set PostGIS-specific parameters
ALTER DATABASE scout_analytics SET postgis.gdal_enabled_drivers = 'ENABLE_ALL';
ALTER DATABASE scout_analytics SET postgis.enable_outdb_rasters = true;
```

## Monitoring Performance

### 1. Enable Query Logging

```sql
-- Log slow spatial queries
ALTER DATABASE scout_analytics SET log_min_duration_statement = '1000';  -- 1 second
```

### 2. Monitor with pg_stat_statements

```sql
-- Find slow geographic queries
SELECT 
    query,
    calls,
    mean_time,
    total_time
FROM pg_stat_statements
WHERE query ILIKE '%ST_%' OR query ILIKE '%geom%'
ORDER BY mean_time DESC
LIMIT 20;
```

### 3. Check Table Bloat

```sql
-- Monitor table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
    n_dead_tup,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE tablename LIKE 'geo_%'
ORDER BY n_dead_tup DESC;
```

## Superset-Specific Optimizations

### 1. Enable Query Result Caching

```python
# In superset_config.py
CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 300,  # 5 minutes
    'CACHE_KEY_PREFIX': 'superset_results',
    'CACHE_REDIS_URL': 'redis://localhost:6379/1'
}

# Cache choropleth queries longer
DATA_CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 3600,  # 1 hour for geo data
    'CACHE_KEY_PREFIX': 'superset_data',
    'CACHE_REDIS_URL': 'redis://localhost:6379/2'
}
```

### 2. Optimize Chart Rendering

```yaml
# In chart configuration
params:
  # Limit features rendered
  row_limit: 5000
  
  # Enable client-side filtering
  js_columns:
    - region_key
    - peso_total
    - txn_count
  
  # Simplify rendering
  filled: true
  stroked: false  # Disable strokes for better performance
  extruded: false
  
  # Reduce line width
  line_width: 1
  line_width_unit: "pixels"
```

### 3. Use Asynchronous Query Execution

```python
# Enable async queries for large datasets
FEATURE_FLAGS = {
    'ENABLE_ASYNC_QUERIES': True,
    'GLOBAL_ASYNC_QUERIES': True,
}
```

## Best Practices

1. **Always Test with Production-Scale Data**
   - Use the benchmark scripts with real data volumes
   - Test with concurrent users

2. **Monitor Continuously**
   - Set up alerts for slow queries
   - Track GeoJSON payload sizes
   - Monitor browser memory usage

3. **Optimize Incrementally**
   - Start with simplified geometries
   - Add detail only where needed
   - Use zoom-based level of detail

4. **Cache Aggressively**
   - Cache computed GeoJSON
   - Cache aggregated metrics
   - Use CDN for static map tiles

5. **Consider Alternatives for Dense Data**
   - Use heatmaps instead of choropleths for >1000 features
   - Implement marker clustering for point data
   - Use hexbins for density visualization

## Troubleshooting Checklist

- [ ] GIST indexes created on all geometry columns
- [ ] Using simplified geometries from `_gen` tables
- [ ] Superset cache configured and running
- [ ] PostgreSQL work_mem increased for spatial ops
- [ ] Browser console checked for client-side errors
- [ ] Network tab checked for payload sizes
- [ ] Zoom-based filtering implemented
- [ ] Materialized views created for common queries
- [ ] Regular VACUUM ANALYZE scheduled
- [ ] Query monitoring enabled