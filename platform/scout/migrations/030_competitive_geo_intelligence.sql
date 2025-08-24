-- ============================================================
-- Migration 030: Competitive & Geographical Intelligence
-- Adds competitive analysis and geographical roll-up views
-- ============================================================

-- ============================================================
-- COMPETITIVE INTELLIGENCE VIEWS
-- ============================================================

-- Brand competitive share (30-day rolling)
CREATE OR REPLACE VIEW scout.gold_brand_competitive_30d AS
WITH date_filter AS (
    SELECT MAX(date_key) - INTERVAL '30 days' AS start_date
    FROM scout.dim_date
    WHERE date_key <= CURRENT_DATE
)
SELECT
    s.store_id,
    s.store_name,
    COALESCE(c.category_name, 'Uncategorized') AS category,
    COALESCE(b.brand_name, 'Unbranded') AS brand,
    COUNT(DISTINCT ft.transaction_id) AS transaction_count,
    SUM(fti.quantity) AS units,
    SUM(fti.line_amount) AS revenue,
    AVG(fti.unit_price) AS avg_price,
    -- Market share calculations
    100.0 * SUM(fti.quantity) / NULLIF(
        SUM(SUM(fti.quantity)) OVER (PARTITION BY s.store_id, c.category_name), 
        0
    ) AS share_units,
    100.0 * SUM(fti.line_amount) / NULLIF(
        SUM(SUM(fti.line_amount)) OVER (PARTITION BY s.store_id, c.category_name), 
        0
    ) AS share_revenue,
    -- Price index (vs category average)
    100.0 * AVG(fti.unit_price) / NULLIF(
        AVG(AVG(fti.unit_price)) OVER (PARTITION BY c.category_name), 
        0
    ) AS price_index,
    -- Growth metrics
    SUM(fti.line_amount) - LAG(SUM(fti.line_amount), 1, 0) OVER (
        PARTITION BY s.store_id, b.brand_id 
        ORDER BY s.store_id, b.brand_id
    ) AS revenue_growth_30d,
    MAX(CASE WHEN fti.discount_amount > 0 THEN TRUE ELSE FALSE END) AS has_promo
FROM scout.fact_transactions ft
JOIN scout.fact_transaction_items fti ON ft.transaction_id = fti.transaction_id
JOIN scout.dim_stores s ON ft.store_key = s.store_key
LEFT JOIN scout.dim_products p ON fti.sku = p.sku_code
LEFT JOIN scout.dim_brands b ON p.brand_id = b.brand_id
LEFT JOIN scout.dim_categories c ON p.category_id = c.category_id
CROSS JOIN date_filter df
WHERE ft.transaction_date >= df.start_date
GROUP BY 1, 2, 3, 4;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_gold_brand_competitive_30d 
ON scout.fact_transactions(transaction_date, store_key);

-- Substitution patterns for Sankey diagram
CREATE OR REPLACE VIEW scout.gold_substitution_sankey_30d AS
WITH substitution_base AS (
    -- Detect substitutions from STT detections + transaction patterns
    SELECT 
        c.category_name AS category,
        sd.brands_detected[1] AS requested_brand,
        COALESCE(b.brand_name, 'Unknown') AS purchased_brand,
        ft.transaction_id,
        ft.transaction_date,
        CASE 
            WHEN sd.brands_detected[1] != b.brand_name THEN 'substitution'
            ELSE 'match'
        END AS substitution_type,
        CASE 
            WHEN fti.quantity = 0 THEN 'stockout'
            WHEN fti.unit_price > LAG(fti.unit_price) OVER (PARTITION BY fti.sku ORDER BY ft.transaction_date) * 1.1 THEN 'price'
            ELSE 'preference'
        END AS reason
    FROM scout.stt_detections sd
    JOIN scout.fact_transactions ft ON sd.transaction_id = ft.transaction_id::VARCHAR
    JOIN scout.fact_transaction_items fti ON ft.transaction_id = fti.transaction_id
    LEFT JOIN scout.dim_products p ON fti.sku = p.sku_code
    LEFT JOIN scout.dim_brands b ON p.brand_id = b.brand_id
    LEFT JOIN scout.dim_categories c ON p.category_id = c.category_id
    WHERE sd.detected_at >= CURRENT_DATE - INTERVAL '30 days'
    AND array_length(sd.brands_detected, 1) > 0
)
SELECT 
    category,
    requested_brand AS from_brand,
    purchased_brand AS to_brand,
    COUNT(*) AS substitution_count,
    100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY category) AS percentage,
    reason,
    substitution_type
