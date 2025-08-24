-- ============================================================
-- SCOUT v5.2 DEPLOYMENT VALIDATION
-- Checks current state and what needs alignment
-- ============================================================

SET search_path TO scout, public;

-- ============================================================
-- CHECK EXISTING TABLES
-- ============================================================

WITH table_check AS (
    SELECT 
        schemaname,
        tablename,
        CASE 
            WHEN tablename LIKE 'fact_%' THEN 'FACT'
            WHEN tablename LIKE 'dim_%' THEN 'DIMENSION'
            WHEN tablename LIKE 'ref_%' THEN 'REFERENCE'
            WHEN tablename LIKE 'master_%' THEN 'MASTER'
            WHEN tablename LIKE 'bronze_%' THEN 'BRONZE'
            WHEN tablename LIKE 'silver_%' THEN 'SILVER'
            WHEN tablename LIKE 'gold_%' THEN 'GOLD'
            WHEN tablename LIKE 'platinum_%' THEN 'PLATINUM'
            WHEN tablename LIKE 'edge_%' THEN 'EDGE'
            WHEN tablename LIKE 'stt_%' THEN 'STT'
            WHEN tablename LIKE 'etl_%' THEN 'ETL'
            ELSE 'OTHER'
        END as table_type,
        obj_description((schemaname||'.'||tablename)::regclass, 'pg_class') as description
    FROM pg_tables
    WHERE schemaname = 'scout'
    ORDER BY table_type, tablename
)
SELECT 
    '📊 TABLE INVENTORY' as section,
    COUNT(*) as total_tables,
    COUNT(*) FILTER (WHERE table_type = 'FACT') as fact_tables,
    COUNT(*) FILTER (WHERE table_type = 'DIMENSION') as dimension_tables,
    COUNT(*) FILTER (WHERE table_type = 'REFERENCE') as reference_tables,
    COUNT(*) FILTER (WHERE table_type = 'MASTER') as master_tables,
    COUNT(*) FILTER (WHERE table_type = 'BRONZE') as bronze_tables,
    COUNT(*) FILTER (WHERE table_type = 'SILVER') as silver_tables,
    COUNT(*) FILTER (WHERE table_type = 'GOLD') as gold_tables,
    COUNT(*) FILTER (WHERE table_type = 'PLATINUM') as platinum_tables,
    COUNT(*) FILTER (WHERE table_type = 'EDGE') as edge_tables,
    COUNT(*) FILTER (WHERE table_type = 'STT') as stt_tables,
    COUNT(*) FILTER (WHERE table_type = 'ETL') as etl_tables
FROM table_check;

-- ============================================================
-- CHECK EXPECTED VS ACTUAL TABLES
-- ============================================================

WITH expected_tables AS (
    SELECT unnest(ARRAY[
        -- Fact tables
        'fact_transactions',
        'fact_transaction_items',
        'fact_daily_sales',
        -- Dimensions
        'dim_date',
        'dim_time',
        'dim_stores', 'dim_store',
        'dim_products', 'dim_product', 'dim_sku',
        'dim_customers', 'dim_customer',
        -- Master/Reference
        'ref_brands', 'master_brands',
        'ref_categories', 'master_categories',
        'master_products',
        -- Bronze
        'bronze_transactions_raw', 'bronze_transactions',
        'bronze_events',
        'bronze_inventory',
        -- Silver
        'silver_transactions',
        'silver_inventory',
        -- Gold
        'gold_fact_transactions_enhanced',
        -- Platinum
        'platinum_substitution_patterns',
        'platinum_demand_forecast',
        -- Edge
        'edge_devices',
        'edge_health',
        'edge_installation_checks',
        -- STT
        'stt_brand_dictionary',
        'stt_detections',
        -- ETL
        'etl_queue',
        'etl_pipeline_status'
    ]) as table_name
),
actual_tables AS (
    SELECT tablename as table_name
    FROM pg_tables
    WHERE schemaname = 'scout'
)
SELECT 
    '✅ EXISTING' as status,
    string_agg(a.table_name, ', ' ORDER BY a.table_name) as tables
FROM actual_tables a
JOIN expected_tables e ON a.table_name = e.table_name

UNION ALL

