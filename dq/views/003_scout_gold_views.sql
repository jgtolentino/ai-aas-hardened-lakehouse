-- Scout Data Model: Gold Layer (Business Intelligence Views)
-- Optimized for the exact dashboard requirements

BEGIN;

-- 1) TRANSACTION TRENDS (time series, geo breakdown)
CREATE MATERIALIZED VIEW scout.gold_txn_daily AS
SELECT 
    date_trunc('day', ts) AS day,
    time_of_day,
    region,
    province,
    city,
    barangay,
    product_category,
    brand_name,
    store_type,
    economic_class,
    COUNT(DISTINCT id) AS transaction_count,
    COUNT(DISTINCT store_id) AS unique_stores,
    SUM(units_per_transaction) AS total_units,
    SUM(peso_value) AS total_peso,
    AVG(peso_value) AS avg_transaction_value,
    AVG(basket_size) AS avg_basket_size,
    AVG(duration_seconds) AS avg_duration_seconds,
    COUNT(DISTINCT CASE WHEN is_tbwa_client THEN brand_name END) AS tbwa_brands,
    SUM(CASE WHEN suggestion_accepted THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0) AS suggestion_acceptance_rate
FROM scout.silver_transactions
GROUP BY 1,2,3,4,5,6,7,8,9,10;

CREATE UNIQUE INDEX idx_gold_txn_daily ON scout.gold_txn_daily(day, time_of_day, region, barangay, product_category, brand_name);

-- 2) PRODUCT MIX & TOP SKUS
CREATE MATERIALIZED VIEW scout.gold_product_mix AS
WITH sku_stats AS (
    SELECT 
        st.product_category,
        st.brand_name,
        st.sku,
        ds.product_name,
        COUNT(DISTINCT st.id) AS transaction_count,
        SUM(st.units_per_transaction) AS total_units,
        SUM(st.peso_value) AS total_revenue,
        AVG(st.peso_value) AS avg_price,
        COUNT(DISTINCT st.store_id) AS store_coverage,
        COUNT(DISTINCT st.barangay) AS barangay_coverage
    FROM scout.silver_transactions st
    JOIN scout.dim_sku ds ON st.sku = ds.sku
    GROUP BY 1,2,3,4
),
ranked AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY product_category ORDER BY total_revenue DESC) AS rank_in_category,
        SUM(total_revenue) OVER (PARTITION BY product_category ORDER BY total_revenue DESC) AS running_revenue,
        SUM(total_revenue) OVER (PARTITION BY product_category) AS category_revenue
    FROM sku_stats
)
SELECT 
    *,
    running_revenue / NULLIF(category_revenue, 0) AS revenue_cumulative_pct,
    CASE WHEN running_revenue / NULLIF(category_revenue, 0) <= 0.8 THEN true ELSE false END AS is_pareto_80
FROM ranked;

CREATE INDEX idx_gold_product_mix ON scout.gold_product_mix(product_category, rank_in_category);

-- 3) BASKET PATTERNS (co-occurrence, affinity)
CREATE MATERIALIZED VIEW scout.gold_basket_patterns AS
WITH basket_pairs AS (
    SELECT 
        a.id,
        a.sku AS sku_a,
        b.sku AS sku_b,
        st.ts::date AS date,
        st.region,
        st.product_category
    FROM scout.silver_combo_items a
    JOIN scout.silver_combo_items b ON a.id = b.id AND a.position < b.position
    JOIN scout.silver_transactions st ON a.id = st.id
),
pair_stats AS (
    SELECT 
        sku_a,
        sku_b,
        COUNT(DISTINCT id) AS co_occurrence_count,
        COUNT(DISTINCT date) AS days_seen_together
    FROM basket_pairs
    GROUP BY 1,2
),
sku_frequency AS (
    SELECT 
        sku,
        COUNT(DISTINCT id) AS total_transactions
    FROM scout.silver_combo_items
    GROUP BY 1
)
SELECT 
    ps.sku_a,
    ps.sku_b,
    da.product_name AS product_a,
    db.product_name AS product_b,
    ps.co_occurrence_count,
    fa.total_transactions AS transactions_a,
    fb.total_transactions AS transactions_b,
    ps.co_occurrence_count::numeric / NULLIF(fa.total_transactions, 0) AS confidence_a_to_b,
    ps.co_occurrence_count::numeric / NULLIF(fb.total_transactions, 0) AS confidence_b_to_a,
    ps.co_occurrence_count::numeric / NULLIF(LEAST(fa.total_transactions, fb.total_transactions), 0) AS lift
