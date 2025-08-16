-- ============================================================================
-- Scout Gold Layer - Business-Ready Aggregates
-- Daily, weekly, and monthly aggregations for dashboards
-- ============================================================================

-- Drop existing views if they exist (for clean re-run)
DROP VIEW IF EXISTS scout_gold.daily_transactions CASCADE;
DROP VIEW IF EXISTS scout_gold.weekly_performance CASCADE;
DROP VIEW IF EXISTS scout_gold.monthly_trends CASCADE;
DROP VIEW IF EXISTS scout_gold.store_rankings CASCADE;
DROP VIEW IF EXISTS scout_gold.product_insights CASCADE;
DROP VIEW IF EXISTS scout_gold.customer_segments CASCADE;

-- Daily Transaction Summary
CREATE OR REPLACE VIEW scout_gold.daily_transactions AS
WITH daily_stats AS (
    SELECT 
        DATE(captured_at) as transaction_date,
        device_id,
        COUNT(*) as transaction_count,
        COUNT(DISTINCT payload->>'store_id') as unique_stores,
        COUNT(DISTINCT payload->>'customer_id') as unique_customers,
        SUM((payload->>'peso_value')::NUMERIC) as total_revenue,
        AVG((payload->>'peso_value')::NUMERIC) as avg_transaction_value,
        SUM((payload->>'units_per_transaction')::INTEGER) as total_units,
        AVG((payload->>'basket_size')::INTEGER) as avg_basket_size,
        -- Payment method distribution
        COUNT(*) FILTER (WHERE payload->>'payment_method' = 'cash') as cash_transactions,
        COUNT(*) FILTER (WHERE payload->>'payment_method' = 'gcash') as gcash_transactions,
        COUNT(*) FILTER (WHERE payload->>'payment_method' = 'card') as card_transactions,
        -- Time-based patterns
        COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM captured_at) BETWEEN 6 AND 12) as morning_transactions,
        COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM captured_at) BETWEEN 12 AND 18) as afternoon_transactions,
        COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM captured_at) BETWEEN 18 AND 24) as evening_transactions,
        -- Request patterns
        COUNT(*) FILTER (WHERE payload->>'request_mode' = 'voice') as voice_requests,
        COUNT(*) FILTER (WHERE payload->>'request_mode' = 'text') as text_requests,
        COUNT(*) FILTER (WHERE (payload->>'suggestion_accepted')::BOOLEAN) as suggestions_accepted,
        -- Data quality
        COUNT(*) FILTER (WHERE payload ? 'store_id' AND payload ? 'peso_value') as complete_records,
        MIN(captured_at) as first_transaction_time,
        MAX(captured_at) as last_transaction_time
    FROM scout.bronze_edge_raw
    WHERE captured_at IS NOT NULL
    GROUP BY DATE(captured_at), device_id
)
SELECT 
    transaction_date,
    device_id,
    transaction_count,
    unique_stores,
    unique_customers,
    ROUND(total_revenue, 2) as total_revenue,
    ROUND(avg_transaction_value, 2) as avg_transaction_value,
    total_units,
    ROUND(avg_basket_size, 2) as avg_basket_size,
    -- Payment method percentages
    ROUND(100.0 * cash_transactions / NULLIF(transaction_count, 0), 1) as cash_pct,
    ROUND(100.0 * gcash_transactions / NULLIF(transaction_count, 0), 1) as gcash_pct,
    ROUND(100.0 * card_transactions / NULLIF(transaction_count, 0), 1) as card_pct,
    -- Time distribution
    ROUND(100.0 * morning_transactions / NULLIF(transaction_count, 0), 1) as morning_pct,
    ROUND(100.0 * afternoon_transactions / NULLIF(transaction_count, 0), 1) as afternoon_pct,
    ROUND(100.0 * evening_transactions / NULLIF(transaction_count, 0), 1) as evening_pct,
    -- Engagement metrics
    ROUND(100.0 * voice_requests / NULLIF(transaction_count, 0), 1) as voice_request_pct,
    ROUND(100.0 * suggestions_accepted / NULLIF(transaction_count, 0), 1) as suggestion_acceptance_rate,
    -- Data quality score
    ROUND(100.0 * complete_records / NULLIF(transaction_count, 0), 1) as data_completeness_pct,
    -- Operating hours
    EXTRACT(HOUR FROM first_transaction_time) as first_hour,
    EXTRACT(HOUR FROM last_transaction_time) as last_hour,
    EXTRACT(EPOCH FROM (last_transaction_time - first_transaction_time))/3600 as operating_hours
