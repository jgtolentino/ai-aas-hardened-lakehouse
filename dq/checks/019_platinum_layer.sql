-- ============================================================================
-- Scout Platinum Layer - ML Features and AI-Ready Exports
-- Time series features, embeddings, and specialized datasets
-- ============================================================================

-- Create platinum tables for persistent ML features
CREATE TABLE IF NOT EXISTS scout_platinum.store_features (
    store_id TEXT PRIMARY KEY,
    region TEXT,
    city TEXT,
    -- Time series features (7-day, 30-day, 90-day windows)
    transactions_7d INTEGER,
    transactions_30d INTEGER,
    transactions_90d INTEGER,
    revenue_7d NUMERIC,
    revenue_30d NUMERIC,
    revenue_90d NUMERIC,
    -- Growth rates
    revenue_growth_7d_pct NUMERIC,
    revenue_growth_30d_pct NUMERIC,
    -- Customer diversity
    unique_customers_30d INTEGER,
    customer_retention_rate NUMERIC,
    new_customer_rate NUMERIC,
    -- Product mix
    top_category TEXT,
    category_diversity_score NUMERIC,
    tbwa_brand_revenue_share NUMERIC,
    -- Engagement scores
    avg_basket_size_30d NUMERIC,
    avg_transaction_value_30d NUMERIC,
    suggestion_acceptance_rate NUMERIC,
    digital_payment_rate NUMERIC,
    -- Operational patterns
    peak_hour INTEGER,
    weekend_revenue_share NUMERIC,
    consistency_score NUMERIC,
    -- ML predictions
    revenue_forecast_next_7d NUMERIC,
    churn_probability NUMERIC,
    growth_potential_score NUMERIC,
    -- Metadata
    features_computed_at TIMESTAMPTZ DEFAULT NOW(),
    model_version TEXT DEFAULT 'v1.0'
);

