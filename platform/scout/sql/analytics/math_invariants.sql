-- ============================================================
-- Scout v5.2 - Math Invariants & Data Quality Checks
-- Ensures analytics formulas are mathematically sound
-- ============================================================

SET search_path TO scout, public;

-- Data Quality Invariants for Analytics Layer
-- Run these checks before trusting any Gold/Platinum analytics

-- 1) ADDITIVITY CHECK: Line amounts must sum to transaction totals
CREATE OR REPLACE VIEW scout.v_additivity_check AS
WITH line_totals AS (
    SELECT 
        transaction_id,
        SUM(line_amount) AS calculated_total,
        COUNT(*) AS line_count
    FROM scout.fact_transaction_items 
    GROUP BY transaction_id
),
transaction_totals AS (
    SELECT 
        transaction_id,
        total_amount AS reported_total
    FROM scout.fact_transactions
)
SELECT 
    lt.transaction_id,
    lt.calculated_total,
    tt.reported_total,
    ABS(lt.calculated_total - tt.reported_total) AS difference,
    lt.line_count,
    CASE 
        WHEN ABS(lt.calculated_total - tt.reported_total) < 0.01 THEN 'PASS'
        WHEN ABS(lt.calculated_total - tt.reported_total) < 1.00 THEN 'WARN'
        ELSE 'FAIL'
    END AS check_status
FROM line_totals lt
JOIN transaction_totals tt USING (transaction_id)
WHERE ABS(lt.calculated_total - tt.reported_total) >= 0.01
ORDER BY difference DESC;

-- 2) MARKET SHARE ADDITIVITY: Category shares must sum to ~100%
CREATE OR REPLACE VIEW scout.v_market_share_check AS
WITH brand_shares AS (
    SELECT 
        store_id,
        category,
        transaction_date,
        brand,
        share_revenue
    FROM scout.gold_brand_competitive_30d
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '7 days'
),
category_totals AS (
    SELECT 
        store_id,
        category,
        transaction_date,
        SUM(share_revenue) AS total_share,
        COUNT(DISTINCT brand) AS brand_count
    FROM brand_shares
    GROUP BY store_id, category, transaction_date
)
SELECT 
    store_id,
    category,
    transaction_date,
    total_share,
    brand_count,
    ABS(total_share - 100.0) AS share_error,
    CASE 
        WHEN ABS(total_share - 100.0) < 0.1 THEN 'PASS'
        WHEN ABS(total_share - 100.0) < 1.0 THEN 'WARN'
        ELSE 'FAIL'
    END AS check_status
FROM category_totals
WHERE ABS(total_share - 100.0) >= 0.1
ORDER BY share_error DESC;

-- 3) UNIQUENESS CHECK: Prevent double-counting
CREATE OR REPLACE VIEW scout.v_uniqueness_check AS
WITH duplicates AS (
    SELECT 
        transaction_id,
        product_key,
        COUNT(*) as duplicate_count
    FROM scout.fact_transaction_items
    GROUP BY transaction_id, product_key
    HAVING COUNT(*) > 1
)
SELECT 
    d.transaction_id,
    d.product_key,
    d.duplicate_count,
    p.product_name,
    'FAIL' as check_status
FROM duplicates d
LEFT JOIN scout.dim_products p ON d.product_key = p.product_key
ORDER BY duplicate_count DESC;

