-- Choropleth Performance Testing Script
-- Run this after data is loaded to test and optimize performance

-- =============================================================================
-- Test 1: Region-level choropleth query performance
-- =============================================================================

\timing on

-- Warm up the cache
SELECT COUNT(*) FROM scout.gold_region_choropleth WHERE day >= CURRENT_DATE - INTERVAL '30 days';

-- Test typical dashboard query (last 30 days, all regions)
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT 
    region_key,
    region_name,
    ST_AsGeoJSON(geom) as geojson,
    SUM(peso_total) as total_sales,
    SUM(txn_count) as total_transactions,
    AVG(revenue_per_capita) as avg_revenue_per_capita
FROM scout.gold_region_choropleth
WHERE day >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY region_key, region_name, geom;

-- Test with date filter (specific week)
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    region_key,
    region_name,
    ST_AsGeoJSON(geom) as geojson,
    peso_total,
    txn_count,
    campaign_influenced_txns
FROM scout.gold_region_choropleth
WHERE day >= '2024-01-01' AND day < '2024-01-08'
ORDER BY peso_total DESC;

-- =============================================================================
-- Test 2: City/Municipality-level query performance
-- =============================================================================

-- Test without simplification
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    citymun_psgc,
    citymun_name,
    LENGTH(ST_AsGeoJSON(geom)) as geojson_size,
    COUNT(*) as days_with_data,
    SUM(peso_total) as total_sales
FROM scout.gold_citymun_choropleth
WHERE day >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY citymun_psgc, citymun_name, geom
LIMIT 100;

-- Test with region filter (more realistic query)
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    c.citymun_psgc,
    c.citymun_name,
    ST_AsGeoJSON(c.geom) as geojson,
    SUM(c.peso_total) as total_sales,
    SUM(c.txn_count) as total_transactions
FROM scout.gold_citymun_choropleth c
WHERE c.region_key = 'NCR'
  AND c.day >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY c.citymun_psgc, c.citymun_name, c.geom;

-- =============================================================================
-- Test 3: Spatial join performance
-- =============================================================================

-- Test point-in-polygon query (find region for a coordinate)
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    region_key,
    region_name
FROM scout.geo_adm1_region
WHERE ST_Contains(geom, ST_SetSRID(ST_MakePoint(121.0, 14.5), 4326));

-- Test intersection query (find overlapping areas)
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    a.region_key,
    COUNT(DISTINCT c.citymun_psgc) as city_count
FROM scout.geo_adm1_region a
JOIN scout.geo_adm3_citymun c ON ST_Intersects(a.geom, c.geom)
GROUP BY a.region_key;

-- =============================================================================
-- Test 4: GeoJSON generation performance
-- =============================================================================

-- Compare original vs simplified geometry
WITH geometry_comparison AS (
    SELECT 
        'Original' as type,
        region_key,
        LENGTH(ST_AsGeoJSON(geom)) as json_length,
        ST_NPoints(geom) as point_count
    FROM scout.geo_adm1_region
    UNION ALL
    SELECT 
        'Simplified' as type,
        region_key,
        LENGTH(ST_AsGeoJSON(geom)) as json_length,
        ST_NPoints(geom) as point_count
    FROM scout.geo_adm1_region_gen
)
SELECT 
    type,
    AVG(json_length) as avg_json_size,
    AVG(point_count) as avg_points,
    MAX(json_length) as max_json_size,
    MAX(point_count) as max_points
FROM geometry_comparison
GROUP BY type;

-- =============================================================================
-- Test 5: Index effectiveness
-- =============================================================================

-- Check if spatial indexes are being used
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM scout.geo_adm3_citymun a
JOIN scout.geo_adm3_citymun b 
ON ST_DWithin(a.geom, b.geom, 0.01)
WHERE a.citymun_psgc != b.citymun_psgc
LIMIT 10;

-- =============================================================================
-- Performance Recommendations
-- =============================================================================

-- Check table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) as indexes_size,
    n_live_tup as row_count
FROM pg_stat_user_tables
WHERE schemaname = 'scout' 
  AND tablename LIKE 'geo_%'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Check index usage statistics
SELECT 
    indexrelname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'scout'
  AND tablename LIKE 'geo_%'
ORDER BY idx_scan DESC;

-- =============================================================================
-- Optimization Queries (run if performance is poor)
-- =============================================================================

-- 1. Create materialized view for frequently accessed data
/*
CREATE MATERIALIZED VIEW scout.mv_region_choropleth_30d AS
SELECT 
    g.region_key,
    g.region_name,
    g.region_psgc,
    gen.geom,  -- Use simplified geometry
    SUM(m.txn_count) as txn_count,
    SUM(m.peso_total) as peso_total,
    AVG(m.avg_transaction_value) as avg_transaction_value,
    COUNT(DISTINCT m.day) as active_days
FROM scout.geo_adm1_region g
JOIN scout.geo_adm1_region_gen gen ON g.region_key = gen.region_key
LEFT JOIN scout.gold_region_daily m ON g.region_key = m.region_key
WHERE m.day >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY g.region_key, g.region_name, g.region_psgc, gen.geom;

CREATE UNIQUE INDEX ON scout.mv_region_choropleth_30d (region_key);
CREATE INDEX ON scout.mv_region_choropleth_30d USING GIST (geom);
*/

-- 2. Cluster tables by frequently used indexes
/*
CLUSTER scout.geo_adm1_region USING idx_geo_adm1_region_geom;
CLUSTER scout.gold_region_daily USING idx_gold_region_daily_composite;
*/

-- 3. Increase work_mem for spatial operations
/*
ALTER DATABASE scout_analytics SET work_mem = '256MB';
ALTER DATABASE scout_analytics SET maintenance_work_mem = '512MB';
*/

\timing off

-- Summary
SELECT 'Performance test complete. Review EXPLAIN ANALYZE output above for optimization opportunities.' as status;