FROM daily_stats
ORDER BY transaction_date DESC, device_id;

-- Weekly Performance Aggregates
CREATE OR REPLACE VIEW scout_gold.weekly_performance AS
SELECT 
    DATE_TRUNC('week', transaction_date)::DATE as week_start,
    device_id,
    COUNT(DISTINCT transaction_date) as active_days,
    SUM(transaction_count) as total_transactions,
    SUM(unique_stores) as total_unique_stores,
    SUM(unique_customers) as total_unique_customers,
    SUM(total_revenue) as weekly_revenue,
    AVG(total_revenue) as avg_daily_revenue,
    SUM(total_units) as weekly_units,
    AVG(avg_basket_size) as avg_basket_size,
    -- Growth metrics
    LAG(SUM(total_revenue)) OVER (PARTITION BY device_id ORDER BY DATE_TRUNC('week', transaction_date)) as prev_week_revenue,
    ROUND(100.0 * (SUM(total_revenue) - LAG(SUM(total_revenue)) OVER (PARTITION BY device_id ORDER BY DATE_TRUNC('week', transaction_date))) 
        / NULLIF(LAG(SUM(total_revenue)) OVER (PARTITION BY device_id ORDER BY DATE_TRUNC('week', transaction_date)), 0), 1) as revenue_growth_pct,
    -- Consistency score (active days / 7)
    ROUND(COUNT(DISTINCT transaction_date) * 100.0 / 7, 1) as consistency_score
FROM scout_gold.daily_transactions
GROUP BY DATE_TRUNC('week', transaction_date), device_id
ORDER BY week_start DESC, device_id;

-- Monthly Trends
CREATE OR REPLACE VIEW scout_gold.monthly_trends AS
SELECT 
    DATE_TRUNC('month', transaction_date)::DATE as month_start,
    TO_CHAR(transaction_date, 'YYYY-MM') as year_month,
    COUNT(DISTINCT device_id) as active_devices,
    COUNT(DISTINCT transaction_date) as active_days,
    SUM(transaction_count) as total_transactions,
    SUM(unique_stores) as total_unique_stores,
    SUM(unique_customers) as total_unique_customers,
    SUM(total_revenue) as monthly_revenue,
    AVG(avg_transaction_value) as avg_transaction_value,
    SUM(total_units) as monthly_units,
    -- Payment trends
    AVG(cash_pct) as avg_cash_pct,
    AVG(gcash_pct) as avg_gcash_pct,
    AVG(card_pct) as avg_card_pct,
    -- Engagement trends
    AVG(voice_request_pct) as avg_voice_usage,
    AVG(suggestion_acceptance_rate) as avg_suggestion_acceptance,
    -- Seasonal patterns
    CASE 
        WHEN EXTRACT(MONTH FROM transaction_date) IN (3,4,5) THEN 'Q1'
        WHEN EXTRACT(MONTH FROM transaction_date) IN (6,7,8) THEN 'Q2'
        WHEN EXTRACT(MONTH FROM transaction_date) IN (9,10,11) THEN 'Q3'
        ELSE 'Q4'
    END as fiscal_quarter
FROM scout_gold.daily_transactions
GROUP BY DATE_TRUNC('month', transaction_date), TO_CHAR(transaction_date, 'YYYY-MM')
ORDER BY month_start DESC;