CREATE TABLE IF NOT EXISTS scout_platinum.customer_features (
    customer_id TEXT PRIMARY KEY,
    -- Demographics
    gender TEXT,
    age_bracket TEXT,
    economic_class TEXT,
    -- Behavioral features
    lifetime_value NUMERIC,
    transaction_frequency NUMERIC,
    avg_days_between_purchases NUMERIC,
    preferred_payment_method TEXT,
    preferred_shopping_time TEXT,
    -- Product preferences
    top_category TEXT,
    top_brand TEXT,
    category_diversity_score NUMERIC,
    brand_loyalty_score NUMERIC,
    -- Engagement
    voice_usage_rate NUMERIC,
    suggestion_acceptance_rate NUMERIC,
    substitution_acceptance_rate NUMERIC,
    -- Recency/Frequency/Monetary
    recency_days INTEGER,
    frequency_30d INTEGER,
    monetary_30d NUMERIC,
    rfm_segment TEXT,
    -- Predictive scores
    churn_probability NUMERIC,
    next_purchase_days INTEGER,
    upsell_probability NUMERIC,
    -- Embeddings (for similarity/recommendation)
    preference_embedding VECTOR(128),
    -- Metadata
    features_computed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS scout_platinum.product_features (
    sku TEXT PRIMARY KEY,
    product_category TEXT,
    brand_name TEXT,
    is_tbwa_client BOOLEAN,
    -- Sales velocity
    units_sold_7d INTEGER,
    units_sold_30d INTEGER,
    revenue_7d NUMERIC,
    revenue_30d NUMERIC,
    -- Market position
    category_rank INTEGER,
    market_share_pct NUMERIC,
    growth_rate_30d NUMERIC,
    -- Distribution
    store_coverage_pct NUMERIC,
    regional_concentration JSONB,
    -- Customer base
    unique_buyers_30d INTEGER,
    repeat_purchase_rate NUMERIC,
    avg_basket_correlation NUMERIC,
    -- Substitution patterns
    substitution_rate NUMERIC,
    top_substitute_skus TEXT[],
    -- Price elasticity
    avg_price NUMERIC,
    price_variance NUMERIC,
    price_elasticity_score NUMERIC,
    -- Campaign effectiveness
    campaign_lift_pct NUMERIC,
    promo_sensitivity_score NUMERIC,
    -- Trend indicators
    seasonality_score NUMERIC,
    trend_direction TEXT,
    inventory_turnover NUMERIC,
    -- Metadata
    features_computed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Time series features for forecasting
CREATE TABLE IF NOT EXISTS scout_platinum.time_series_features (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    entity_type TEXT NOT NULL, -- 'store', 'product', 'region'
    entity_id TEXT NOT NULL,
    date DATE NOT NULL,
    -- Core metrics
    transactions INTEGER,
    revenue NUMERIC,
    units_sold INTEGER,
    unique_customers INTEGER,
    -- Derived features
    day_of_week INTEGER,
    week_of_month INTEGER,
    month_of_year INTEGER,
    is_weekend BOOLEAN,
    is_holiday BOOLEAN,
    -- Lag features
    revenue_lag_1d NUMERIC,
    revenue_lag_7d NUMERIC,
    revenue_lag_30d NUMERIC,
    -- Moving averages
    revenue_ma_7d NUMERIC,
    revenue_ma_30d NUMERIC,
    -- Growth rates
    revenue_growth_wow NUMERIC,
    revenue_growth_mom NUMERIC,
    -- External factors
    weather_temp NUMERIC,
    weather_precipitation NUMERIC,
    local_events INTEGER,
    competitor_promo BOOLEAN,
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(entity_type, entity_id, date)
);

-- GenieView export format (for AI assistant)
CREATE TABLE IF NOT EXISTS scout_platinum.genie_exports (
    export_id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    export_type TEXT NOT NULL, -- 'daily_summary', 'anomaly_alert', 'forecast'
    export_date DATE NOT NULL,
    -- Structured data for LLM consumption
    metrics_summary JSONB NOT NULL,
    insights JSONB NOT NULL,
    recommendations JSONB NOT NULL,
    natural_language_summary TEXT,
    -- Visualization data
    chart_configs JSONB,
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    processed BOOLEAN DEFAULT false
);

-- ChartVision export format (for visualization)
CREATE TABLE IF NOT EXISTS scout_platinum.chartvision_exports (
    export_id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    chart_type TEXT NOT NULL, -- 'line', 'bar', 'scatter', 'heatmap'
    title TEXT NOT NULL,
    subtitle TEXT,
    -- Data specification
    x_axis_data JSONB NOT NULL,
    y_axis_data JSONB NOT NULL,
    series_config JSONB NOT NULL,
    -- Styling
    color_scheme TEXT,
    interactive_elements JSONB,
    -- React component export
    tsx_component TEXT,
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create functions to compute ML features

-- Store features computation
CREATE OR REPLACE FUNCTION scout_platinum.compute_store_features()
RETURNS void AS $$
BEGIN
    INSERT INTO scout_platinum.store_features (
        store_id, region, city,
        transactions_7d, transactions_30d, transactions_90d,
        revenue_7d, revenue_30d, revenue_90d,
        revenue_growth_7d_pct, revenue_growth_30d_pct,
        unique_customers_30d, customer_retention_rate,
        top_category, category_diversity_score,
        tbwa_brand_revenue_share,
        avg_basket_size_30d, avg_transaction_value_30d,
        suggestion_acceptance_rate, digital_payment_rate,
        peak_hour, weekend_revenue_share, consistency_score
    )
    WITH store_base AS (
        SELECT DISTINCT 
            payload->>'store_id' as store_id,
            payload->'location'->>'region' as region,
            payload->'location'->>'city' as city
        FROM scout.bronze_edge_raw
        WHERE payload ? 'store_id'
    ),
    store_metrics AS (
        SELECT 
            s.store_id,
            s.region,
            s.city,
            -- Transaction counts
            COUNT(*) FILTER (WHERE b.captured_at >= CURRENT_DATE - INTERVAL '7 days') as transactions_7d,
            COUNT(*) FILTER (WHERE b.captured_at >= CURRENT_DATE - INTERVAL '30 days') as transactions_30d,
            COUNT(*) FILTER (WHERE b.captured_at >= CURRENT_DATE - INTERVAL '90 days') as transactions_90d,
            -- Revenue
            SUM((b.payload->>'peso_value')::NUMERIC) FILTER (WHERE b.captured_at >= CURRENT_DATE - INTERVAL '7 days') as revenue_7d,
            SUM((b.payload->>'peso_value')::NUMERIC) FILTER (WHERE b.captured_at >= CURRENT_DATE - INTERVAL '30 days') as revenue_30d,
            SUM((b.payload->>'peso_value')::NUMERIC) FILTER (WHERE b.captured_at >= CURRENT_DATE - INTERVAL '90 days') as revenue_90d,
            -- Previous period revenue for growth calculation
            SUM((b.payload->>'peso_value')::NUMERIC) FILTER (WHERE b.captured_at >= CURRENT_DATE - INTERVAL '14 days' AND b.captured_at < CURRENT_DATE - INTERVAL '7 days') as revenue_prev_7d,
            SUM((b.payload->>'peso_value')::NUMERIC) FILTER (WHERE b.captured_at >= CURRENT_DATE - INTERVAL '60 days' AND b.captured_at < CURRENT_DATE - INTERVAL '30 days') as revenue_prev_30d,
            -- Customer metrics
            COUNT(DISTINCT b.payload->>'customer_id') FILTER (WHERE b.captured_at >= CURRENT_DATE - INTERVAL '30 days') as unique_customers_30d,
            -- Category analysis
            MODE() WITHIN GROUP (ORDER BY b.payload->>'product_category') FILTER (WHERE b.captured_at >= CURRENT_DATE - INTERVAL '30 days') as top_category,
            COUNT(DISTINCT b.payload->>'product_category') FILTER (WHERE b.captured_at >= CURRENT_DATE - INTERVAL '30 days')::NUMERIC as category_count,
            -- TBWA brand share
            SUM((b.payload->>'peso_value')::NUMERIC) FILTER (WHERE (b.payload->>'is_tbwa_client')::BOOLEAN AND b.captured_at >= CURRENT_DATE - INTERVAL '30 days') as tbwa_revenue,
            -- Engagement metrics
            AVG((b.payload->>'basket_size')::INTEGER) FILTER (WHERE b.captured_at >= CURRENT_DATE - INTERVAL '30 days') as avg_basket_size_30d,
            AVG((b.payload->>'peso_value')::NUMERIC) FILTER (WHERE b.captured_at >= CURRENT_DATE - INTERVAL '30 days') as avg_transaction_value_30d,
            AVG(CASE WHEN (b.payload->>'suggestion_accepted')::BOOLEAN THEN 1 ELSE 0 END) FILTER (WHERE b.captured_at >= CURRENT_DATE - INTERVAL '30 days') * 100 as suggestion_acceptance_rate,
            AVG(CASE WHEN b.payload->>'payment_method' IN ('gcash', 'card') THEN 1 ELSE 0 END) FILTER (WHERE b.captured_at >= CURRENT_DATE - INTERVAL '30 days') * 100 as digital_payment_rate,
            -- Peak hour
            MODE() WITHIN GROUP (ORDER BY EXTRACT(HOUR FROM b.captured_at)) FILTER (WHERE b.captured_at >= CURRENT_DATE - INTERVAL '30 days') as peak_hour,
            -- Weekend share
            SUM((b.payload->>'peso_value')::NUMERIC) FILTER (WHERE EXTRACT(DOW FROM b.captured_at) IN (0,6) AND b.captured_at >= CURRENT_DATE - INTERVAL '30 days') as weekend_revenue,
            -- Active days for consistency
            COUNT(DISTINCT DATE(b.captured_at)) FILTER (WHERE b.captured_at >= CURRENT_DATE - INTERVAL '30 days') as active_days_30d
        FROM store_base s
        LEFT JOIN scout.bronze_edge_raw b ON b.payload->>'store_id' = s.store_id
        GROUP BY s.store_id, s.region, s.city
    )
    SELECT 
        store_id,
        region,
        city,
        COALESCE(transactions_7d, 0),
        COALESCE(transactions_30d, 0),
        COALESCE(transactions_90d, 0),
        COALESCE(revenue_7d, 0),
        COALESCE(revenue_30d, 0),
        COALESCE(revenue_90d, 0),
        -- Growth calculations
        ROUND(CASE 
            WHEN COALESCE(revenue_prev_7d, 0) > 0 
            THEN ((revenue_7d - revenue_prev_7d) / revenue_prev_7d * 100)
            ELSE 0 
        END, 2),
        ROUND(CASE 
            WHEN COALESCE(revenue_prev_30d, 0) > 0 
            THEN ((revenue_30d - revenue_prev_30d) / revenue_prev_30d * 100)
            ELSE 0 
        END, 2),
        COALESCE(unique_customers_30d, 0),
        0.0, -- customer_retention_rate (placeholder for now)
        top_category,
        ROUND(LOG(category_count + 1) * 20, 2), -- diversity score
        ROUND(COALESCE(tbwa_revenue / NULLIF(revenue_30d, 0) * 100, 0), 2),
        ROUND(avg_basket_size_30d, 2),
        ROUND(avg_transaction_value_30d, 2),
        ROUND(suggestion_acceptance_rate, 2),
        ROUND(digital_payment_rate, 2),
        peak_hour::INTEGER,
        ROUND(COALESCE(weekend_revenue / NULLIF(revenue_30d, 0) * 100, 0), 2),
        ROUND(active_days_30d * 100.0 / 30, 2) -- consistency score
    FROM store_metrics
    ON CONFLICT (store_id) DO UPDATE SET
        region = EXCLUDED.region,
        city = EXCLUDED.city,
        transactions_7d = EXCLUDED.transactions_7d,
        transactions_30d = EXCLUDED.transactions_30d,
        transactions_90d = EXCLUDED.transactions_90d,
        revenue_7d = EXCLUDED.revenue_7d,
        revenue_30d = EXCLUDED.revenue_30d,
        revenue_90d = EXCLUDED.revenue_90d,
        revenue_growth_7d_pct = EXCLUDED.revenue_growth_7d_pct,
        revenue_growth_30d_pct = EXCLUDED.revenue_growth_30d_pct,
        unique_customers_30d = EXCLUDED.unique_customers_30d,
        customer_retention_rate = EXCLUDED.customer_retention_rate,
        top_category = EXCLUDED.top_category,
        category_diversity_score = EXCLUDED.category_diversity_score,
        tbwa_brand_revenue_share = EXCLUDED.tbwa_brand_revenue_share,
        avg_basket_size_30d = EXCLUDED.avg_basket_size_30d,
        avg_transaction_value_30d = EXCLUDED.avg_transaction_value_30d,
        suggestion_acceptance_rate = EXCLUDED.suggestion_acceptance_rate,
        digital_payment_rate = EXCLUDED.digital_payment_rate,
        peak_hour = EXCLUDED.peak_hour,
        weekend_revenue_share = EXCLUDED.weekend_revenue_share,
        consistency_score = EXCLUDED.consistency_score,
        features_computed_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_platinum_store_features_store ON scout_platinum.store_features(store_id);
CREATE INDEX IF NOT EXISTS idx_platinum_customer_features_customer ON scout_platinum.customer_features(customer_id);
CREATE INDEX IF NOT EXISTS idx_platinum_product_features_sku ON scout_platinum.product_features(sku);
CREATE INDEX IF NOT EXISTS idx_platinum_time_series_entity ON scout_platinum.time_series_features(entity_type, entity_id, date);

-- Grant permissions
GRANT SELECT ON ALL TABLES IN SCHEMA scout_platinum TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA scout_platinum TO service_role;

-- Update medallion metadata
SELECT scout.update_medallion_metadata(
    'platinum',
    'store_features',
    'scout.bronze_edge_raw',
    'ml_features',
    (SELECT COUNT(*) FROM scout_platinum.store_features),
    100.0,
    NULL
);

-- Create a sample GenieView export
INSERT INTO scout_platinum.genie_exports (
    export_type,
    export_date,
    metrics_summary,
    insights,
    recommendations,
    natural_language_summary
) VALUES (
    'daily_summary',
    CURRENT_DATE,
    jsonb_build_object(
        'total_revenue', 125000,
        'transaction_count', 450,
        'active_stores', 25,
        'growth_rate', 5.2
    ),
    jsonb_build_object(
        'top_insight', 'Digital payment adoption increased by 15%',
        'anomaly', 'Unusual spike in evening transactions at Store #12'
    ),
    jsonb_build_object(
        'action_1', 'Increase GCash promotion in stores with low digital adoption',
        'action_2', 'Investigate evening demand at high-performing stores'
    ),
    'Today''s performance shows strong growth with 450 transactions generating ₱125,000 in revenue across 25 active stores. Digital payment adoption continues to rise, suggesting successful modernization efforts.'
);