-- 4) WEIGHTED AVERAGE VALIDATION: Price calculations
CREATE OR REPLACE VIEW scout.v_weighted_price_check AS
WITH price_calcs AS (
    SELECT 
        store_id,
        category,
        brand,
        -- Manual weighted average
        SUM(line_amount) / NULLIF(SUM(quantity), 0) AS manual_avg_price,
        -- Using built-in weighted calculation
        SUM(unit_price * quantity) / NULLIF(SUM(quantity), 0) AS weighted_avg_price,
        SUM(quantity) as total_units
    FROM scout.silver_line_items sli
    JOIN scout.dim_products p ON sli.product_key = p.product_key
    JOIN scout.dim_stores s ON sli.store_key = s.store_key
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY store_id, category, brand
)
SELECT 
    store_id,
    category,
    brand,
    manual_avg_price,
    weighted_avg_price,
    total_units,
    ABS(manual_avg_price - weighted_avg_price) AS price_diff,
    CASE 
        WHEN ABS(manual_avg_price - weighted_avg_price) < 0.01 THEN 'PASS'
        WHEN ABS(manual_avg_price - weighted_avg_price) < 0.10 THEN 'WARN'
        ELSE 'FAIL'
    END AS check_status
FROM price_calcs
WHERE total_units > 0 
  AND ABS(manual_avg_price - weighted_avg_price) >= 0.01
ORDER BY price_diff DESC;

-- 5) CURRENCY & UNIT NORMALIZATION CHECK
CREATE OR REPLACE VIEW scout.v_normalization_check AS
WITH unit_analysis AS (
    SELECT 
        p.product_name,
        p.unit_size,
        p.category,
        COUNT(DISTINCT fti.unit_price) as price_variants,
        MIN(fti.unit_price) as min_price,
        MAX(fti.unit_price) as max_price,
        MAX(fti.unit_price) / NULLIF(MIN(fti.unit_price), 0) as price_ratio
    FROM scout.fact_transaction_items fti
    JOIN scout.dim_products p ON fti.product_key = p.product_key
    WHERE fti.unit_price > 0
    GROUP BY p.product_name, p.unit_size, p.category
)
SELECT 
    product_name,
    unit_size,
    category,
    price_variants,
    min_price,
    max_price,
    price_ratio,
    CASE 
        WHEN price_ratio <= 2.0 THEN 'PASS'
        WHEN price_ratio <= 5.0 THEN 'WARN'
        ELSE 'FAIL'
    END AS check_status
FROM unit_analysis
WHERE price_ratio > 2.0
ORDER BY price_ratio DESC;

-- 6) TEMPORAL WINDOW CONSISTENCY CHECK
CREATE OR REPLACE VIEW scout.v_window_consistency_check AS
WITH window_defs AS (
    SELECT 
        'gold_daily_metrics' as view_name,
        'day' as window_type,
        1 as expected_days
    UNION ALL
    SELECT 
        'gold_brand_competitive_30d' as view_name,
        '30d' as window_type,
        30 as expected_days
    UNION ALL
    SELECT 
        'gold_region_choropleth' as view_name,
        'variable' as window_type,
        NULL as expected_days
),
actual_windows AS (
    SELECT 
        'gold_daily_metrics' as view_name,
        MAX(transaction_date) - MIN(transaction_date) + 1 as actual_days,
        COUNT(DISTINCT transaction_date) as distinct_days
    FROM scout.gold_daily_metrics
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '35 days'
    
    UNION ALL
    
    SELECT 
        'gold_brand_competitive_30d' as view_name,
        MAX(transaction_date) - MIN(transaction_date) + 1 as actual_days,
        COUNT(DISTINCT transaction_date) as distinct_days
    FROM scout.gold_brand_competitive_30d
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '35 days'
)
SELECT 
    wd.view_name,
    wd.window_type,
    wd.expected_days,
    aw.actual_days,
    aw.distinct_days,
    CASE 
        WHEN wd.expected_days IS NULL THEN 'SKIP'
        WHEN ABS(aw.actual_days - wd.expected_days) <= 1 THEN 'PASS'
        WHEN ABS(aw.actual_days - wd.expected_days) <= 3 THEN 'WARN'
        ELSE 'FAIL'
    END AS check_status
FROM window_defs wd
LEFT JOIN actual_windows aw ON wd.view_name = aw.view_name;