FROM pair_stats ps
JOIN sku_frequency fa ON ps.sku_a = fa.sku
JOIN sku_frequency fb ON ps.sku_b = fb.sku
JOIN scout.dim_sku da ON ps.sku_a = da.sku
JOIN scout.dim_sku db ON ps.sku_b = db.sku
WHERE ps.co_occurrence_count >= 10;

CREATE INDEX idx_gold_basket_patterns ON scout.gold_basket_patterns(lift DESC);

-- 4) SUBSTITUTION FLOWS (for Sankey diagram)
CREATE MATERIALIZED VIEW scout.gold_substitution_flows AS
SELECT 
    ss.from_sku,
    ss.to_sku,
    df.product_name AS from_product,
    dt.product_name AS to_product,
    df.brand_name AS from_brand,
    dt.brand_name AS to_brand,
    df.category AS from_category,
    dt.category AS to_category,
    ss.reason,
    COUNT(*) AS substitution_count,
    COUNT(DISTINCT st.store_id) AS stores_affected,
    COUNT(DISTINCT st.barangay) AS barangays_affected,
    AVG(st.peso_value) AS avg_transaction_value
FROM scout.silver_substitutions ss
JOIN scout.silver_transactions st ON ss.id = st.id
JOIN scout.dim_sku df ON ss.from_sku = df.sku
JOIN scout.dim_sku dt ON ss.to_sku = dt.sku
WHERE ss.occurred = true
GROUP BY 1,2,3,4,5,6,7,8,9;

CREATE INDEX idx_gold_substitution_flows ON scout.gold_substitution_flows(substitution_count DESC);

-- 5) REQUEST BEHAVIOR ANALYSIS
CREATE MATERIALIZED VIEW scout.gold_request_behavior AS
SELECT 
    date_trunc('day', ts) AS day,
    region,
    product_category,
    request_mode,
    request_type,
    COUNT(*) AS request_count,
    SUM(CASE WHEN suggestion_accepted THEN 1 ELSE 0 END) AS suggestions_accepted,
    AVG(CASE WHEN suggestion_accepted THEN 1 ELSE 0 END) AS acceptance_rate,
    AVG(handshake_score) AS avg_handshake_score,
    AVG(duration_seconds) AS avg_interaction_time
FROM scout.silver_transactions
GROUP BY 1,2,3,4,5;

CREATE INDEX idx_gold_request_behavior ON scout.gold_request_behavior(day, region, request_mode);

-- 6) DEMOGRAPHICS PROFILING
CREATE MATERIALIZED VIEW scout.gold_demographics AS
SELECT 
    date_trunc('week', ts) AS week,
    region,
    barangay,
    product_category,
    gender,
    age_bracket,
    customer_type,
    economic_class,
    COUNT(DISTINCT id) AS transaction_count,
    COUNT(DISTINCT store_id) AS unique_stores,
    SUM(peso_value) AS total_spend,
    AVG(peso_value) AS avg_transaction_value,
    AVG(basket_size) AS avg_basket_size,
    SUM(CASE WHEN campaign_influenced THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*), 0) AS campaign_influence_rate
FROM scout.silver_transactions
GROUP BY 1,2,3,4,5,6,7,8;

CREATE INDEX idx_gold_demographics ON scout.gold_demographics(week, region, gender, age_bracket);

-- 7) REFRESH FUNCTION FOR ALL GOLD VIEWS
CREATE OR REPLACE FUNCTION scout.refresh_gold_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_txn_daily;
    REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_product_mix;
    REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_basket_patterns;
    REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_substitution_flows;
    REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_request_behavior;
    REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_demographics;
END;
$$ LANGUAGE plpgsql;

-- Schedule refresh every 5 minutes (requires pg_cron extension)
-- SELECT cron.schedule('refresh-scout-gold', '*/5 * * * *', 'SELECT scout.refresh_gold_views()');

COMMIT;