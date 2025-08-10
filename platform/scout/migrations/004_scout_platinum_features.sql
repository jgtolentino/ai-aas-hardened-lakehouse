-- Scout Data Model: Platinum Layer (ML Features)
-- Feature store for recommendations and predictive models

BEGIN;

-- 1) ROLLING WINDOW FEATURES (7d, 28d aggregates)
CREATE MATERIALIZED VIEW scout.platinum_features_sales_7d AS
WITH daily_sales AS (
    SELECT 
        date_trunc('day', ts) AS day,
        region,
        product_category,
        brand_name,
        SUM(peso_value) AS daily_revenue,
        COUNT(DISTINCT id) AS daily_transactions,
        AVG(basket_size) AS avg_basket_size,
        SUM(units_per_transaction) AS total_units
    FROM scout.silver_transactions
    WHERE ts >= CURRENT_DATE - INTERVAL '14 days'
    GROUP BY 1,2,3,4
)
SELECT 
    day,
    region,
    product_category,
    brand_name,
    daily_revenue,
    daily_transactions,
    -- 7-day rolling features
    AVG(daily_revenue) OVER w7 AS revenue_7d_avg,
    SUM(daily_revenue) OVER w7 AS revenue_7d_sum,
    STDDEV(daily_revenue) OVER w7 AS revenue_7d_stddev,
    MAX(daily_revenue) OVER w7 AS revenue_7d_max,
    MIN(daily_revenue) OVER w7 AS revenue_7d_min,
    AVG(daily_transactions) OVER w7 AS transactions_7d_avg,
    AVG(avg_basket_size) OVER w7 AS basket_size_7d_avg,
    -- Trend indicators
    CASE 
        WHEN LAG(daily_revenue, 7) OVER (PARTITION BY region, product_category, brand_name ORDER BY day) > 0
        THEN daily_revenue / LAG(daily_revenue, 7) OVER (PARTITION BY region, product_category, brand_name ORDER BY day) - 1
        ELSE NULL 
    END AS revenue_wow_growth,
    -- Rank features
    RANK() OVER (PARTITION BY day, region ORDER BY daily_revenue DESC) AS revenue_rank_in_region,
    PERCENT_RANK() OVER (PARTITION BY day, product_category ORDER BY daily_revenue DESC) AS revenue_percentile_in_category
FROM daily_sales
WINDOW w7 AS (PARTITION BY region, product_category, brand_name ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW);

CREATE UNIQUE INDEX idx_platinum_sales_7d ON scout.platinum_features_sales_7d(day, region, product_category, brand_name);

-- 2) STORE PERFORMANCE FEATURES
CREATE MATERIALIZED VIEW scout.platinum_features_store_performance AS
WITH store_metrics AS (
    SELECT 
        st.store_id,
        date_trunc('day', st.ts) AS day,
        COUNT(DISTINCT st.id) AS daily_transactions,
        SUM(st.peso_value) AS daily_revenue,
        AVG(st.basket_size) AS avg_basket_size,
        AVG(st.duration_seconds) AS avg_duration,
        AVG(st.handshake_score) AS avg_handshake,
        SUM(CASE WHEN st.suggestion_accepted THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*), 0) AS acceptance_rate,
        COUNT(DISTINCT st.sku) AS unique_skus_sold,
        COUNT(DISTINCT st.brand_name) AS unique_brands_sold
    FROM scout.silver_transactions st
    WHERE st.ts >= CURRENT_DATE - INTERVAL '35 days'
    GROUP BY 1,2
)
SELECT 
    store_id,
    day,
    daily_transactions,
    daily_revenue,
    -- Rolling features
    AVG(daily_revenue) OVER w7 AS revenue_7d_avg,
    AVG(daily_revenue) OVER w28 AS revenue_28d_avg,
    STDDEV(daily_revenue) OVER w7 AS revenue_7d_volatility,
    AVG(acceptance_rate) OVER w7 AS acceptance_rate_7d,
    -- Store vitality score (composite metric)
    (
        0.3 * (daily_revenue / NULLIF(AVG(daily_revenue) OVER w28, 0)) +
        0.2 * (daily_transactions / NULLIF(AVG(daily_transactions) OVER w28, 0)) +
        0.2 * (unique_skus_sold / NULLIF(AVG(unique_skus_sold) OVER w28, 0)) +
        0.2 * acceptance_rate +
        0.1 * avg_handshake
    ) AS vitality_score
FROM store_metrics
WINDOW 
    w7 AS (PARTITION BY store_id ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),
    w28 AS (PARTITION BY store_id ORDER BY day ROWS BETWEEN 27 PRECEDING AND CURRENT ROW);

CREATE INDEX idx_platinum_store_perf ON scout.platinum_features_store_performance(store_id, day DESC);