-- Store Rankings (by revenue)
CREATE OR REPLACE VIEW scout_gold.store_rankings AS
WITH store_metrics AS (
    SELECT 
        payload->>'store_id' as store_id,
        payload->'location'->>'region' as region,
        payload->'location'->>'city' as city,
        COUNT(*) as transaction_count,
        SUM((payload->>'peso_value')::NUMERIC) as total_revenue,
        AVG((payload->>'peso_value')::NUMERIC) as avg_transaction_value,
        COUNT(DISTINCT DATE(captured_at)) as active_days,
        COUNT(DISTINCT payload->>'customer_id') as unique_customers,
        AVG((payload->>'basket_size')::INTEGER) as avg_basket_size,
        -- Engagement scores
        AVG(CASE WHEN (payload->>'suggestion_accepted')::BOOLEAN THEN 1 ELSE 0 END) * 100 as suggestion_acceptance_rate,
        AVG((payload->>'handshake_score')::NUMERIC) as avg_handshake_score
    FROM scout.bronze_edge_raw
    WHERE payload ? 'store_id'
        AND captured_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY payload->>'store_id', payload->'location'->>'region', payload->'location'->>'city'
)
SELECT 
    store_id,
    region,
    city,
    transaction_count,
    ROUND(total_revenue, 2) as total_revenue,
    ROUND(avg_transaction_value, 2) as avg_transaction_value,
    active_days,
    unique_customers,
    ROUND(avg_basket_size, 2) as avg_basket_size,
    ROUND(suggestion_acceptance_rate, 1) as suggestion_acceptance_rate,
    ROUND(avg_handshake_score, 2) as avg_handshake_score,
    -- Rankings
    RANK() OVER (ORDER BY total_revenue DESC) as revenue_rank,
    RANK() OVER (PARTITION BY region ORDER BY total_revenue DESC) as regional_revenue_rank,
    RANK() OVER (ORDER BY transaction_count DESC) as volume_rank,
    RANK() OVER (ORDER BY avg_transaction_value DESC) as avg_value_rank,
    -- Performance tier
    CASE 
        WHEN RANK() OVER (ORDER BY total_revenue DESC) <= 10 THEN 'Top 10'
        WHEN RANK() OVER (ORDER BY total_revenue DESC) <= 50 THEN 'Top 50'
        WHEN RANK() OVER (ORDER BY total_revenue DESC) <= 100 THEN 'Top 100'
        ELSE 'Other'
    END as performance_tier
FROM store_metrics
WHERE transaction_count >= 10  -- Minimum threshold
ORDER BY revenue_rank;

-- Product Insights
CREATE OR REPLACE VIEW scout_gold.product_insights AS
WITH product_metrics AS (
    SELECT 
        payload->>'product_category' as product_category,
        payload->>'brand_name' as brand_name,
        payload->>'sku' as sku,
        COUNT(*) as purchase_count,
        SUM((payload->>'units_per_transaction')::INTEGER) as total_units,
        SUM((payload->>'peso_value')::NUMERIC) as total_revenue,
        AVG((payload->>'peso_value')::NUMERIC) as avg_price,
        COUNT(DISTINCT payload->>'store_id') as store_distribution,
        COUNT(DISTINCT payload->>'customer_id') as unique_buyers,
        -- TBWA client flag
        BOOL_OR((payload->>'is_tbwa_client')::BOOLEAN) as is_tbwa_client,
        -- Substitution analysis
        COUNT(*) FILTER (WHERE payload ? 'substitution_event') as substitution_count,
        -- Campaign effectiveness
        COUNT(*) FILTER (WHERE (payload->>'campaign_influenced')::BOOLEAN) as campaign_influenced_purchases
    FROM scout.bronze_edge_raw
    WHERE payload ? 'product_category' 
        AND payload ? 'brand_name'
        AND captured_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY payload->>'product_category', payload->>'brand_name', payload->>'sku'
)
SELECT 
    product_category,
    brand_name,
    sku,
    purchase_count,
    total_units,
    ROUND(total_revenue, 2) as total_revenue,
    ROUND(avg_price, 2) as avg_price,
    store_distribution,
    unique_buyers,
    is_tbwa_client,
    ROUND(100.0 * substitution_count / NULLIF(purchase_count, 0), 1) as substitution_rate,
    ROUND(100.0 * campaign_influenced_purchases / NULLIF(purchase_count, 0), 1) as campaign_influence_rate,
    -- Market share within category
    ROUND(100.0 * total_revenue / SUM(total_revenue) OVER (PARTITION BY product_category), 2) as category_revenue_share,
    -- Rankings
    RANK() OVER (PARTITION BY product_category ORDER BY total_revenue DESC) as category_rank,
    RANK() OVER (ORDER BY total_revenue DESC) as overall_rank
