-- ============================================================
-- SEED LOADER SYSTEM - Load data from Supabase Storage buckets
-- Uses HTTP extension to pull CSV data from public storage
-- ============================================================

-- Enable HTTP extension for loading data from storage
CREATE EXTENSION IF NOT EXISTS "http";

-- Create seed data loader function
CREATE OR REPLACE FUNCTION scout.fn_load_seed_data()
RETURNS TEXT
LANGUAGE plpgsql
AS $function$
DECLARE
    v_project_ref TEXT := 'cxzllzyxwpyptfretryc';
    v_base_url TEXT;
    v_response http_response_result;
    v_csv_content TEXT;
    v_row_count INTEGER;
    v_total_loaded INTEGER := 0;
    v_result TEXT := '';
BEGIN
    -- Construct base URL for storage bucket
    v_base_url := 'https://' || v_project_ref || '.supabase.co/storage/v1/object/public/seed-data/';
    
    v_result := v_result || E'🌱 SCOUT SEED DATA LOADER\n';
    v_result := v_result || E'================================\n\n';
    
    -- 1) Load reference sources
    BEGIN
        v_response := http_get(v_base_url || 'ref_sources.csv');
        IF v_response.status = 200 THEN
            -- Create temporary table for CSV import
            CREATE TEMP TABLE temp_sources (LIKE scout.ref_sources) ON COMMIT DROP;
            
            -- Parse CSV and insert (skipping header)
            INSERT INTO temp_sources 
            SELECT * FROM csv_each(v_response.content, true, E'\t') 
            AS csv_data(source_id TEXT, title TEXT, url TEXT, notes TEXT, created_at TIMESTAMPTZ);
            
            -- Insert into main table
            INSERT INTO scout.ref_sources SELECT * FROM temp_sources ON CONFLICT (source_id) DO NOTHING;
            GET DIAGNOSTICS v_row_count = ROW_COUNT;
            
            v_result := v_result || '✅ Sources: ' || v_row_count || E' loaded\n';
            v_total_loaded := v_total_loaded + v_row_count;
        ELSE
            v_result := v_result || '❌ Sources: Failed (HTTP ' || v_response.status || E')\n';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_result := v_result || '⚠️  Sources: Error - ' || SQLERRM || E'\n';
    END;
    
    -- 2) Load categories
    BEGIN
        v_response := http_get(v_base_url || 'ref_categories.csv');
        IF v_response.status = 200 THEN
            CREATE TEMP TABLE temp_categories (
                category_name TEXT,
                parent_category_name TEXT,
                level INTEGER,
                is_health_sensitive BOOLEAN
            ) ON COMMIT DROP;
            
            -- Import CSV data
            COPY temp_categories FROM PROGRAM 'curl -s "' || v_base_url || 'ref_categories.csv"' 
            WITH (FORMAT CSV, HEADER true);
            
            -- Insert with parent resolution
            INSERT INTO scout.ref_categories (category_name, parent_category_id, level, is_health_sensitive)
            SELECT 
                tc.category_name,
                pc.category_id as parent_category_id,
                tc.level,
                tc.is_health_sensitive
            FROM temp_categories tc
            LEFT JOIN scout.ref_categories pc ON pc.category_name = tc.parent_category_name
            ON CONFLICT (category_name) DO NOTHING;
            
            GET DIAGNOSTICS v_row_count = ROW_COUNT;
            v_result := v_result || '✅ Categories: ' || v_row_count || E' loaded\n';
            v_total_loaded := v_total_loaded + v_row_count;
        ELSE
            v_result := v_result || '❌ Categories: Failed (HTTP ' || v_response.status || E')\n';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_result := v_result || '⚠️  Categories: Error - ' || SQLERRM || E'\n';
    END;
    
    -- 3) Load brands
    BEGIN
        v_response := http_get(v_base_url || 'ref_brands.csv');
        IF v_response.status = 200 THEN
            CREATE TEMP TABLE temp_brands (LIKE scout.ref_brands) ON COMMIT DROP;
            ALTER TABLE temp_brands DROP COLUMN brand_id, DROP COLUMN canonical_name, DROP COLUMN created_at;
            
            COPY temp_brands FROM PROGRAM 'curl -s "' || v_base_url || 'ref_brands.csv"' 
            WITH (FORMAT CSV, HEADER true);
            
            INSERT INTO scout.ref_brands (brand_name, brand_owner, country_origin, is_local, health_positioning)
            SELECT brand_name, brand_owner, country_origin, is_local, health_positioning 
            FROM temp_brands
            ON CONFLICT (brand_name) DO NOTHING;
            
            GET DIAGNOSTICS v_row_count = ROW_COUNT;
            v_result := v_result || '✅ Brands: ' || v_row_count || E' loaded\n';
            v_total_loaded := v_total_loaded + v_row_count;
        ELSE
            v_result := v_result || '❌ Brands: Failed (HTTP ' || v_response.status || E')\n';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_result := v_result || '⚠️  Brands: Error - ' || SQLERRM || E'\n';
    END;
    
    -- 4) Load health category rules
    BEGIN
        v_response := http_get(v_base_url || 'health_category_rules.csv');
        IF v_response.status = 200 THEN
            CREATE TEMP TABLE temp_health_rules (
                category_name TEXT,
                health_flag TEXT,
                lift_pct NUMERIC(5,2),
                confidence_level NUMERIC(3,2),
                source_id TEXT,
                evidence_strength TEXT
            ) ON COMMIT DROP;
            
            COPY temp_health_rules FROM PROGRAM 'curl -s "' || v_base_url || 'health_category_rules.csv"' 
            WITH (FORMAT CSV, HEADER true);
            
            INSERT INTO scout.ref_health_category_rules (category_id, health_flag, lift_pct, confidence_level, source_id, evidence_strength)
            SELECT 
                c.category_id,
                thr.health_flag::health_flag,
                thr.lift_pct,
                thr.confidence_level,
                thr.source_id,
                thr.evidence_strength
            FROM temp_health_rules thr
            JOIN scout.ref_categories c ON c.category_name = thr.category_name
            ON CONFLICT (category_id, health_flag) DO NOTHING;
            
            GET DIAGNOSTICS v_row_count = ROW_COUNT;
            v_result := v_result || '✅ Health Rules: ' || v_row_count || E' loaded\n';
            v_total_loaded := v_total_loaded + v_row_count;
        ELSE
            v_result := v_result || '❌ Health Rules: Failed (HTTP ' || v_response.status || E')\n';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_result := v_result || '⚠️  Health Rules: Error - ' || SQLERRM || E'\n';
    END;
    
    -- 5) Load seasonality factors
    BEGIN
        v_response := http_get(v_base_url || 'seasonality_factors.csv');
        IF v_response.status = 200 THEN
            CREATE TEMP TABLE temp_seasonality (
                category_name TEXT,
                month SMALLINT,
                factor NUMERIC(5,2),
                seasonal_driver TEXT,
                source_id TEXT
            ) ON COMMIT DROP;
            
            COPY temp_seasonality FROM PROGRAM 'curl -s "' || v_base_url || 'seasonality_factors.csv"' 
            WITH (FORMAT CSV, HEADER true);
            
            INSERT INTO scout.ref_category_seasonality (category_id, month, factor, seasonal_driver, source_id)
            SELECT 
                c.category_id,
                ts.month,
                ts.factor,
                ts.seasonal_driver,
                ts.source_id
            FROM temp_seasonality ts
            JOIN scout.ref_categories c ON c.category_name = ts.category_name
            ON CONFLICT (category_id, month) DO NOTHING;
            
            GET DIAGNOSTICS v_row_count = ROW_COUNT;
            v_result := v_result || '✅ Seasonality: ' || v_row_count || E' loaded\n';
            v_total_loaded := v_total_loaded + v_row_count;
        ELSE
            v_result := v_result || '❌ Seasonality: Failed (HTTP ' || v_response.status || E')\n';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_result := v_result || '⚠️  Seasonality: Error - ' || SQLERRM || E'\n';
    END;
    
    -- 6) Load sample SKU catalog (Bronze layer)
    BEGIN
        v_response := http_get(v_base_url || 'sample_sku_catalog.csv');
        IF v_response.status = 200 THEN
            CREATE TEMP TABLE temp_skus (
                sku TEXT,
                product_name TEXT,
                brand TEXT,
                category TEXT,
                price NUMERIC(10,2),
                raw_metadata JSONB
            ) ON COMMIT DROP;
            
            COPY temp_skus FROM PROGRAM 'curl -s "' || v_base_url || 'sample_sku_catalog.csv"' 
            WITH (FORMAT CSV, HEADER true);
            
            INSERT INTO scout.bronze_raw_sku_catalog (sku, product_name, brand, category, price, raw_metadata)
            SELECT sku, product_name, brand, category, price, raw_metadata::jsonb 
            FROM temp_skus;
            
            GET DIAGNOSTICS v_row_count = ROW_COUNT;
            v_result := v_result || '✅ Sample SKUs: ' || v_row_count || E' loaded\n';
            v_total_loaded := v_total_loaded + v_row_count;
        ELSE
            v_result := v_result || '⚠️  Sample SKUs: Not found (optional)' || E'\n';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_result := v_result || '⚠️  Sample SKUs: Error - ' || SQLERRM || E'\n';
    END;
    
    -- Summary
    v_result := v_result || E'\n================================\n';
    v_result := v_result || '🎯 TOTAL LOADED: ' || v_total_loaded || E' rows\n';
    v_result := v_result || '✅ Seed data loading completed!' || E'\n';
    
    RETURN v_result;