FROM substitution_base
WHERE substitution_type = 'substitution'
GROUP BY 1, 2, 3, 6, 7
ORDER BY category, substitution_count DESC;

-- Price elasticity by store cluster
CREATE OR REPLACE VIEW scout.gold_price_elasticity AS
WITH price_quantity_changes AS (
    SELECT 
        sc.cluster_name AS store_cluster,
        b.brand_name AS brand,
        p.sku_code,
        ft.transaction_date,
        AVG(fti.unit_price) AS avg_price,
        SUM(fti.quantity) AS total_quantity,
        LAG(AVG(fti.unit_price)) OVER w AS prev_price,
        LAG(SUM(fti.quantity)) OVER w AS prev_quantity
    FROM scout.fact_transactions ft
    JOIN scout.fact_transaction_items fti ON ft.transaction_id = fti.transaction_id
    JOIN scout.dim_stores s ON ft.store_key = s.store_key
    LEFT JOIN scout.store_clusters sc ON s.store_id = sc.store_id
    LEFT JOIN scout.dim_products p ON fti.sku = p.sku_code
    LEFT JOIN scout.dim_brands b ON p.brand_id = b.brand_id
    WHERE ft.transaction_date >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY 1, 2, 3, 4
    WINDOW w AS (PARTITION BY sc.cluster_name, p.sku_code ORDER BY ft.transaction_date)
),
elasticity_calc AS (
    SELECT 
        store_cluster,
        brand,
        -- Price elasticity = % change in quantity / % change in price
        AVG(
            CASE 
                WHEN prev_price > 0 AND prev_quantity > 0 
                AND avg_price != prev_price
                THEN ((total_quantity - prev_quantity) / prev_quantity) / 
                     ((avg_price - prev_price) / prev_price)
                ELSE NULL 
            END
        ) AS elasticity,
        COUNT(*) AS sample_size,
        STDDEV(
            CASE 
                WHEN prev_price > 0 AND prev_quantity > 0 
                AND avg_price != prev_price
                THEN ((total_quantity - prev_quantity) / prev_quantity) / 
                     ((avg_price - prev_price) / prev_price)
                ELSE NULL 
            END
        ) AS elasticity_stddev
    FROM price_quantity_changes
    WHERE prev_price IS NOT NULL 
    AND prev_quantity IS NOT NULL
    GROUP BY 1, 2
)
SELECT 
    store_cluster,
    brand,
    ROUND(elasticity::NUMERIC, 2) AS elasticity,
    ROUND((elasticity - 1.96 * elasticity_stddev / SQRT(sample_size))::NUMERIC, 2) AS conf_lower,
    ROUND((elasticity + 1.96 * elasticity_stddev / SQRT(sample_size))::NUMERIC, 2) AS conf_upper,
    sample_size
FROM elasticity_calc
WHERE sample_size >= 30; -- Minimum sample size for reliability

-- ============================================================
-- GEOGRAPHICAL INTELLIGENCE VIEWS
-- ============================================================

-- Region-level choropleth data
CREATE OR REPLACE VIEW scout.gold_region_choropleth AS
WITH daily_metrics AS (
    SELECT 
        DATE(ft.transaction_date) AS transaction_date,
        g.adm1_psgc AS region_key,
        g.adm1_name AS region_name,
        COUNT(DISTINCT ft.transaction_id) AS txn_count,
        COUNT(DISTINCT ft.store_key) AS active_stores,
        COUNT(DISTINCT ft.customer_id) AS unique_customers,
        SUM(ft.total_amount) AS revenue,
        AVG(ft.total_amount) AS avg_ticket,
        SUM(ft.total_amount) / NULLIF(g.population, 0) AS revenue_per_capita
    FROM scout.fact_transactions ft
    JOIN scout.dim_stores s ON ft.store_key = s.store_key
    LEFT JOIN scout.geo_store_mapping gsm ON s.store_id = gsm.store_id
    LEFT JOIN scout.geo_adm1_boundaries g ON gsm.adm1_psgc = g.adm1_psgc
    WHERE ft.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY 1, 2, 3, g.population
)
SELECT 
    transaction_date,
    region_key,
    region_name,
    g.geometry AS geom,
    txn_count,
    revenue,
    avg_ticket,
    active_stores,
    unique_customers,
    revenue_per_capita,
    -- Calculate growth metrics
    txn_count - LAG(txn_count) OVER (PARTITION BY region_key ORDER BY transaction_date) AS txn_growth,
    100.0 * (revenue - LAG(revenue) OVER (PARTITION BY region_key ORDER BY transaction_date)) / 
        NULLIF(LAG(revenue) OVER (PARTITION BY region_key ORDER BY transaction_date), 0) AS revenue_growth_pct
