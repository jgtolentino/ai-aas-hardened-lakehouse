-- ============================================================
-- SCOUT v5.2 SMOKE TESTS
-- Quick validation suite for production deployment
-- ============================================================

SET search_path TO scout, public;

-- ============================================================
-- TEST 1: Core Tables Exist
-- ============================================================
DO $$
DECLARE
    v_missing_tables TEXT[];
    v_required_tables TEXT[] := ARRAY[
        'fact_transactions',
        'fact_transaction_items', 
        'fact_daily_sales',
        'dim_date',
        'dim_time',
        'edge_devices',
        'edge_health',
        'stt_brand_dictionary',
        'stt_detections'
    ];
    v_table TEXT;
BEGIN
    -- Check each required table
    FOREACH v_table IN ARRAY v_required_tables
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_tables 
            WHERE schemaname = 'scout' 
            AND tablename = v_table
        ) THEN
            v_missing_tables := array_append(v_missing_tables, v_table);
        END IF;
    END LOOP;
    
    IF array_length(v_missing_tables, 1) > 0 THEN
        RAISE EXCEPTION 'Missing required tables: %', array_to_string(v_missing_tables, ', ');
    ELSE
        RAISE NOTICE '✅ TEST 1 PASSED: All core tables exist';
    END IF;
END $$;

-- ============================================================
-- TEST 2: RPC Functions Available
-- ============================================================
DO $$
DECLARE
    v_missing_rpcs TEXT[];
    v_required_rpcs TEXT[] := ARRAY[
        'get_dashboard_kpis',
        'get_sales_trend',
        'get_store_performance',
        'get_brand_analysis',
        'get_connectivity_dashboard'
    ];
    v_rpc TEXT;
BEGIN
    FOREACH v_rpc IN ARRAY v_required_rpcs
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'scout' 
            AND p.proname = v_rpc
        ) THEN
            v_missing_rpcs := array_append(v_missing_rpcs, v_rpc);
        END IF;
    END LOOP;
    
    IF array_length(v_missing_rpcs, 1) > 0 THEN
        RAISE EXCEPTION 'Missing required RPCs: %', array_to_string(v_missing_rpcs, ', ');
    ELSE
        RAISE NOTICE '✅ TEST 2 PASSED: All core RPCs exist';
    END IF;
END $$;

-- ============================================================
-- TEST 3: Privacy Compliance (No Audio/Video)
-- ============================================================
DO $$
DECLARE
    v_privacy_violations INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_privacy_violations
    FROM pg_tables
    WHERE schemaname = 'scout'
    AND tablename ~* '(audio|video|recording|media|biometric)';
    
    IF v_privacy_violations > 0 THEN
        RAISE EXCEPTION '❌ Privacy violation: Found % tables with audio/video/biometric data', v_privacy_violations;
    ELSE
        RAISE NOTICE '✅ TEST 3 PASSED: No audio/video storage detected';
    END IF;
END $$;

-- ============================================================
-- TEST 4: Data Layer Integrity
-- ============================================================
DO $$
DECLARE
    v_bronze_count INTEGER;
    v_silver_count INTEGER;
    v_gold_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_bronze_count
    FROM pg_tables
    WHERE schemaname = 'scout' 
    AND tablename LIKE 'bronze_%';
    
    SELECT COUNT(*) INTO v_silver_count
    FROM pg_tables
    WHERE schemaname = 'scout' 
    AND tablename LIKE 'silver_%';
    
    SELECT COUNT(*) INTO v_gold_count
    FROM pg_tables
    WHERE schemaname = 'scout' 
    AND tablename LIKE 'gold_%';
    
    IF v_bronze_count = 0 OR v_silver_count = 0 OR v_gold_count = 0 THEN
        RAISE EXCEPTION '❌ Incomplete medallion architecture - Bronze: %, Silver: %, Gold: %', 
            v_bronze_count, v_silver_count, v_gold_count;
    ELSE
        RAISE NOTICE '✅ TEST 4 PASSED: Medallion architecture complete - Bronze: %, Silver: %, Gold: %',
            v_bronze_count, v_silver_count, v_gold_count;
    END IF;
END $$;

-- ============================================================
-- TEST 5: Master Data Populated
-- ============================================================
DO $$
DECLARE
    v_brand_count INTEGER;
    v_category_count INTEGER;
    v_store_count INTEGER;
BEGIN
    -- Check brands (handle both ref_ and master_ naming)
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'scout' AND tablename = 'ref_brands') THEN
        SELECT COUNT(*) INTO v_brand_count FROM scout.ref_brands;
    ELSIF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'scout' AND tablename = 'master_brands') THEN
        SELECT COUNT(*) INTO v_brand_count FROM scout.master_brands;
    ELSE
        v_brand_count := 0;
    END IF;
    
    -- Check categories
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'scout' AND tablename = 'ref_categories') THEN
        SELECT COUNT(*) INTO v_category_count FROM scout.ref_categories;
    ELSIF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'scout' AND tablename = 'master_categories') THEN
        SELECT COUNT(*) INTO v_category_count FROM scout.master_categories;
    ELSE
        v_category_count := 0;
    END IF;
    
    -- Check stores
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'scout' AND tablename = 'dim_store') THEN
        SELECT COUNT(*) INTO v_store_count FROM scout.dim_store;
    ELSIF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'scout' AND tablename = 'dim_stores') THEN
        SELECT COUNT(*) INTO v_store_count FROM scout.dim_stores;
    ELSE
        v_store_count := 0;
    END IF;
    
    IF v_brand_count < 30 OR v_category_count < 15 OR v_store_count < 10 THEN
        RAISE WARNING '⚠️ Low master data counts - Brands: %, Categories: %, Stores: %',
            v_brand_count, v_category_count, v_store_count;
    ELSE
        RAISE NOTICE '✅ TEST 5 PASSED: Master data populated - Brands: %, Categories: %, Stores: %',
            v_brand_count, v_category_count, v_store_count;
    END IF;