-- 3) CUSTOMER SEGMENT FEATURES
CREATE MATERIALIZED VIEW scout.platinum_features_customer_segments AS
WITH segment_behavior AS (
    SELECT 
        gender,
        age_bracket,
        customer_type,
        economic_class,
        product_category,
        date_trunc('week', ts) AS week,
        COUNT(DISTINCT id) AS transaction_count,
        AVG(peso_value) AS avg_spend,
        AVG(basket_size) AS avg_basket,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY peso_value) AS median_spend,
        SUM(CASE WHEN campaign_influenced THEN 1 ELSE 0 END)::numeric / COUNT(*) AS campaign_responsiveness,
        AVG(handshake_score) AS avg_engagement
    FROM scout.silver_transactions
    WHERE ts >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY 1,2,3,4,5,6
)
SELECT 
    gender,
    age_bracket,
    customer_type,
    economic_class,
    product_category,
    week,
    transaction_count,
    avg_spend,
    avg_basket,
    median_spend,
    campaign_responsiveness,
    avg_engagement,
    -- Segment value score
    NTILE(10) OVER (PARTITION BY week ORDER BY avg_spend * transaction_count) AS value_decile,
    -- Behavioral clustering features
    avg_spend / NULLIF(AVG(avg_spend) OVER (PARTITION BY product_category), 0) AS spend_index,
    avg_basket / NULLIF(AVG(avg_basket) OVER (PARTITION BY economic_class), 0) AS basket_index
FROM segment_behavior;

CREATE INDEX idx_platinum_segments ON scout.platinum_features_customer_segments(week, gender, age_bracket, economic_class);

-- 4) RECOMMENDATION CANDIDATES (top items by context)
CREATE MATERIALIZED VIEW scout.platinum_recommendation_candidates AS
WITH contextual_popularity AS (
    SELECT 
        st.region,
        st.barangay,
        st.time_of_day,
        st.gender,
        st.age_bracket,
        st.sku,
        ds.product_name,
        ds.brand_name,
        ds.category,
        COUNT(DISTINCT st.id) AS purchase_count,
        SUM(st.units_per_transaction) AS total_units,
        AVG(st.peso_value) AS avg_transaction_value,
        COUNT(DISTINCT st.store_id) AS store_coverage,
        MAX(st.ts) AS last_purchased
    FROM scout.silver_transactions st
    JOIN scout.dim_sku ds ON st.sku = ds.sku
    WHERE st.ts >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY 1,2,3,4,5,6,7,8,9
),
ranked AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY region, time_of_day, gender, age_bracket, category ORDER BY purchase_count DESC) AS rank_in_context,
        purchase_count::numeric / SUM(purchase_count) OVER (PARTITION BY region, time_of_day, gender, age_bracket) AS context_share
    FROM contextual_popularity
)
SELECT * FROM ranked WHERE rank_in_context <= 20;

CREATE INDEX idx_platinum_recommendations ON scout.platinum_recommendation_candidates(region, time_of_day, gender, age_bracket, category, rank_in_context);

-- 5) AI PANEL METRICS (for recommendation panel)
CREATE OR REPLACE VIEW scout.platinum_ai_panel_metrics AS
WITH recent_performance AS (
    SELECT 
        region,
        product_category,
        brand_name,
        SUM(peso_value) AS revenue_today,
        COUNT(DISTINCT id) AS transactions_today,
        AVG(basket_size) AS avg_basket_today,
        AVG(duration_seconds) AS avg_duration_today
    FROM scout.silver_transactions
    WHERE ts >= CURRENT_DATE
    GROUP BY 1,2,3
),
trending AS (
    SELECT 
        region,
        product_category,
        brand_name,
        revenue_7d_avg,
        revenue_wow_growth,
        revenue_rank_in_region
    FROM scout.platinum_features_sales_7d
    WHERE day = CURRENT_DATE - 1
),
substitution_impact AS (
    SELECT 
        to_brand AS gaining_brand,
        from_brand AS losing_brand,
        SUM(substitution_count) AS substitution_volume
    FROM scout.gold_substitution_flows
    GROUP BY 1,2
)
SELECT 
    rp.region,
    rp.product_category,
    rp.brand_name,
    rp.revenue_today,
    rp.transactions_today,
    rp.avg_basket_today,
    t.revenue_7d_avg,
    t.revenue_wow_growth,
    t.revenue_rank_in_region,
    COALESCE(si_gain.substitution_volume, 0) AS substitutions_gained,
    COALESCE(si_loss.substitution_volume, 0) AS substitutions_lost,
    -- Momentum score for AI recommendations
    CASE 
        WHEN t.revenue_wow_growth > 0.1 AND t.revenue_rank_in_region <= 5 THEN 'HIGH_MOMENTUM'
        WHEN t.revenue_wow_growth > 0 THEN 'GROWING'
        WHEN t.revenue_wow_growth < -0.1 THEN 'DECLINING'
        ELSE 'STABLE'
    END AS momentum_status
FROM recent_performance rp
LEFT JOIN trending t ON rp.region = t.region 
    AND rp.product_category = t.product_category 
    AND rp.brand_name = t.brand_name
LEFT JOIN substitution_impact si_gain ON rp.brand_name = si_gain.gaining_brand
LEFT JOIN substitution_impact si_loss ON rp.brand_name = si_loss.losing_brand;

-- 6) Refresh function for platinum features
CREATE OR REPLACE FUNCTION scout.refresh_platinum_features()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY scout.platinum_features_sales_7d;
    REFRESH MATERIALIZED VIEW CONCURRENTLY scout.platinum_features_store_performance;
    REFRESH MATERIALIZED VIEW CONCURRENTLY scout.platinum_features_customer_segments;
    REFRESH MATERIALIZED VIEW CONCURRENTLY scout.platinum_recommendation_candidates;
END;
$$ LANGUAGE plpgsql;

COMMIT;