FROM daily_metrics dm
JOIN scout.geo_adm1_boundaries g ON dm.region_key = g.adm1_psgc;

-- City/Municipality level choropleth
CREATE OR REPLACE VIEW scout.gold_citymun_choropleth AS
WITH citymun_metrics AS (
    SELECT 
        DATE(ft.transaction_date) AS transaction_date,
        g.adm3_psgc AS citymun_psgc,
        g.adm3_name AS citymun_name,
        g.adm2_name AS province_name,
        COUNT(DISTINCT ft.transaction_id) AS txn_count,
        SUM(ft.total_amount) AS revenue,
        AVG(ft.total_amount) AS avg_ticket,
        -- Client share calculation
        100.0 * SUM(CASE WHEN b.is_client_brand THEN ft.total_amount ELSE 0 END) / 
            NULLIF(SUM(ft.total_amount), 0) AS client_share,
        -- Top brand
        MODE() WITHIN GROUP (ORDER BY b.brand_name) AS top_brand
    FROM scout.fact_transactions ft
    JOIN scout.fact_transaction_items fti ON ft.transaction_id = fti.transaction_id
    JOIN scout.dim_stores s ON ft.store_key = s.store_key
    LEFT JOIN scout.geo_store_mapping gsm ON s.store_id = gsm.store_id
    LEFT JOIN scout.geo_adm3_boundaries g ON gsm.adm3_psgc = g.adm3_psgc
    LEFT JOIN scout.dim_products p ON fti.sku = p.sku_code
    LEFT JOIN scout.dim_brands b ON p.brand_id = b.brand_id
    WHERE ft.transaction_date >= CURRENT_DATE - INTERVAL '7 days'
    GROUP BY 1, 2, 3, 4
)
SELECT 
    cm.*,
    g.geometry AS geom,
    -- Ranking within province
    RANK() OVER (PARTITION BY cm.province_name ORDER BY cm.revenue DESC) AS revenue_rank_in_province
FROM citymun_metrics cm
JOIN scout.geo_adm3_boundaries g ON cm.citymun_psgc = g.adm3_psgc;

-- Barangay-level roll-up
CREATE OR REPLACE VIEW scout.gold_barangay_rollup AS
WITH barangay_sales AS (
    SELECT 
        DATE(ft.transaction_date) AS transaction_date,
        s.barangay,
        s.city_municipality,
        COUNT(DISTINCT ft.transaction_id) AS txn_count,
        SUM(ft.total_amount) AS revenue,
        -- Top categories
        ARRAY_AGG(DISTINCT c.category_name) FILTER (WHERE c.category_name IS NOT NULL) AS categories,
        -- Store density
        COUNT(DISTINCT s.store_id) AS store_count
    FROM scout.fact_transactions ft
    JOIN scout.dim_stores s ON ft.store_key = s.store_key
    LEFT JOIN scout.fact_transaction_items fti ON ft.transaction_id = fti.transaction_id
    LEFT JOIN scout.dim_products p ON fti.sku = p.sku_code
    LEFT JOIN scout.dim_categories c ON p.category_id = c.category_id
    WHERE ft.transaction_date >= CURRENT_DATE - INTERVAL '7 days'
    GROUP BY 1, 2, 3
)
SELECT 
    transaction_date,
    barangay,
    city_municipality,
    txn_count,
    revenue,
    categories[1:3] AS top_3_categories, -- Top 3 categories
    store_count,
    revenue / NULLIF(store_count, 0) AS revenue_per_store
FROM barangay_sales
ORDER BY transaction_date DESC, revenue DESC;

-- ============================================================
-- ML FEATURE TABLES (PLATINUM LAYER)
-- ============================================================

-- Brand switch propensity features
CREATE TABLE IF NOT EXISTS scout.feature_brand_switch_propensity (
    customer_key INT,
    brand_code VARCHAR(50),
    category_code VARCHAR(50),
    p_switch_30d NUMERIC(4,3), -- Probability of switching in next 30 days
    historical_switches INT,
    avg_days_between_switches NUMERIC(6,2),
    last_switch_date DATE,
    computed_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (customer_key, brand_code)
);

-- Health lift features (from health intelligence system)
CREATE TABLE IF NOT EXISTS scout.feature_health_lift (
    category VARCHAR(100),
    condition VARCHAR(100),
    lift_pct NUMERIC(5,2),
    confidence_interval NUMRANGE,
    sample_size INT,
    last_updated TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (category, condition)
);

