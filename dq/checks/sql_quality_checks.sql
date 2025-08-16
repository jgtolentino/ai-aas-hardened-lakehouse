-- Scout Data Quality SQL Checks
-- Run these periodically to monitor data health

-- 1. Check for data freshness
WITH freshness_check AS (
    SELECT 
        MAX(ts) as latest_transaction,
        CURRENT_TIMESTAMP - MAX(ts) as data_lag,
        CASE 
            WHEN CURRENT_TIMESTAMP - MAX(ts) > INTERVAL '1 hour' THEN 'STALE'
            ELSE 'FRESH'
        END as freshness_status
    FROM scout.silver_transactions
)
SELECT * FROM freshness_check;

-- 2. Check for duplicate transactions
WITH duplicate_check AS (
    SELECT 
        id,
        COUNT(*) as occurrence_count
    FROM scout.silver_transactions
    GROUP BY id
    HAVING COUNT(*) > 1
)
SELECT 
    COUNT(*) as duplicate_transaction_count,
    CASE 
        WHEN COUNT(*) > 0 THEN 'DUPLICATES_FOUND'
        ELSE 'NO_DUPLICATES'
    END as status
FROM duplicate_check;

-- 3. Basket consistency check
WITH basket_consistency AS (
    SELECT 
        st.id,
        st.basket_size as declared_basket_size,
        COUNT(sci.sku) as actual_basket_size,
        st.basket_size - COUNT(sci.sku) as size_difference
    FROM scout.silver_transactions st
    LEFT JOIN scout.silver_combo_items sci ON st.id = sci.id
    GROUP BY st.id, st.basket_size
    HAVING st.basket_size != COUNT(sci.sku)
)
SELECT 
    COUNT(*) as inconsistent_baskets,
    AVG(ABS(size_difference)) as avg_size_difference
FROM basket_consistency;

-- 4. Substitution completeness check
WITH substitution_check AS (
    SELECT 
        id,
        occurred,
        from_sku,
        to_sku,
        reason,
        CASE 
            WHEN occurred = true AND (from_sku IS NULL OR to_sku IS NULL OR reason IS NULL) THEN 'INCOMPLETE'
            WHEN occurred = false AND (from_sku IS NOT NULL OR to_sku IS NOT NULL OR reason IS NOT NULL) THEN 'INCONSISTENT'
            ELSE 'OK'
        END as substitution_status
    FROM scout.silver_substitutions
)
SELECT 
    substitution_status,
    COUNT(*) as count
FROM substitution_check
GROUP BY substitution_status;

-- 5. Price reasonableness check
WITH price_check AS (
    SELECT 
        st.id,
        st.sku,
        st.units_per_transaction,
        st.peso_value,
        ds.unit_price,
        st.peso_value / NULLIF(st.units_per_transaction, 0) as implied_unit_price,
        ABS(st.peso_value - (st.units_per_transaction * ds.unit_price)) as price_variance
    FROM scout.silver_transactions st
    JOIN scout.dim_sku ds ON st.sku = ds.sku
    WHERE ds.unit_price > 0
)
SELECT 
    COUNT(*) as transactions_checked,
    AVG(price_variance) as avg_price_variance,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY price_variance) as p95_variance,
    COUNT(CASE WHEN price_variance > 100 THEN 1 END) as high_variance_count
FROM price_check;

-- 6. Geographic coverage check
WITH geo_coverage AS (
    SELECT 
        region,
        COUNT(DISTINCT province) as provinces,
        COUNT(DISTINCT city) as cities,
        COUNT(DISTINCT barangay) as barangays,
        COUNT(DISTINCT store_id) as stores,
        COUNT(*) as transactions
    FROM scout.silver_transactions
    WHERE ts >= CURRENT_DATE - INTERVAL '7 days'
    GROUP BY region
)
SELECT * FROM geo_coverage ORDER BY transactions DESC;