END;
$function$;

-- Create convenience function for development seeding
CREATE OR REPLACE FUNCTION scout.fn_seed_dev_data()
RETURNS TEXT
LANGUAGE plpgsql
AS $function$
DECLARE
    v_result TEXT;
BEGIN
    -- Only run in non-production environments
    IF EXISTS (SELECT 1 FROM scout.ref_categories WHERE category_id > 100) THEN
        RETURN '⚠️  Production data detected - skipping development seeding';
    END IF;
    
    -- Load from storage bucket
    SELECT scout.fn_load_seed_data() INTO v_result;
    
    -- Add sample customers and transactions for development
    INSERT INTO scout.silver_customer_health (customer_id, health_flags, age_group, income_bracket, location, dietary_preferences) VALUES
    ('DEV_CUST_001', ARRAY['diabetes']::health_flag[], '40-49', 'middle_class', 'Metro Manila', '{"restrictions": ["low_sugar"]}'),
    ('DEV_CUST_002', ARRAY['obesity']::health_flag[], '30-39', 'upper_middle', 'Cebu City', '{"restrictions": ["low_calorie"]}'),
    ('DEV_CUST_003', ARRAY[]::health_flag[], '25-29', 'middle_class', 'Quezon City', '{"preferences": ["variety"]}')
    ON CONFLICT (customer_id) DO NOTHING;
    
    -- Sample transactions
    WITH sample_transactions AS (
        INSERT INTO scout.silver_transactions (transaction_id, customer_id, store_id, transaction_date, transaction_time, total_amount, payment_method) VALUES
        (gen_random_uuid(), 'DEV_CUST_001', 'DEV_STORE_001', CURRENT_DATE, '14:30:00', 125.00, 'cash'),
        (gen_random_uuid(), 'DEV_CUST_002', 'DEV_STORE_002', CURRENT_DATE, '16:45:00', 200.00, 'gcash'),
        (gen_random_uuid(), 'DEV_CUST_003', 'DEV_STORE_001', CURRENT_DATE, '18:20:00', 150.00, 'card')
        ON CONFLICT (transaction_id) DO NOTHING
        RETURNING transaction_id
    )
    SELECT COUNT(*) FROM sample_transactions;
    
    RETURN v_result || E'\n🧪 Development sample data added!';
