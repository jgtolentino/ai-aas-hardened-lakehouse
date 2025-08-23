-- Scout v3 Schema Verification Script
-- Counts tables and views to verify v3 deployment

-- Count tables by schema
SELECT 
    'Schema Table Counts' as report_type,
    table_schema,
    COUNT(*) as table_count
FROM information_schema.tables
WHERE table_type = 'BASE TABLE'
    AND table_schema IN (
        'scout', 'bronze', 'silver', 'gold', 
        'master_data', 'staging', 'deep_research',
        'masterdata', 'analytics'
    )
GROUP BY table_schema
ORDER BY table_schema;

-- Count views by schema
SELECT 
    'Schema View Counts' as report_type,
    table_schema,
    COUNT(*) as view_count
FROM information_schema.tables
WHERE table_type = 'VIEW'
    AND table_schema IN (
        'scout', 'bronze', 'silver', 'gold', 
        'master_data', 'analytics'
    )
GROUP BY table_schema
ORDER BY table_schema;

-- Total summary
SELECT 
    'Total Database Objects' as report_type,
    COUNT(CASE WHEN table_type = 'BASE TABLE' THEN 1 END) as total_tables,
    COUNT(CASE WHEN table_type = 'VIEW' THEN 1 END) as total_views,
    COUNT(*) as total_objects
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog', 'information_schema', 'pgbouncer', 'realtime', 'pgsodium', 'pgsodium_masks', 'graphql', 'graphql_public');

-- Check for v3 specific tables
SELECT 
    'V3 Feature Tables' as report_type,
    EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'stt_brand_requests') as has_stt,
    EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'scraping_queue') as has_scraping,
    EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema IN ('master_data', 'masterdata') AND table_name = 'brands') as has_brands,
    EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'psgc_regions') as has_psgc;