FROM product_metrics
WHERE purchase_count >= 5  -- Minimum threshold
ORDER BY total_revenue DESC;

-- Customer Segments
CREATE OR REPLACE VIEW scout_gold.customer_segments AS
WITH customer_behavior AS (
    SELECT 
        payload->>'customer_id' as customer_id,
        payload->>'gender' as gender,
        payload->>'age_bracket' as age_bracket,
        payload->>'economic_class' as economic_class,
        COUNT(*) as transaction_count,
        SUM((payload->>'peso_value')::NUMERIC) as total_spent,
        AVG((payload->>'peso_value')::NUMERIC) as avg_transaction_value,
        AVG((payload->>'basket_size')::INTEGER) as avg_basket_size,
        COUNT(DISTINCT DATE(captured_at)) as shopping_days,
        COUNT(DISTINCT payload->>'store_id') as stores_visited,
        -- Behavior patterns
        MODE() WITHIN GROUP (ORDER BY payload->>'payment_method') as preferred_payment,
        MODE() WITHIN GROUP (ORDER BY payload->>'request_mode') as preferred_request_mode,
        AVG(CASE WHEN (payload->>'suggestion_accepted')::BOOLEAN THEN 1 ELSE 0 END) * 100 as suggestion_acceptance_rate,
        -- Recency
        MAX(captured_at) as last_purchase_date,
        CURRENT_DATE - MAX(captured_at)::DATE as days_since_last_purchase
    FROM scout.bronze_edge_raw
    WHERE payload ? 'customer_id'
        AND payload->>'customer_id' != ''
    GROUP BY payload->>'customer_id', payload->>'gender', payload->>'age_bracket', payload->>'economic_class'
)
SELECT 
    customer_id,
    gender,
    age_bracket,
    economic_class,
    transaction_count,
    ROUND(total_spent, 2) as total_spent,
    ROUND(avg_transaction_value, 2) as avg_transaction_value,
    ROUND(avg_basket_size, 2) as avg_basket_size,
    shopping_days,
    stores_visited,
    preferred_payment,
    preferred_request_mode,
    ROUND(suggestion_acceptance_rate, 1) as suggestion_acceptance_rate,
    last_purchase_date,
    days_since_last_purchase,
    -- Customer value tier
    CASE 
        WHEN total_spent >= 10000 THEN 'VIP'
        WHEN total_spent >= 5000 THEN 'Premium'
        WHEN total_spent >= 1000 THEN 'Regular'
        ELSE 'Occasional'
    END as value_tier,
    -- Activity status
    CASE 
        WHEN days_since_last_purchase <= 7 THEN 'Active'
        WHEN days_since_last_purchase <= 30 THEN 'Recent'
        WHEN days_since_last_purchase <= 90 THEN 'Lapsing'
        ELSE 'Inactive'
    END as activity_status,
    -- Engagement level
    CASE 
        WHEN suggestion_acceptance_rate >= 70 THEN 'High'
        WHEN suggestion_acceptance_rate >= 40 THEN 'Medium'
        ELSE 'Low'
    END as engagement_level
FROM customer_behavior
ORDER BY total_spent DESC;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_bronze_captured_at ON scout.bronze_edge_raw(captured_at);
CREATE INDEX IF NOT EXISTS idx_bronze_device_id ON scout.bronze_edge_raw(device_id);
CREATE INDEX IF NOT EXISTS idx_bronze_payload_store ON scout.bronze_edge_raw((payload->>'store_id'));
CREATE INDEX IF NOT EXISTS idx_bronze_payload_customer ON scout.bronze_edge_raw((payload->>'customer_id'));

-- Update medallion metadata
SELECT scout.update_medallion_metadata(
    'gold',
    'daily_transactions',
    'scout.bronze_edge_raw',
    'aggregation',
    (SELECT COUNT(*) FROM scout_gold.daily_transactions),
    100.0,
    NULL
);

SELECT scout.update_medallion_metadata(
    'gold',
    'store_rankings',
    'scout.bronze_edge_raw',
    'ranking',
    (SELECT COUNT(*) FROM scout_gold.store_rankings),
    100.0,
    NULL
);

-- Grant permissions
GRANT SELECT ON ALL TABLES IN SCHEMA scout_gold TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA scout_gold TO anon;