-- Seasonality features
CREATE TABLE IF NOT EXISTS scout.feature_seasonality (
    category VARCHAR(100),
    month INT CHECK (month BETWEEN 1 AND 12),
    day_of_week INT CHECK (day_of_week BETWEEN 0 AND 6),
    factor NUMERIC(4,3), -- Multiplicative factor (1.0 = baseline)
    holiday_flag BOOLEAN DEFAULT FALSE,
    weather_condition VARCHAR(50),
    last_updated TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (category, month, day_of_week)
);

-- Create indexes for ML features
CREATE INDEX idx_feature_switch_customer ON scout.feature_brand_switch_propensity(customer_key);
CREATE INDEX idx_feature_health_category ON scout.feature_health_lift(category);
CREATE INDEX idx_feature_seasonality_lookup ON scout.feature_seasonality(category, month);

-- ============================================================
-- MATERIALIZED VIEWS FOR PERFORMANCE
-- ============================================================

-- Materialized view for heavy competitive analysis
CREATE MATERIALIZED VIEW IF NOT EXISTS scout.mv_brand_competitive_daily AS
SELECT * FROM scout.gold_brand_competitive_30d
WITH DATA;

-- Create refresh function
CREATE OR REPLACE FUNCTION scout.refresh_competitive_mvs()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY scout.mv_brand_competitive_daily;
    -- Add more MVs as needed
    
    -- Log refresh
    INSERT INTO scout.etl_log (process_name, status, rows_affected)
    VALUES ('refresh_competitive_mvs', 'completed', 0);
END;
$$ LANGUAGE plpgsql;

-- Schedule refresh every 10 minutes
SELECT cron.schedule(
    'refresh-competitive-mvs',
    '*/10 * * * *',
    'SELECT scout.refresh_competitive_mvs();'
);

-- ============================================================
-- HELPER FUNCTIONS FOR AI RECOMMENDATIONS
-- ============================================================

CREATE OR REPLACE FUNCTION scout.generate_ai_recommendations(
    p_store_id VARCHAR,
    p_persona VARCHAR DEFAULT 'store_manager'
)
RETURNS TABLE (
    recommendation_type VARCHAR,
    priority INT,
    message TEXT,
    expected_impact NUMERIC,
    reason_codes TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    WITH store_context AS (
        SELECT 
            s.store_id,
            s.barangay,
            sc.cluster_name
        FROM scout.dim_stores s
        LEFT JOIN scout.store_clusters sc ON s.store_id = sc.store_id
        WHERE s.store_id = p_store_id
    ),
    recommendations AS (
        -- Stock recommendations based on seasonality
        SELECT 
            'stock_optimization' AS rec_type,
            1 AS priority,
            FORMAT('Stock more %s in %s (+%s%% expected lift)', 
                b.brand_name, 
                TO_CHAR(CURRENT_DATE, 'Month'),
                ROUND(fs.factor * 100 - 100)
            ) AS message,
            fs.factor AS impact,
            ARRAY['seasonality', b.brand_name] AS reasons
        FROM scout.feature_seasonality fs
        JOIN scout.dim_brands b ON fs.category = b.category_name
        WHERE fs.month = EXTRACT(MONTH FROM CURRENT_DATE)
        AND fs.factor > 1.1
        
        UNION ALL
        
        -- Substitution recommendations
        SELECT 
            'substitution_placement' AS rec_type,
            2 AS priority,
            FORMAT('Place %s as fallback for %s (switch rate %s%%)', 
                to_brand, 
                from_brand,
                ROUND(percentage)
            ) AS message,
            percentage / 100.0 AS impact,
            ARRAY['substitution', from_brand, to_brand] AS reasons
        FROM scout.gold_substitution_sankey_30d
        WHERE percentage > 20
        
        UNION ALL
        
        -- Bundle recommendations
        SELECT 
            'bundle_promotion' AS rec_type,
            3 AS priority,
            FORMAT('In %s, push bundle: %s (+₱%s ATP)', 
                sc.barangay,
                'noodles + cola', -- This would come from basket analysis
                ROUND(18::NUMERIC, 0)
            ) AS message,
            0.15 AS impact, -- 15% lift
            ARRAY['bundle', 'location', sc.barangay] AS reasons
        FROM store_context sc
    )
    SELECT 
        rec_type,
        priority,
        message,
        impact,
        reasons
    FROM recommendations
    ORDER BY priority
    LIMIT 5;
END;
$$ LANGUAGE plpgsql;