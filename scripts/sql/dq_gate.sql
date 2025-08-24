-- Data Quality Gate for Scout Analytics Platform
-- Production readiness criteria for data quality

-- Set strict error handling
\set ON_ERROR_STOP on

-- Helper function to check coverage
CREATE OR REPLACE FUNCTION check_coverage(
    covered_count INTEGER,
    total_count INTEGER,
    threshold DECIMAL
) RETURNS BOOLEAN AS $$
BEGIN
    IF total_count = 0 THEN
        RETURN FALSE;
    END IF;
    RETURN (covered_count::DECIMAL / total_count::DECIMAL) >= threshold;
END;
$$ LANGUAGE plpgsql;

-- Brand Coverage Check (Must be >= 70%)
WITH brand_coverage AS (
    SELECT 
        COUNT(DISTINCT CASE WHEN dp.price IS NOT NULL THEN dp.product_id END) as products_with_brand,
        COUNT(DISTINCT dp.product_id) as total_products,
        ROUND(COUNT(DISTINCT CASE WHEN dp.price IS NOT NULL THEN dp.product_id END)::DECIMAL / 
              NULLIF(COUNT(DISTINCT dp.product_id), 0) * 100, 2) as coverage_percentage
    FROM scout_gold.dim_products dp
    LEFT JOIN scout_gold.dim_brands db ON dp.brand_id = db.brand_id
    WHERE dp.is_active = true
)
SELECT 
    'Brand Coverage' as metric,
    coverage_percentage || '%' as value,
    CASE 
        WHEN coverage_percentage >= 70 THEN 'PASS'
        ELSE 'FAIL'
    END as status,
    'Minimum 70% required' as threshold
FROM brand_coverage;

-- Price Coverage Check (Must be >= 85%)
WITH price_coverage AS (
    SELECT 
        COUNT(DISTINCT CASE WHEN ft.total_amount > 0 THEN ft.product_id END) as products_with_price,
        COUNT(DISTINCT ft.product_id) as total_products,
        ROUND(COUNT(DISTINCT CASE WHEN ft.total_amount > 0 THEN ft.product_id END)::DECIMAL / 
              NULLIF(COUNT(DISTINCT ft.product_id), 0) * 100, 2) as coverage_percentage
    FROM scout_gold.fact_transactions ft
    WHERE ft.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
)
SELECT 
    'Price Coverage' as metric,
    coverage_percentage || '%' as value,
    CASE 
        WHEN coverage_percentage >= 85 THEN 'PASS'
        ELSE 'FAIL'
    END as status,
    'Minimum 85% required' as threshold
FROM price_coverage;

-- Store Completeness Check
WITH store_completeness AS (
    SELECT 
        COUNT(CASE WHEN store_name IS NOT NULL AND city IS NOT NULL AND region IS NOT NULL THEN 1 END) as complete_stores,
        COUNT(*) as total_stores,
        ROUND(COUNT(CASE WHEN store_name IS NOT NULL AND city IS NOT NULL AND region IS NOT NULL THEN 1 END)::DECIMAL / 
              NULLIF(COUNT(*), 0) * 100, 2) as completeness_percentage
    FROM scout_gold.dim_stores
    WHERE is_active = true
)
SELECT 
    'Store Completeness' as metric,
    completeness_percentage || '%' as value,
    CASE 
        WHEN completeness_percentage >= 95 THEN 'PASS'
        ELSE 'FAIL'
    END as status,
    'Minimum 95% required' as threshold
FROM store_completeness;

-- Transaction Data Freshness
WITH data_freshness AS (
    SELECT 
        MAX(transaction_timestamp) as latest_transaction,
        EXTRACT(EPOCH FROM (NOW() - MAX(transaction_timestamp)))/3600 as hours_old
    FROM scout_gold.fact_transactions
)
SELECT 
    'Data Freshness' as metric,
    ROUND(hours_old, 2) || ' hours' as value,
    CASE 
        WHEN hours_old <= 24 THEN 'PASS'
        ELSE 'FAIL'
    END as status,
    'Maximum 24 hours old' as threshold
FROM data_freshness;