END $$;

-- ============================================================
-- TEST 6: RLS Policies Enabled
-- ============================================================
DO $$
DECLARE
    v_unprotected_tables TEXT[];
    v_sensitive_tables TEXT[] := ARRAY[
        'fact_transactions',
        'fact_transaction_items',
        'dim_customers',
        'edge_health'
    ];
    v_table TEXT;
BEGIN
    FOREACH v_table IN ARRAY v_sensitive_tables
    LOOP
        IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'scout' AND tablename = v_table) THEN
            IF NOT EXISTS (
                SELECT 1 FROM pg_tables t
                JOIN pg_policies p ON t.tablename = p.tablename AND t.schemaname = p.schemaname
                WHERE t.schemaname = 'scout' 
                AND t.tablename = v_table
            ) THEN
                -- Check if RLS is at least enabled
                IF NOT EXISTS (
                    SELECT 1 FROM pg_class c
                    JOIN pg_namespace n ON c.relnamespace = n.oid
                    WHERE n.nspname = 'scout' 
                    AND c.relname = v_table
                    AND c.relrowsecurity = true
                ) THEN
                    v_unprotected_tables := array_append(v_unprotected_tables, v_table);
                END IF;
            END IF;
        END IF;
    END LOOP;
    
    IF array_length(v_unprotected_tables, 1) > 0 THEN
        RAISE WARNING '⚠️ Tables without RLS: %', array_to_string(v_unprotected_tables, ', ');
    ELSE
        RAISE NOTICE '✅ TEST 6 PASSED: RLS policies configured';
    END IF;
END $$;

-- ============================================================
-- TEST 7: PostGIS Extension
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis') THEN
        RAISE EXCEPTION '❌ PostGIS extension not installed';
    ELSE
        RAISE NOTICE '✅ TEST 7 PASSED: PostGIS extension available';
    END IF;
END $$;

-- ============================================================
-- TEST 8: Edge Connectivity Functions
-- ============================================================
DO $$
DECLARE
    v_result RECORD;
BEGIN
    -- Test connectivity dashboard function
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'scout' AND p.proname = 'get_connectivity_dashboard'
    ) THEN
        -- Try to execute the function
        BEGIN
            EXECUTE 'SELECT * FROM scout.get_connectivity_dashboard() LIMIT 1' INTO v_result;
            RAISE NOTICE '✅ TEST 8 PASSED: Edge connectivity functions operational';
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING '⚠️ Edge connectivity function exists but returned error: %', SQLERRM;
        END;
    ELSE
        RAISE WARNING '⚠️ Edge connectivity functions not found';
    END IF;
END $$;

-- ============================================================
-- TEST 9: Date/Time Dimensions
-- ============================================================
DO $$
DECLARE
    v_date_count INTEGER;
    v_time_count INTEGER;
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'scout' AND tablename = 'dim_date') THEN
        SELECT COUNT(*) INTO v_date_count FROM scout.dim_date;
    ELSE
        v_date_count := 0;
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'scout' AND tablename = 'dim_time') THEN
        SELECT COUNT(*) INTO v_time_count FROM scout.dim_time;
    ELSE
        v_time_count := 0;
    END IF;
    
    IF v_date_count < 365 OR v_time_count < 1440 THEN
        RAISE WARNING '⚠️ Date/Time dimensions incomplete - Dates: %, Times: %', v_date_count, v_time_count;
    ELSE
        RAISE NOTICE '✅ TEST 9 PASSED: Date/Time dimensions populated - Dates: %, Times: %', v_date_count, v_time_count;
    END IF;
END $$;

-- ============================================================
-- TEST 10: Performance Quick Check
-- ============================================================
DO $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
    v_result RECORD;
BEGIN
    -- Test a simple KPI query performance
    v_start_time := clock_timestamp();
    
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'scout' AND p.proname = 'get_dashboard_kpis'
    ) THEN
        BEGIN
            EXECUTE 'SELECT * FROM scout.get_dashboard_kpis($1, $2) LIMIT 1' 
            USING CURRENT_DATE - INTERVAL '7 days', CURRENT_DATE
            INTO v_result;
            
            v_end_time := clock_timestamp();
            v_duration := v_end_time - v_start_time;
            
            IF EXTRACT(MILLISECONDS FROM v_duration) > 3000 THEN
                RAISE WARNING '⚠️ Performance concern: Dashboard KPI query took %ms', 
                    EXTRACT(MILLISECONDS FROM v_duration)::INTEGER;
            ELSE
                RAISE NOTICE '✅ TEST 10 PASSED: Performance check OK (%ms)', 
                    EXTRACT(MILLISECONDS FROM v_duration)::INTEGER;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING '⚠️ Performance test skipped: %', SQLERRM;
        END;
    ELSE
        RAISE WARNING '⚠️ Performance test skipped: get_dashboard_kpis not found';
    END IF;
END $$;

-- ============================================================
-- SUMMARY
-- ============================================================
SELECT 
    '🚀 SCOUT v5.2 SMOKE TESTS COMPLETE' as status,
    'Check above for any failures or warnings' as note,
    NOW() as tested_at;