SELECT 
    '❌ MISSING' as status,
    string_agg(e.table_name, ', ' ORDER BY e.table_name) as tables
FROM expected_tables e
LEFT JOIN actual_tables a ON e.table_name = a.table_name
WHERE a.table_name IS NULL

UNION ALL

SELECT 
    '➕ EXTRA' as status,
    string_agg(a.table_name, ', ' ORDER BY a.table_name) as tables
FROM actual_tables a
LEFT JOIN expected_tables e ON a.table_name = e.table_name
WHERE e.table_name IS NULL;

-- ============================================================
-- CHECK KEY RPC FUNCTIONS
-- ============================================================

SELECT 
    '📡 RPC FUNCTIONS' as section,
    COUNT(*) as total_functions,
    string_agg(proname, ', ' ORDER BY proname) as function_names
FROM pg_proc
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'scout')
AND proname IN (
    'get_dashboard_kpis',
    'get_sales_trend',
    'get_store_performance',
    'get_brand_analysis',
    'run_pre_installation_check',
    'run_post_installation_check',
    'get_installation_dashboard',
    'get_connectivity_dashboard',
    'check_connectivity_health'
);

-- ============================================================
-- CHECK VIEWS
-- ============================================================

SELECT 
    '👁️ VIEWS' as section,
    COUNT(*) as total_views,
    COUNT(*) FILTER (WHERE viewname LIKE 'v_dashboard_%') as dashboard_views,
    COUNT(*) FILTER (WHERE viewname LIKE 'v_gold_%') as gold_views,
    COUNT(*) FILTER (WHERE viewname LIKE 'v_analytics_%') as analytics_views
FROM pg_views
WHERE schemaname = 'scout';

-- ============================================================
-- CHECK DATA POPULATION
-- ============================================================

WITH data_counts AS (
    SELECT 'ref_brands' as table_name, COUNT(*) as row_count FROM scout.ref_brands
    UNION ALL
    SELECT 'ref_categories', COUNT(*) FROM scout.ref_categories
    UNION ALL
    SELECT 'dim_sku', COUNT(*) FROM scout.dim_sku
    UNION ALL
    SELECT 'dim_store', COUNT(*) FROM scout.dim_store
    UNION ALL
    SELECT 'edge_devices', COUNT(*) FROM scout.edge_devices WHERE 1=1
    UNION ALL
    SELECT 'edge_health', COUNT(*) FROM scout.edge_health WHERE 1=1
    UNION ALL
    SELECT 'silver_transactions', COUNT(*) FROM scout.silver_transactions WHERE 1=1
)
SELECT 
    '📊 DATA POPULATION' as section,
    table_name,
    row_count,
    CASE 
        WHEN row_count = 0 THEN '⚠️ Empty'
        WHEN row_count < 10 THEN '⚠️ Low data'
        ELSE '✅ Populated'
    END as status
FROM data_counts
ORDER BY row_count DESC;

-- ============================================================
-- CHECK NAMING COMPATIBILITY
-- ============================================================

SELECT 
    '🔄 NAMING COMPATIBILITY' as section,
    'Dimension Tables' as category,
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'scout' AND tablename = 'dim_store')
         AND EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'scout' AND tablename = 'dim_stores')
        THEN '✅ Both singular and plural exist'
        WHEN EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'scout' AND tablename = 'dim_store')
        THEN '⚠️ Only singular exists (dim_store)'
        WHEN EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'scout' AND tablename = 'dim_stores')
        THEN '⚠️ Only plural exists (dim_stores)'
        ELSE '❌ Neither exists'
    END as status;

-- ============================================================
-- PATCH IMPACT SUMMARY
-- ============================================================

SELECT 
    '🔧 PATCH WILL ADD' as section,
    'fact_transactions, fact_transaction_items, fact_daily_sales' as fact_tables,
    'dim_date, dim_time' as new_dimensions,
    'bronze_events, bronze_inventory, silver_inventory' as data_layers,
    'stt_brand_dictionary, stt_detections' as stt_tables,
    'platinum_substitution_patterns, platinum_demand_forecast' as predictive_tables,
    'etl_pipeline_status' as etl_tracking,
    'Compatibility views for naming differences' as views,
    'get_dashboard_kpis(), get_sales_trend() RPCs' as functions;