-- 7. Enum value distribution (detect anomalies)
WITH enum_distribution AS (
    SELECT 
        'request_mode' as field,
        request_mode as value,
        COUNT(*) as count,
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as percentage
    FROM scout.silver_transactions
    WHERE ts >= CURRENT_DATE - INTERVAL '1 day'
    GROUP BY request_mode
    
    UNION ALL
    
    SELECT 
        'payment_method' as field,
        payment_method as value,
        COUNT(*) as count,
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as percentage
    FROM scout.silver_transactions
    WHERE ts >= CURRENT_DATE - INTERVAL '1 day'
    GROUP BY payment_method
    
    UNION ALL
    
    SELECT 
        'customer_type' as field,
        customer_type as value,
        COUNT(*) as count,
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as percentage
    FROM scout.silver_transactions
    WHERE ts >= CURRENT_DATE - INTERVAL '1 day'
    GROUP BY customer_type
)
SELECT * FROM enum_distribution ORDER BY field, count DESC;

-- 8. Data quality issues summary
SELECT 
    issue_type,
    severity,
    COUNT(*) as issue_count,
    COUNT(DISTINCT transaction_id) as affected_transactions,
    MIN(created_at) as first_seen,
    MAX(created_at) as last_seen
FROM scout.data_quality_issues
WHERE created_at >= CURRENT_DATE - INTERVAL '1 day'
GROUP BY issue_type, severity
ORDER BY severity, issue_count DESC;

-- 9. Hourly ingestion monitoring
WITH hourly_ingestion AS (
    SELECT 
        date_trunc('hour', ts) as hour,
        COUNT(*) as transactions,
        COUNT(DISTINCT store_id) as unique_stores,
        AVG(peso_value) as avg_transaction_value,
        SUM(peso_value) as hourly_revenue
    FROM scout.silver_transactions
    WHERE ts >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    GROUP BY 1
)
SELECT 
    hour,
    transactions,
    unique_stores,
    avg_transaction_value,
    hourly_revenue,
    LAG(transactions, 1) OVER (ORDER BY hour) as prev_hour_transactions,
    CASE 
        WHEN LAG(transactions, 1) OVER (ORDER BY hour) > 0 
        THEN (transactions - LAG(transactions, 1) OVER (ORDER BY hour))::float / LAG(transactions, 1) OVER (ORDER BY hour) * 100
        ELSE NULL 
    END as hour_over_hour_change
FROM hourly_ingestion
ORDER BY hour DESC;

-- 10. Create monitoring view for dashboards
CREATE OR REPLACE VIEW scout.v_data_quality_metrics AS
WITH metrics AS (
    SELECT 
        -- Freshness
        (SELECT EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - MAX(ts))) / 60 FROM scout.silver_transactions) as minutes_since_last_transaction,
        
        -- Volume
        (SELECT COUNT(*) FROM scout.silver_transactions WHERE ts >= CURRENT_DATE) as transactions_today,
        (SELECT COUNT(DISTINCT store_id) FROM scout.silver_transactions WHERE ts >= CURRENT_DATE) as active_stores_today,
        
        -- Quality
        (SELECT COUNT(*) FROM scout.data_quality_issues WHERE severity = 'error' AND created_at >= CURRENT_DATE) as errors_today,
        (SELECT COUNT(*) FROM scout.data_quality_issues WHERE severity = 'warning' AND created_at >= CURRENT_DATE) as warnings_today,
        
        -- Completeness
        (SELECT AVG(CASE WHEN peso_value > 0 THEN 1 ELSE 0 END) FROM scout.silver_transactions WHERE ts >= CURRENT_DATE) as peso_value_completeness,
        (SELECT AVG(CASE WHEN suggestion_accepted IS NOT NULL THEN 1 ELSE 0 END) FROM scout.silver_transactions WHERE ts >= CURRENT_DATE) as suggestion_completeness
)
SELECT 
    CURRENT_TIMESTAMP as check_timestamp,
    minutes_since_last_transaction,
    CASE 
        WHEN minutes_since_last_transaction > 60 THEN 'ALERT'
        WHEN minutes_since_last_transaction > 30 THEN 'WARNING'
        ELSE 'OK'
    END as freshness_status,
    transactions_today,
    active_stores_today,
    errors_today,
    warnings_today,
    ROUND(peso_value_completeness * 100, 2) as peso_value_completeness_pct,
    ROUND(suggestion_completeness * 100, 2) as suggestion_completeness_pct
FROM metrics;