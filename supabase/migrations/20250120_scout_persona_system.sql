-- ============================================================
-- Scout v5.2 - Derived Persona System
-- Advanced customer archetypes based on behavioral patterns
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- PERSONA DEFINITIONS AND TAXONOMY
-- ============================================================

-- Persona type enum
CREATE TYPE scout.persona_type AS ENUM ('primary', 'modifier', 'contextual');
CREATE TYPE scout.assignment_method AS ENUM ('rule_based', 'ml_clustering', 'neural_network', 'hybrid');

-- Core persona definitions
CREATE TABLE scout.persona_definitions (
    persona_id VARCHAR(50) PRIMARY KEY,
    persona_name VARCHAR(100) NOT NULL,
    persona_type scout.persona_type NOT NULL,
    persona_category VARCHAR(50), -- shopping, health, lifestyle
    
    -- Characteristics
    description TEXT,
    key_traits JSONB DEFAULT '[]'::JSONB,
    behavioral_indicators JSONB DEFAULT '{}'::JSONB,
    
    -- Rules and thresholds
    assignment_rules JSONB DEFAULT '{}'::JSONB,
    min_confidence DECIMAL(3,2) DEFAULT 0.70,
    
    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Customer persona assignments (many-to-many)
CREATE TABLE scout.customer_personas (
    assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL, -- References existing customer
    persona_id VARCHAR(50) REFERENCES scout.persona_definitions(persona_id),
    
    -- Assignment details
    confidence_score DECIMAL(3,2) CHECK (confidence_score BETWEEN 0 AND 1),
    is_primary BOOLEAN DEFAULT FALSE,
    assignment_method scout.assignment_method,
    
    -- Temporal validity
    valid_from TIMESTAMPTZ DEFAULT NOW(),
    valid_to TIMESTAMPTZ,
    
    -- Assignment context
    assignment_features JSONB, -- Features used for assignment
    assignment_reason TEXT,
    model_version VARCHAR(20),
    
    -- Constraints
    UNIQUE(customer_id, persona_id, valid_from),
    CHECK (valid_to IS NULL OR valid_to > valid_from)
);

-- Persona feature vectors for ML
CREATE TABLE scout.persona_feature_vectors (
    vector_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    calculation_date DATE NOT NULL,
    
    -- Behavioral features
    purchase_frequency_score DECIMAL(3,2),
    avg_basket_size_normalized DECIMAL(3,2),
    category_diversity_index DECIMAL(3,2),
    price_sensitivity_score DECIMAL(3,2),
    brand_loyalty_index DECIMAL(3,2),
    
    -- Health & wellness features
    health_product_affinity DECIMAL(3,2),
    organic_preference_score DECIMAL(3,2),
    dietary_restriction_indicator JSONB,
    
    -- Shopping patterns
    weekday_vs_weekend DECIMAL(3,2), -- 0=weekday, 1=weekend
    morning_vs_evening DECIMAL(3,2),  -- 0=morning, 1=evening
    online_vs_offline DECIMAL(3,2),   -- 0=offline, 1=online
    
    -- Promotion responsiveness
    promo_redemption_rate DECIMAL(3,2),
    discount_depth_preference DECIMAL(3,2),
    
    -- Innovation adoption
    new_product_trial_rate DECIMAL(3,2),
    category_exploration_score DECIMAL(3,2),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(customer_id, calculation_date)
);

-- Persona transition tracking
CREATE TABLE scout.persona_transitions (
    transition_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    from_persona_id VARCHAR(50) REFERENCES scout.persona_definitions(persona_id),
    to_persona_id VARCHAR(50) REFERENCES scout.persona_definitions(persona_id),
    transition_date TIMESTAMPTZ DEFAULT NOW(),
    trigger_event VARCHAR(100),
    transition_confidence DECIMAL(3,2),
    transition_features JSONB
);

-- ============================================================
-- PERSONA ANALYTICS AND METRICS
-- ============================================================

-- Persona performance metrics
CREATE TABLE scout.persona_metrics (
    metric_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    persona_id VARCHAR(50) REFERENCES scout.persona_definitions(persona_id),
    metric_date DATE NOT NULL,
    
    -- Population metrics
    total_customers INTEGER DEFAULT 0,
    new_customers INTEGER DEFAULT 0,
    churned_customers INTEGER DEFAULT 0,
    
    -- Behavioral metrics
    avg_purchase_frequency DECIMAL(5,2),
    avg_basket_size DECIMAL(10,2),
    avg_items_per_basket DECIMAL(5,2),
    
    -- Value metrics
    total_revenue DECIMAL(15,2),
    avg_customer_value DECIMAL(10,2),
    projected_clv DECIMAL(12,2),
    
    -- Engagement metrics
    email_open_rate DECIMAL(3,2),
    app_usage_rate DECIMAL(3,2),
    promotion_redemption_rate DECIMAL(3,2),
    
    UNIQUE(persona_id, metric_date)
);

-- Persona recommendation effectiveness
CREATE TABLE scout.persona_recommendations (
    recommendation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    persona_id VARCHAR(50) REFERENCES scout.persona_definitions(persona_id),
    recommendation_type VARCHAR(50), -- product, content, offer
    recommendation_content JSONB,
    
    -- Performance
    impressions INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    conversions INTEGER DEFAULT 0,
    revenue_generated DECIMAL(10,2) DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

-- ============================================================
-- PERSONA ASSIGNMENT FUNCTIONS
-- ============================================================

-- Calculate customer features for persona assignment
CREATE OR REPLACE FUNCTION scout.calculate_customer_features(
    p_customer_id UUID,
    p_lookback_days INTEGER DEFAULT 90
) RETURNS scout.persona_feature_vectors AS $$
DECLARE
    v_features scout.persona_feature_vectors;
BEGIN
    -- Initialize record
    v_features.customer_id := p_customer_id;
    v_features.calculation_date := CURRENT_DATE;
    
    -- Calculate purchase frequency (transactions per week)
    SELECT 
        LEAST(COUNT(*)::DECIMAL / (p_lookback_days / 7.0) / 5.0, 1.0) -- Normalize to 0-1
    INTO v_features.purchase_frequency_score
    FROM scout.gold_nl_customer_summary
    WHERE customer_id = p_customer_id::VARCHAR
    AND transaction_date > CURRENT_DATE - INTERVAL '1 day' * p_lookback_days;
    
    -- Calculate average basket size (normalized by store average)
    WITH store_avg AS (
        SELECT AVG(revenue) as avg_basket
        FROM scout.gold_nl_customer_summary
        WHERE transaction_date > CURRENT_DATE - INTERVAL '1 day' * p_lookback_days
    )
    SELECT 
        LEAST(AVG(cs.revenue) / NULLIF(sa.avg_basket, 0), 2.0) / 2.0 -- Normalize to 0-1
    INTO v_features.avg_basket_size_normalized
    FROM scout.gold_nl_customer_summary cs
    CROSS JOIN store_avg sa
    WHERE cs.customer_id = p_customer_id::VARCHAR
    AND cs.transaction_date > CURRENT_DATE - INTERVAL '1 day' * p_lookback_days
    GROUP BY sa.avg_basket;
    
    -- Calculate category diversity
    SELECT 
        COUNT(DISTINCT category)::DECIMAL / GREATEST(COUNT(*), 1)
    INTO v_features.category_diversity_index
    FROM scout.gold_nl_customer_summary cs
    JOIN scout.gold_product_performance pp ON cs.product_name = pp.product_name
    WHERE cs.customer_id = p_customer_id::VARCHAR
    AND cs.transaction_date > CURRENT_DATE - INTERVAL '1 day' * p_lookback_days;
    
    -- Price sensitivity (preference for discounted items)
    SELECT 
        COALESCE(
            SUM(CASE WHEN cs.revenue < pp.avg_price * 0.9 THEN 1 ELSE 0 END)::DECIMAL / 
            NULLIF(COUNT(*), 0), 
            0.5
        )
    INTO v_features.price_sensitivity_score
    FROM scout.gold_nl_customer_summary cs
    JOIN scout.gold_product_performance pp ON cs.product_name = pp.product_name
    WHERE cs.customer_id = p_customer_id::VARCHAR
    AND cs.transaction_date > CURRENT_DATE - INTERVAL '1 day' * p_lookback_days;
    
    -- Brand loyalty (repeat purchases of same brands)
    WITH brand_purchases AS (
        SELECT 
            pp.brand,
            COUNT(*) as purchase_count
        FROM scout.gold_nl_customer_summary cs
        JOIN scout.gold_product_performance pp ON cs.product_name = pp.product_name
        WHERE cs.customer_id = p_customer_id::VARCHAR
        AND cs.transaction_date > CURRENT_DATE - INTERVAL '1 day' * p_lookback_days
        GROUP BY pp.brand
    )
    SELECT 
        COALESCE(
            SUM(CASE WHEN purchase_count > 1 THEN purchase_count ELSE 0 END)::DECIMAL / 
            NULLIF(SUM(purchase_count), 0),
            0
        )
    INTO v_features.brand_loyalty_index
    FROM brand_purchases;
    
    -- Set defaults for null values
    v_features.purchase_frequency_score := COALESCE(v_features.purchase_frequency_score, 0);
    v_features.avg_basket_size_normalized := COALESCE(v_features.avg_basket_size_normalized, 0);
    v_features.category_diversity_index := COALESCE(v_features.category_diversity_index, 0);
    v_features.price_sensitivity_score := COALESCE(v_features.price_sensitivity_score, 0.5);
    v_features.brand_loyalty_index := COALESCE(v_features.brand_loyalty_index, 0);
    
    -- Placeholder values for advanced features (to be implemented)
    v_features.health_product_affinity := 0.5;
    v_features.organic_preference_score := 0.5;
    v_features.weekday_vs_weekend := 0.5;
    v_features.morning_vs_evening := 0.5;
    v_features.online_vs_offline := 0;
    v_features.promo_redemption_rate := v_features.price_sensitivity_score;
    v_features.new_product_trial_rate := v_features.category_diversity_index;
    
    RETURN v_features;
END;
$$ LANGUAGE plpgsql;

-- Rule-based persona assignment
CREATE OR REPLACE FUNCTION scout.assign_persona_rules(
    p_features scout.persona_feature_vectors
) RETURNS TABLE (
    persona_id VARCHAR(50),
    confidence DECIMAL(3,2),
    reasoning TEXT
) AS $$
BEGIN
    -- Value Maximizer
    IF p_features.price_sensitivity_score > 0.6 
       AND p_features.promo_redemption_rate > 0.5 THEN
        RETURN QUERY
        SELECT 
            'value_maximizer'::VARCHAR(50),
            LEAST(
                (p_features.price_sensitivity_score + p_features.promo_redemption_rate) / 2 + 0.1,
                0.95
            )::DECIMAL(3,2),
            'High price sensitivity and promotion usage'::TEXT;
    END IF;
    
    -- Premium Seeker
    IF p_features.avg_basket_size_normalized > 0.7 
       AND p_features.price_sensitivity_score < 0.3 THEN
        RETURN QUERY
        SELECT 
            'premium_seeker'::VARCHAR(50),
            LEAST(
                p_features.avg_basket_size_normalized * (1 - p_features.price_sensitivity_score),
                0.95
            )::DECIMAL(3,2),
            'High basket value with low price sensitivity'::TEXT;
    END IF;
    
    -- Health Guardian
    IF p_features.health_product_affinity > 0.6 
       OR p_features.organic_preference_score > 0.7 THEN
        RETURN QUERY
        SELECT 
            'health_guardian'::VARCHAR(50),
            GREATEST(
                p_features.health_product_affinity,
                p_features.organic_preference_score
            )::DECIMAL(3,2),
            'Strong preference for health and organic products'::TEXT;
    END IF;
    
    -- Explorer
    IF p_features.category_diversity_index > 0.7 
       AND p_features.new_product_trial_rate > 0.5 THEN
        RETURN QUERY
        SELECT 
            'explorer'::VARCHAR(50),
            ((p_features.category_diversity_index + p_features.new_product_trial_rate) / 2)::DECIMAL(3,2),
            'High category diversity and new product adoption'::TEXT;
    END IF;
    
    -- Brand Loyalist
    IF p_features.brand_loyalty_index > 0.7 THEN
        RETURN QUERY
        SELECT 
            'loyalist'::VARCHAR(50),
            p_features.brand_loyalty_index::DECIMAL(3,2),
            'Strong brand loyalty patterns'::TEXT;
    END IF;
    
    -- Default: Regular Shopper
    RETURN QUERY
    SELECT 
        'regular_shopper'::VARCHAR(50),
        0.60::DECIMAL(3,2),
        'Balanced shopping behavior'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Main persona assignment orchestrator
CREATE OR REPLACE FUNCTION scout.assign_customer_personas(
    p_customer_id UUID,
    p_method scout.assignment_method DEFAULT 'rule_based'
) RETURNS VOID AS $$
DECLARE
    v_features scout.persona_feature_vectors;
    v_persona RECORD;
BEGIN
    -- Calculate current features
    v_features := scout.calculate_customer_features(p_customer_id);
    
    -- Store feature vector
    INSERT INTO scout.persona_feature_vectors 
    SELECT v_features.*
    ON CONFLICT (customer_id, calculation_date) 
    DO UPDATE SET 
        purchase_frequency_score = EXCLUDED.purchase_frequency_score,
        avg_basket_size_normalized = EXCLUDED.avg_basket_size_normalized,
        category_diversity_index = EXCLUDED.category_diversity_index,
        price_sensitivity_score = EXCLUDED.price_sensitivity_score,
        brand_loyalty_index = EXCLUDED.brand_loyalty_index,
        updated_at = NOW();
    
    -- Expire existing assignments
    UPDATE scout.customer_personas
    SET valid_to = NOW()
    WHERE customer_id = p_customer_id
    AND valid_to IS NULL;
    
    -- Assign new personas based on method
    IF p_method = 'rule_based' THEN
        FOR v_persona IN 
            SELECT * FROM scout.assign_persona_rules(v_features)
            WHERE confidence >= 0.6
        LOOP
            INSERT INTO scout.customer_personas (
                customer_id,
                persona_id,
                confidence_score,
                is_primary,
                assignment_method,
                assignment_features,
                assignment_reason
            ) VALUES (
                p_customer_id,
                v_persona.persona_id,
                v_persona.confidence,
                FALSE, -- Will set primary after
                p_method,
                row_to_json(v_features),
                v_persona.reasoning
            );
        END LOOP;
        
        -- Set highest confidence as primary
        UPDATE scout.customer_personas cp
        SET is_primary = TRUE
        WHERE cp.customer_id = p_customer_id
        AND cp.valid_to IS NULL
        AND cp.confidence_score = (
            SELECT MAX(confidence_score)
            FROM scout.customer_personas
            WHERE customer_id = p_customer_id
            AND valid_to IS NULL
        );
    END IF;
    
    -- Track transitions
    INSERT INTO scout.persona_transitions (
        customer_id,
        from_persona_id,
        to_persona_id,
        transition_confidence,
        trigger_event
    )
    SELECT 
        p_customer_id,
        old_p.persona_id,
        new_p.persona_id,
        new_p.confidence_score,
        'Scheduled recalculation'
    FROM scout.customer_personas old_p
    JOIN scout.customer_personas new_p 
        ON old_p.customer_id = new_p.customer_id
        AND old_p.is_primary = TRUE
        AND new_p.is_primary = TRUE
        AND old_p.valid_to IS NOT NULL
        AND new_p.valid_to IS NULL
        AND old_p.persona_id != new_p.persona_id
    WHERE old_p.customer_id = p_customer_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- PERSONA-BASED INSIGHTS AND RECOMMENDATIONS
-- ============================================================

-- Get persona-based product recommendations
CREATE OR REPLACE FUNCTION scout.get_persona_recommendations(
    p_persona_id VARCHAR(50),
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    product_name VARCHAR(255),
    brand VARCHAR(100),
    category VARCHAR(100),
    recommendation_score DECIMAL(3,2),
    recommendation_reason TEXT
) AS $$
BEGIN
    -- Different strategies per persona
    CASE p_persona_id
        WHEN 'value_maximizer' THEN
            RETURN QUERY
            SELECT 
                pp.product_name,
                pp.brand,
                pp.category,
                (0.7 - (pp.avg_price / NULLIF(cat_avg.avg_price, 1)))::DECIMAL(3,2) as score,
                'Great value - below category average price'::TEXT
            FROM scout.gold_product_performance pp
            JOIN (
                SELECT category, AVG(avg_price) as avg_price
                FROM scout.gold_product_performance
                GROUP BY category
            ) cat_avg ON pp.category = cat_avg.category
            WHERE pp.avg_price < cat_avg.avg_price * 0.8
            ORDER BY score DESC
            LIMIT p_limit;
            
        WHEN 'health_guardian' THEN
            RETURN QUERY
            SELECT 
                pp.product_name,
                pp.brand,
                pp.category,
                CASE 
                    WHEN pp.category IN ('Organic', 'Health Foods', 'Fresh Produce') THEN 0.9
                    WHEN pp.product_name ILIKE '%organic%' THEN 0.85
                    WHEN pp.product_name ILIKE '%natural%' THEN 0.8
                    WHEN pp.product_name ILIKE '%whole%' THEN 0.75
                    ELSE 0.5
                END::DECIMAL(3,2) as score,
                'Matches health-conscious preferences'::TEXT
            FROM scout.gold_product_performance pp
            WHERE pp.category IN ('Organic', 'Health Foods', 'Fresh Produce', 'Beverages')
            OR pp.product_name ILIKE ANY(ARRAY['%organic%', '%natural%', '%whole%', '%fresh%'])
            ORDER BY score DESC, pp.units_sold DESC
            LIMIT p_limit;
            
        WHEN 'explorer' THEN
            RETURN QUERY
            SELECT 
                pp.product_name,
                pp.brand,
                pp.category,
                (0.5 + RANDOM() * 0.5)::DECIMAL(3,2) as score,
                'New product to try in ' || pp.category::TEXT
            FROM scout.gold_product_performance pp
            WHERE pp.created_at > NOW() - INTERVAL '30 days'
            OR pp.units_sold < 100  -- Low sales might mean new
            ORDER BY RANDOM()
            LIMIT p_limit;
            
        ELSE -- Default recommendations
            RETURN QUERY
            SELECT 
                pp.product_name,
                pp.brand,
                pp.category,
                0.7::DECIMAL(3,2) as score,
                'Popular in your store'::TEXT
            FROM scout.gold_product_performance pp
            ORDER BY pp.units_sold DESC
            LIMIT p_limit;
    END CASE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- PERSONA INITIALIZATION DATA
-- ============================================================

-- Insert base personas
INSERT INTO scout.persona_definitions (persona_id, persona_name, persona_type, description, key_traits) VALUES
('value_maximizer', 'Value Maximizer', 'primary', 'Price-conscious shoppers who actively seek deals', 
 '["promotion_responsive", "price_sensitive", "bulk_buyer", "coupon_user"]'::JSONB),

('premium_seeker', 'Premium Seeker', 'primary', 'Quality-focused customers willing to pay more', 
 '["brand_conscious", "quality_driven", "low_price_sensitivity", "loyal"]'::JSONB),

('health_guardian', 'Health Guardian', 'primary', 'Health and wellness focused shoppers', 
 '["organic_preference", "nutrition_conscious", "fresh_focused", "label_reader"]'::JSONB),

('family_provider', 'Family Provider', 'primary', 'Shopping for household and family needs', 
 '["bulk_buyer", "variety_seeker", "routine_shopper", "kid_items"]'::JSONB),

('explorer', 'Explorer', 'primary', 'Adventurous shoppers trying new products', 
 '["early_adopter", "category_diverse", "trend_follower", "curious"]'::JSONB),

('loyalist', 'Loyalist', 'primary', 'Highly loyal to specific brands or stores', 
 '["repeat_buyer", "brand_loyal", "routine_driven", "low_churn"]'::JSONB),

('convenience_champion', 'Convenience Champion', 'primary', 'Time-sensitive, efficiency-focused', 
 '["quick_shop", "ready_made", "online_preferred", "delivery_user"]'::JSONB),

('regular_shopper', 'Regular Shopper', 'primary', 'Balanced shopping behavior', 
 '["moderate_frequency", "average_basket", "mixed_preferences"]'::JSONB);

-- Insert modifier personas
INSERT INTO scout.persona_definitions (persona_id, persona_name, persona_type, description) VALUES
('digital_native', 'Digital Native', 'modifier', 'Prefers online/app shopping'),
('eco_warrior', 'Eco Warrior', 'modifier', 'Environmentally conscious choices'),
('local_champion', 'Local Champion', 'modifier', 'Supports local brands and products'),
('impulse_buyer', 'Impulse Buyer', 'modifier', 'Makes unplanned purchases'),
('stockup_strategist', 'Stock-up Strategist', 'modifier', 'Bulk buys during promotions');

-- ============================================================
-- VIEWS AND ANALYTICS
-- ============================================================

-- Current customer personas view
CREATE OR REPLACE VIEW scout.vw_current_customer_personas AS
SELECT 
    cp.customer_id,
    cp.persona_id,
    pd.persona_name,
    pd.persona_type,
    cp.confidence_score,
    cp.is_primary,
    cp.valid_from,
    cp.assignment_reason
FROM scout.customer_personas cp
JOIN scout.persona_definitions pd ON cp.persona_id = pd.persona_id
WHERE cp.valid_to IS NULL
ORDER BY cp.customer_id, cp.is_primary DESC, cp.confidence_score DESC;

-- Persona distribution
CREATE OR REPLACE VIEW scout.vw_persona_distribution AS
SELECT 
    pd.persona_name,
    pd.persona_type,
    COUNT(DISTINCT cp.customer_id) as customer_count,
    AVG(cp.confidence_score) as avg_confidence,
    COUNT(DISTINCT cp.customer_id) * 100.0 / 
        (SELECT COUNT(DISTINCT customer_id) FROM scout.customer_personas WHERE valid_to IS NULL) as percentage
FROM scout.customer_personas cp
JOIN scout.persona_definitions pd ON cp.persona_id = pd.persona_id
WHERE cp.valid_to IS NULL
AND cp.is_primary = TRUE
GROUP BY pd.persona_name, pd.persona_type
ORDER BY customer_count DESC;

-- Persona performance summary
CREATE OR REPLACE VIEW scout.vw_persona_performance AS
SELECT 
    pd.persona_name,
    pm.metric_date,
    pm.total_customers,
    pm.avg_basket_size,
    pm.avg_customer_value,
    pm.projected_clv,
    pm.promotion_redemption_rate,
    RANK() OVER (PARTITION BY pm.metric_date ORDER BY pm.avg_customer_value DESC) as value_rank
FROM scout.persona_metrics pm
JOIN scout.persona_definitions pd ON pm.persona_id = pd.persona_id
WHERE pm.metric_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY pm.metric_date DESC, value_rank;

-- ============================================================
-- PERMISSIONS
-- ============================================================

-- Grant read access to authenticated users
GRANT SELECT ON ALL TABLES IN SCHEMA scout TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA scout TO authenticated;

-- ============================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================

CREATE INDEX idx_customer_personas_customer ON scout.customer_personas(customer_id);
CREATE INDEX idx_customer_personas_valid ON scout.customer_personas(valid_to) WHERE valid_to IS NULL;
CREATE INDEX idx_persona_vectors_customer_date ON scout.persona_feature_vectors(customer_id, calculation_date);
CREATE INDEX idx_persona_transitions_customer ON scout.persona_transitions(customer_id);
CREATE INDEX idx_persona_metrics_date ON scout.persona_metrics(metric_date);

-- ============================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================

COMMENT ON TABLE scout.persona_definitions IS 'Master catalog of all persona types and their characteristics';
COMMENT ON TABLE scout.customer_personas IS 'Customer-to-persona assignments with confidence scores and validity periods';
COMMENT ON TABLE scout.persona_feature_vectors IS 'Calculated behavioral features used for persona assignment';
COMMENT ON FUNCTION scout.assign_customer_personas IS 'Main function to assign personas to a customer based on their behavior';
COMMENT ON FUNCTION scout.get_persona_recommendations IS 'Get personalized product recommendations based on persona type';