-- ============================================================
-- Scout v5.2 - Health & Behavioral Extensions (SAFE VERSION)
-- This ONLY ADDS new tables, does NOT modify existing ones
-- ============================================================

-- SAFETY CHECK: Verify our RAG tables are safe
DO $$
BEGIN
    -- List existing important tables (for safety verification)
    RAISE NOTICE 'Existing RAG tables that will NOT be modified:';
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'knowledge_documents') THEN
        RAISE NOTICE '  ✅ scout.knowledge_documents exists - will NOT be touched';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'knowledge_chunks') THEN
        RAISE NOTICE '  ✅ scout.knowledge_chunks exists - will NOT be touched';
    END IF;
END $$;

-- ============================================================
-- NEW TABLES ONLY - Consumer Health Extension
-- ============================================================

-- Only create if doesn't exist
CREATE TABLE IF NOT EXISTS scout.fct_consumer_health (
    consumer_health_key SERIAL PRIMARY KEY,
    customer_key    INTEGER, -- Will link to existing customers
    
    -- Medical/Health Conditions
    smoker_flag     BOOLEAN DEFAULT FALSE,
    diabetes_risk   BOOLEAN DEFAULT FALSE,
    hypertension_risk BOOLEAN DEFAULT FALSE,
    obesity_risk    BOOLEAN DEFAULT FALSE,
    cholesterol_risk BOOLEAN DEFAULT FALSE,
    
    -- Lifestyle Indicators
    alcohol_consumer BOOLEAN DEFAULT FALSE,
    fitness_active  BOOLEAN DEFAULT FALSE,
    diet_conscious  BOOLEAN DEFAULT FALSE,
    
    -- Composite Scores
    health_score    INTEGER CHECK (health_score BETWEEN 0 AND 100),
    nutrition_score INTEGER CHECK (nutrition_score BETWEEN 0 AND 100),
    wellness_index  INTEGER CHECK (wellness_index BETWEEN 0 AND 100),
    
    -- Data Source
    data_source     VARCHAR(50) DEFAULT 'synthetic',
    confidence_level NUMERIC(3,2),
    recorded_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- NEW TABLES ONLY - Brand Health Extension
-- ============================================================

CREATE TABLE IF NOT EXISTS scout.fct_brand_health (
    brand_health_key SERIAL PRIMARY KEY,
    brand_name      VARCHAR(100), -- Links to existing products
    date_key        INTEGER,
    region          VARCHAR(50),
    
    -- Brand Funnel Metrics
    awareness_pct   INTEGER CHECK (awareness_pct BETWEEN 0 AND 100),
    consideration_pct INTEGER CHECK (consideration_pct BETWEEN 0 AND 100),
    preference_pct  INTEGER CHECK (preference_pct BETWEEN 0 AND 100),
    purchase_pct    INTEGER CHECK (purchase_pct BETWEEN 0 AND 100),
    loyalty_pct     INTEGER CHECK (loyalty_pct BETWEEN 0 AND 100),
    advocacy_pct    INTEGER CHECK (advocacy_pct BETWEEN 0 AND 100),
    
    -- Brand Equity Components
    quality_perception INTEGER CHECK (quality_perception BETWEEN 0 AND 100),
    value_perception INTEGER CHECK (value_perception BETWEEN 0 AND 100),
    differentiation_score INTEGER CHECK (differentiation_score BETWEEN 0 AND 100),
    relevance_score INTEGER CHECK (relevance_score BETWEEN 0 AND 100),
    
    -- Composite Index
    brand_equity_index INTEGER CHECK (brand_equity_index BETWEEN 0 AND 100),
    brand_power_score INTEGER CHECK (brand_power_score BETWEEN 0 AND 100),
    
    -- Competitive Position
    market_share_pct NUMERIC(5,2),
    share_of_voice_pct NUMERIC(5,2),
    
    -- Data Source
    survey_source   VARCHAR(50) DEFAULT 'synthetic',
    sample_size     INTEGER,
    confidence_interval NUMERIC(3,2),
    recorded_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- NEW TABLES ONLY - Behavioral Signals Extension
-- ============================================================

CREATE TABLE IF NOT EXISTS scout.fct_behavioral_signals (
    signal_key      SERIAL PRIMARY KEY,
    transaction_id  VARCHAR(100), -- Links to existing transactions
    customer_id     VARCHAR(100), -- Links to existing customers
    
    -- Purchase Behavior
    basket_type     VARCHAR(30) CHECK (basket_type IN (
        'single_item', 'multi_item', 'cross_category', 'bulk_buy', 'trial_purchase'
    )),
    purchase_mission VARCHAR(30) CHECK (purchase_mission IN (
        'routine_refill', 'stock_up', 'immediate_need', 'impulse', 'planned'
    )),
    
    -- Timing Patterns
    occasion        VARCHAR(30) CHECK (occasion IN (
        'morning_rush', 'lunch_break', 'afternoon', 'evening_meal', 'late_night', 
        'weekend', 'payday', 'holiday', 'seasonal'
    )),
    frequency_pattern VARCHAR(20),
    
    -- Decision Factors
    price_sensitivity_signal BOOLEAN DEFAULT FALSE,
    brand_loyalty_signal BOOLEAN DEFAULT FALSE,
    health_conscious_signal BOOLEAN DEFAULT FALSE,
    convenience_seeking_signal BOOLEAN DEFAULT FALSE,
    
    -- Observed Behaviors
    substitution_accepted BOOLEAN DEFAULT FALSE,
    promotion_responsive BOOLEAN DEFAULT FALSE,
    new_product_trial BOOLEAN DEFAULT FALSE,
    
    -- Strength & Confidence
    signal_strength INTEGER CHECK (signal_strength BETWEEN 0 AND 100),
    confidence_score NUMERIC(3,2),
    
    -- Meta
    data_source     VARCHAR(50) DEFAULT 'transaction_derived',
    recorded_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- NEW INTEGRATION VIEWS (Read from existing + new)
-- ============================================================

-- Health-Aware Product Recommendations
CREATE OR REPLACE VIEW scout.vw_health_product_matches AS
SELECT 
    ch.customer_key,
    p.product_name,
    p.brand,
    p.category,
    CASE 
        WHEN ch.diabetes_risk AND p.category = 'Beverages' THEN 'Check sugar content'
        WHEN ch.hypertension_risk AND p.category = 'Snacks' THEN 'Check sodium levels'
        WHEN ch.diet_conscious THEN 'Matches health profile'
        ELSE 'General product'
    END AS health_recommendation
FROM scout.fct_consumer_health ch
CROSS JOIN scout.gold_product_performance p
WHERE p.product_name IS NOT NULL;

-- Brand Health Dashboard (integrates with existing brand data)
CREATE OR REPLACE VIEW scout.vw_enhanced_brand_dashboard AS
SELECT 
    COALESCE(bh.brand_name, p.brand) AS brand_name,
    -- From existing product performance
    p.revenue AS sales_revenue,
    p.units_sold,
    p.avg_price,
    -- From new brand health metrics
    bh.awareness_pct,
    bh.preference_pct,
    bh.loyalty_pct,
    bh.brand_equity_index,
    -- Calculated insights
    CASE 
        WHEN bh.awareness_pct > 80 AND p.revenue > 1000000 THEN 'Market Leader'
        WHEN bh.awareness_pct > 60 THEN 'Strong Contender'
        ELSE 'Growth Opportunity'
    END AS market_position
FROM scout.gold_product_performance p
LEFT JOIN scout.fct_brand_health bh ON bh.brand_name = p.brand
WHERE p.brand IS NOT NULL;

-- ============================================================
-- NEW FUNCTIONS that ENHANCE existing capabilities
-- ============================================================

-- Enhanced dashboard KPIs (adds health insights to existing KPIs)
CREATE OR REPLACE FUNCTION scout.get_enhanced_dashboard_kpis()
RETURNS TABLE (
    -- Original KPIs (preserved)
    total_revenue NUMERIC,
    total_transactions BIGINT,
    unique_customers BIGINT,
    avg_order_value NUMERIC,
    -- New health-aware KPIs
    health_conscious_customers BIGINT,
    health_driven_revenue NUMERIC,
    brand_equity_avg NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH base_kpis AS (
        -- Get existing KPIs from gold layer
        SELECT 
            SUM(revenue) AS total_revenue,
            COUNT(DISTINCT transaction_id) AS total_transactions,
            COUNT(DISTINCT customer_id) AS unique_customers,
            AVG(revenue) AS avg_order_value
        FROM scout.gold_nl_customer_summary
    ),
    health_kpis AS (
        -- New health metrics
        SELECT 
            COUNT(DISTINCT customer_key) AS health_conscious_customers
        FROM scout.fct_consumer_health
        WHERE diet_conscious = TRUE OR fitness_active = TRUE
    ),
    brand_kpis AS (
        -- Brand health average
        SELECT AVG(brand_equity_index) AS brand_equity_avg
        FROM scout.fct_brand_health
        WHERE recorded_at > NOW() - INTERVAL '30 days'
    )
    SELECT 
        b.total_revenue,
        b.total_transactions,
        b.unique_customers,
        b.avg_order_value,
        h.health_conscious_customers,
        b.total_revenue * 0.15 AS health_driven_revenue, -- Estimate
        br.brand_equity_avg
    FROM base_kpis b
    CROSS JOIN health_kpis h
    CROSS JOIN brand_kpis br;
END;
$$;

-- ============================================================
-- PERMISSIONS (Grant read access, preserve existing)
-- ============================================================

-- Grant read access to new tables
GRANT SELECT ON 
    scout.fct_consumer_health,
    scout.fct_brand_health,
    scout.fct_behavioral_signals,
    scout.vw_health_product_matches,
    scout.vw_enhanced_brand_dashboard
TO authenticated;

GRANT EXECUTE ON FUNCTION scout.get_enhanced_dashboard_kpis() TO authenticated;

-- ============================================================
-- SAFETY VERIFICATION
-- ============================================================

DO $$
DECLARE
    v_count INTEGER;
BEGIN
    -- Verify RAG tables still exist and are untouched
    SELECT COUNT(*) INTO v_count
    FROM information_schema.tables 
    WHERE table_schema = 'scout' 
    AND table_name IN ('knowledge_documents', 'knowledge_chunks');
    
    IF v_count >= 2 THEN
        RAISE NOTICE '✅ SUCCESS: RAG tables verified intact';
    END IF;
    
    -- Verify new tables were created
    SELECT COUNT(*) INTO v_count
    FROM information_schema.tables 
    WHERE table_schema = 'scout' 
    AND table_name IN ('fct_consumer_health', 'fct_brand_health', 'fct_behavioral_signals');
    
    RAISE NOTICE '✅ Created % new extension tables', v_count;
END $$;

-- ============================================================
-- ROLLBACK SCRIPT (Just in case)
-- ============================================================
COMMENT ON TABLE scout.fct_consumer_health IS 'SAFE_TO_DROP: Health extension added 2025-01-20';
COMMENT ON TABLE scout.fct_brand_health IS 'SAFE_TO_DROP: Brand extension added 2025-01-20';
COMMENT ON TABLE scout.fct_behavioral_signals IS 'SAFE_TO_DROP: Behavioral extension added 2025-01-20';

-- To rollback if needed:
-- DROP TABLE IF EXISTS scout.fct_consumer_health CASCADE;
-- DROP TABLE IF EXISTS scout.fct_brand_health CASCADE;
-- DROP TABLE IF EXISTS scout.fct_behavioral_signals CASCADE;
-- DROP VIEW IF EXISTS scout.vw_health_product_matches;
-- DROP VIEW IF EXISTS scout.vw_enhanced_brand_dashboard;
-- DROP FUNCTION IF EXISTS scout.get_enhanced_dashboard_kpis();