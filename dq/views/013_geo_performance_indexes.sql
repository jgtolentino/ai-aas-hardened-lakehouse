-- Performance optimization for geographic queries
-- GIST indexes for spatial operations

BEGIN;

-- =============================================================================
-- GIST Indexes for Spatial Columns
-- =============================================================================

-- Region boundaries (ADM1)
CREATE INDEX IF NOT EXISTS idx_geo_adm1_region_geom 
ON scout.geo_adm1_region USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_geo_adm1_region_gen_geom 
ON scout.geo_adm1_region_gen USING GIST (geom);

-- Province boundaries (ADM2)
CREATE INDEX IF NOT EXISTS idx_geo_adm2_province_geom 
ON scout.geo_adm2_province USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_geo_adm2_province_gen_geom 
ON scout.geo_adm2_province_gen USING GIST (geom);

-- City/Municipality boundaries (ADM3)
CREATE INDEX IF NOT EXISTS idx_geo_adm3_citymun_geom 
ON scout.geo_adm3_citymun USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_geo_adm3_citymun_gen_geom 
ON scout.geo_adm3_citymun_gen USING GIST (geom);

-- =============================================================================
-- B-tree Indexes for Lookup Columns
-- =============================================================================

-- PSGC code lookups
CREATE INDEX IF NOT EXISTS idx_geo_adm1_region_psgc 
ON scout.geo_adm1_region (region_psgc);

CREATE INDEX IF NOT EXISTS idx_geo_adm2_province_psgc 
ON scout.geo_adm2_province (province_psgc);

CREATE INDEX IF NOT EXISTS idx_geo_adm3_citymun_psgc 
ON scout.geo_adm3_citymun (citymun_psgc);

-- Name lookups (for normalization functions)
CREATE INDEX IF NOT EXISTS idx_geo_adm1_region_name 
ON scout.geo_adm1_region (UPPER(region_name));

CREATE INDEX IF NOT EXISTS idx_geo_adm2_province_name 
ON scout.geo_adm2_province (UPPER(province_name));

CREATE INDEX IF NOT EXISTS idx_geo_adm3_citymun_name 
ON scout.geo_adm3_citymun (UPPER(citymun_name));

-- Dimension table indexes
CREATE INDEX IF NOT EXISTS idx_dim_geo_region_aliases 
ON scout.dim_geo_region (region_key, unnest(aliases));

CREATE INDEX IF NOT EXISTS idx_dim_store_geo_psgc 
ON scout.dim_store (citymun_psgc, province_psgc);

-- =============================================================================
-- Partial Indexes for Common Filters
-- =============================================================================

-- Cities only (excluding municipalities)
CREATE INDEX IF NOT EXISTS idx_geo_adm3_cities_only 
ON scout.geo_adm3_citymun (citymun_psgc) 
WHERE citymun_name ILIKE '%city%';

-- High-income class areas
CREATE INDEX IF NOT EXISTS idx_dim_geo_citymun_income_high 
ON scout.dim_geo_citymun (citymun_psgc) 
WHERE income_class IN ('1st', '2nd', '3rd');

-- =============================================================================
-- Composite Indexes for Join Performance
-- =============================================================================

-- For spatial joins with transaction data
CREATE INDEX IF NOT EXISTS idx_gold_region_daily_composite 
ON scout.gold_region_daily (region_key, day DESC, peso_total DESC);

CREATE INDEX IF NOT EXISTS idx_gold_citymun_daily_composite 
ON scout.gold_citymun_daily (citymun_psgc, day DESC, peso_total DESC);

-- =============================================================================
-- Materialized View Indexes (if MVs are created)
-- =============================================================================

-- Note: If converting views to materialized views for performance
-- CREATE UNIQUE INDEX ON scout.mv_gold_region_choropleth (region_key, day);
-- CREATE INDEX ON scout.mv_gold_region_choropleth USING GIST (geom);

-- =============================================================================
-- Statistics for Query Planner
-- =============================================================================

-- Update statistics for spatial columns
ANALYZE scout.geo_adm1_region;
ANALYZE scout.geo_adm1_region_gen;
ANALYZE scout.geo_adm2_province;
ANALYZE scout.geo_adm2_province_gen;
ANALYZE scout.geo_adm3_citymun;
ANALYZE scout.geo_adm3_citymun_gen;

-- =============================================================================
-- Performance Monitoring Views
-- =============================================================================

-- View to monitor slow geographic queries
CREATE OR REPLACE VIEW scout.geo_query_performance AS
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    min_time,
    max_time,
    stddev_time
FROM pg_stat_statements
WHERE query ILIKE '%geo_%' 
   OR query ILIKE '%ST_%'
   OR query ILIKE '%geom%'
ORDER BY mean_time DESC
LIMIT 20;

-- View to check index usage
CREATE OR REPLACE VIEW scout.geo_index_usage AS
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'scout' 
  AND tablename LIKE 'geo_%'
ORDER BY idx_scan DESC;

-- =============================================================================
-- Query Hints and Configuration
-- =============================================================================

-- Ensure parallel queries are enabled for large spatial operations
ALTER TABLE scout.geo_adm1_region SET (parallel_workers = 4);
ALTER TABLE scout.geo_adm2_province SET (parallel_workers = 4);
ALTER TABLE scout.geo_adm3_citymun SET (parallel_workers = 4);

-- Set appropriate work_mem for spatial operations (session-level)
-- SET work_mem = '256MB';  -- Uncomment when running heavy spatial queries

COMMIT;