-- 7) MASTER DATA QUALITY GATES
CREATE OR REPLACE VIEW scout.v_master_data_quality AS
WITH data_completeness AS (
    SELECT 
        'dim_products' as table_name,
        COUNT(*) as total_records,
        COUNT(*) FILTER (WHERE product_name IS NOT NULL) as name_complete,
        COUNT(*) FILTER (WHERE category IS NOT NULL) as category_complete,
        COUNT(*) FILTER (WHERE brand IS NOT NULL) as brand_complete,
        COUNT(*) FILTER (WHERE unit_price > 0) as price_complete
    FROM scout.dim_products
    WHERE is_current = true
    
    UNION ALL
    
    SELECT 
        'dim_stores' as table_name,
        COUNT(*) as total_records,
        COUNT(*) FILTER (WHERE store_name IS NOT NULL) as name_complete,
        COUNT(*) FILTER (WHERE city_municipality IS NOT NULL) as location_complete,
        COUNT(*) FILTER (WHERE region IS NOT NULL) as region_complete,
        COUNT(*) FILTER (WHERE store_type IS NOT NULL) as type_complete
    FROM scout.dim_stores
    WHERE is_current = true
)
SELECT 
    table_name,
    total_records,
    ROUND(100.0 * name_complete / NULLIF(total_records, 0), 1) as name_completeness_pct,
    ROUND(100.0 * category_complete / NULLIF(total_records, 0), 1) as category_completeness_pct,
    ROUND(100.0 * brand_complete / NULLIF(total_records, 0), 1) as brand_completeness_pct,
    CASE 
        WHEN name_complete::float / NULLIF(total_records, 0) >= 0.95 THEN 'PASS'
        WHEN name_complete::float / NULLIF(total_records, 0) >= 0.90 THEN 'WARN'
        ELSE 'FAIL'
    END AS data_quality_status
FROM data_completeness;

-- Summary check function for CI/CD
CREATE OR REPLACE FUNCTION scout.run_math_invariant_checks()
RETURNS TABLE (
    check_name TEXT,
    status TEXT,
    error_count BIGINT,
    total_count BIGINT,
    pass_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH checks AS (
        SELECT 'additivity' as name, check_status as status, COUNT(*) as cnt
        FROM scout.v_additivity_check GROUP BY check_status
        
        UNION ALL
        
        SELECT 'market_share' as name, check_status as status, COUNT(*) as cnt
        FROM scout.v_market_share_check GROUP BY check_status
        
        UNION ALL
        
        SELECT 'uniqueness' as name, check_status as status, COUNT(*) as cnt
        FROM scout.v_uniqueness_check GROUP BY check_status
        
        UNION ALL
        
        SELECT 'weighted_price' as name, check_status as status, COUNT(*) as cnt
        FROM scout.v_weighted_price_check GROUP BY check_status
        
        UNION ALL
        
        SELECT 'normalization' as name, check_status as status, COUNT(*) as cnt
        FROM scout.v_normalization_check GROUP BY check_status
    ),
    check_summary AS (
        SELECT 
            name,
            SUM(cnt) as total,
            SUM(cnt) FILTER (WHERE status = 'FAIL') as failures,
            SUM(cnt) FILTER (WHERE status = 'WARN') as warnings,
            SUM(cnt) FILTER (WHERE status = 'PASS') as passes
        FROM checks
        GROUP BY name
    )
    SELECT 
        cs.name::TEXT,
        CASE 
            WHEN cs.failures > 0 THEN 'FAIL'
            WHEN cs.warnings > 0 THEN 'WARN' 
            ELSE 'PASS'
        END::TEXT as status,
        COALESCE(cs.failures, 0) as error_count,
        cs.total as total_count,
        ROUND(100.0 * COALESCE(cs.passes, 0) / NULLIF(cs.total, 0), 2) as pass_rate
    FROM check_summary cs
    ORDER BY cs.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION scout.run_math_invariant_checks() TO authenticated;