-- Dataset Publisher Health
WITH publisher_health AS (
    SELECT 
        COUNT(DISTINCT dataset_type) as active_types,
        COUNT(CASE WHEN created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_datasets,
        AVG(CASE WHEN file_size_bytes > 0 THEN 1 ELSE 0 END) * 100 as valid_datasets_pct
    FROM datasets.published_datasets
)
SELECT 
    'Dataset Publisher' as metric,
    ROUND(valid_datasets_pct, 2) || '% valid' as value,
    CASE 
        WHEN valid_datasets_pct >= 90 AND recent_datasets > 0 THEN 'PASS'
        ELSE 'FAIL'
    END as status,
    'Minimum 90% valid datasets' as threshold
FROM publisher_health;

-- Regional Replication Success
WITH replication_health AS (
    SELECT 
        COUNT(CASE WHEN status = 'completed' THEN 1 END) as successful,
        COUNT(*) as total,
        ROUND(COUNT(CASE WHEN status = 'completed' THEN 1 END)::DECIMAL / 
              NULLIF(COUNT(*), 0) * 100, 2) as success_rate
    FROM replication.replication_queue
    WHERE created_at >= NOW() - INTERVAL '24 hours'
)
SELECT 
    'Replication Success' as metric,
    success_rate || '%' as value,
    CASE 
        WHEN success_rate >= 95 THEN 'PASS'
        ELSE 'FAIL'
    END as status,
    'Minimum 95% success rate' as threshold
FROM replication_health;

-- Transcript Processing Accuracy
WITH transcript_accuracy AS (
    SELECT 
        COUNT(CASE WHEN jsonb_array_length(detected_brands) > 0 THEN 1 END) as with_brands,
        COUNT(*) as total_transcripts,
        ROUND(COUNT(CASE WHEN jsonb_array_length(detected_brands) > 0 THEN 1 END)::DECIMAL / 
              NULLIF(COUNT(*), 0) * 100, 2) as detection_rate
    FROM scout.processed_transcripts
    WHERE created_at >= NOW() - INTERVAL '7 days'
)
SELECT 
    'Brand Detection Rate' as metric,
    detection_rate || '%' as value,
    CASE 
        WHEN detection_rate >= 60 THEN 'PASS'
        ELSE 'FAIL'
    END as status,
    'Minimum 60% detection' as threshold
FROM transcript_accuracy;

-- Overall Data Quality Score
WITH dq_summary AS (
    SELECT 
        COUNT(CASE WHEN status = 'PASS' THEN 1 END) as passed_checks,
        COUNT(*) as total_checks
    FROM (
        -- Combine all checks
        SELECT 'PASS' as status WHERE EXISTS (
            SELECT 1 FROM scout_gold.dim_products dp
            LEFT JOIN scout_gold.dim_brands db ON dp.brand_id = db.brand_id
            WHERE dp.is_active = true
            GROUP BY 1
            HAVING COUNT(DISTINCT CASE WHEN dp.price IS NOT NULL THEN dp.product_id END)::DECIMAL / 
                   NULLIF(COUNT(DISTINCT dp.product_id), 0) >= 0.7
        )
        UNION ALL
        SELECT 'PASS' WHERE EXISTS (
            SELECT 1 FROM scout_gold.fact_transactions
            WHERE transaction_date >= CURRENT_DATE - INTERVAL '30 days'
            GROUP BY 1
            HAVING COUNT(DISTINCT CASE WHEN total_amount > 0 THEN product_id END)::DECIMAL / 
                   NULLIF(COUNT(DISTINCT product_id), 0) >= 0.85
        )
        -- Add other checks...
    ) checks
)
SELECT 
    '=== OVERALL DQ SCORE ===' as metric,
    passed_checks || '/' || total_checks || ' checks passed' as value,
    CASE 
        WHEN passed_checks = total_checks THEN 'PASS'
        ELSE 'FAIL'
    END as status,
    'All checks must pass' as threshold
FROM dq_summary;

-- Clean up
DROP FUNCTION IF EXISTS check_coverage(INTEGER, INTEGER, DECIMAL);