END;
$function$;

-- Create bucket access validation function
CREATE OR REPLACE FUNCTION scout.fn_validate_seed_bucket()
RETURNS TABLE (
    file_name TEXT,
    exists BOOLEAN,
    size_bytes BIGINT,
    last_modified TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_project_ref TEXT := 'cxzllzyxwpyptfretryc';
    v_base_url TEXT;
    v_response http_response_result;
    v_file TEXT;
BEGIN
    v_base_url := 'https://' || v_project_ref || '.supabase.co/storage/v1/object/public/seed-data/';
    
    -- Check each required file
    FOR v_file IN VALUES ('ref_sources.csv'), ('ref_categories.csv'), ('ref_brands.csv'), ('health_category_rules.csv'), ('seasonality_factors.csv') LOOP
        BEGIN
            v_response := http_head(v_base_url || v_file);
            
            RETURN QUERY SELECT 
                v_file,
                (v_response.status = 200),
                COALESCE((v_response.headers->>'content-length')::BIGINT, 0),
                COALESCE((v_response.headers->>'last-modified')::TIMESTAMPTZ, NULL);
        EXCEPTION WHEN OTHERS THEN
            RETURN QUERY SELECT v_file, false, 0::BIGINT, NULL::TIMESTAMPTZ;
        END;
    END LOOP;
END;
$function$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION scout.fn_load_seed_data() TO service_role;
GRANT EXECUTE ON FUNCTION scout.fn_seed_dev_data() TO service_role;
GRANT EXECUTE ON FUNCTION scout.fn_validate_seed_bucket() TO service_role;