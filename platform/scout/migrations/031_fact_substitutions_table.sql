-- ============================================================
-- Migration 031: Fact Substitutions Table
-- Creates the fact table for tracking product substitutions
-- ============================================================

-- Create fact_substitutions table for tracking brand/product substitutions
CREATE TABLE IF NOT EXISTS scout.fact_substitutions (
    substitution_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id VARCHAR(100) NOT NULL,
    store_key INT,
    customer_key INT,
    
    -- What was requested vs what was purchased
    category VARCHAR(100),
    detected_brand VARCHAR(255),      -- From STT or customer request
    substitute_to VARCHAR(255),        -- What was actually purchased
    
    -- Substitution details
    reason VARCHAR(50) CHECK (reason IN ('stockout', 'price', 'preference', 'availability', 'promotion')),
    confidence_score NUMERIC(3,2),
    
    -- Metrics
    original_price NUMERIC(10,2),
    substitute_price NUMERIC(10,2),
    price_difference NUMERIC(10,2),
    quantity INT DEFAULT 1,
    
    -- Timestamps
    detected_at TIMESTAMP DEFAULT NOW(),
    transaction_date DATE,
    
    -- Source tracking
    detection_method VARCHAR(50) DEFAULT 'stt', -- 'stt', 'manual', 'inferred'
    device_id VARCHAR(100)
);

-- Create indexes for performance
CREATE INDEX idx_fact_substitutions_date ON scout.fact_substitutions(detected_at);
CREATE INDEX idx_fact_substitutions_category ON scout.fact_substitutions(category);
CREATE INDEX idx_fact_substitutions_brands ON scout.fact_substitutions(detected_brand, substitute_to);
CREATE INDEX idx_fact_substitutions_store ON scout.fact_substitutions(store_key);
CREATE INDEX idx_fact_substitutions_reason ON scout.fact_substitutions(reason);

-- Create function to populate fact_substitutions from STT detections
CREATE OR REPLACE FUNCTION scout.populate_fact_substitutions()
RETURNS void AS $$
BEGIN
    -- Insert new substitutions detected from STT + transactions
    INSERT INTO scout.fact_substitutions (
        transaction_id,
        store_key,
        customer_key,
        category,
        detected_brand,
        substitute_to,
        reason,
        confidence_score,
        original_price,
        substitute_price,
        price_difference,
        quantity,
        detected_at,
        transaction_date,
        detection_method,
        device_id
    )
    SELECT 
        ft.transaction_id::VARCHAR,
        ft.store_key,
        ft.customer_id AS customer_key,
        c.category_name AS category,
        sd.brands_detected[1] AS detected_brand,
        b.brand_name AS substitute_to,
        CASE 
            WHEN fti.quantity = 0 THEN 'stockout'
            WHEN fti.unit_price > prev_price.avg_price * 1.1 THEN 'price'
            WHEN sd.brands_detected[1] = b.brand_name THEN NULL -- No substitution
            ELSE 'availability'
        END AS reason,
        sd.confidence_score,
        prev_price.avg_price AS original_price,
        fti.unit_price AS substitute_price,
        fti.unit_price - COALESCE(prev_price.avg_price, fti.unit_price) AS price_difference,
        fti.quantity,
        sd.detected_at,
        ft.transaction_date::DATE,
        'stt' AS detection_method,
        sd.device_id
    FROM scout.stt_detections sd
    JOIN scout.fact_transactions ft ON sd.transaction_id = ft.transaction_id::VARCHAR
    JOIN scout.fact_transaction_items fti ON ft.transaction_id = fti.transaction_id
    LEFT JOIN scout.dim_products p ON fti.sku = p.sku_code
    LEFT JOIN scout.dim_brands b ON p.brand_id = b.brand_id
    LEFT JOIN scout.dim_categories c ON p.category_id = c.category_id
    -- Get previous average price for the requested brand
    LEFT JOIN LATERAL (
        SELECT AVG(fti2.unit_price) AS avg_price
        FROM scout.fact_transaction_items fti2
        JOIN scout.dim_products p2 ON fti2.sku = p2.sku_code
        JOIN scout.dim_brands b2 ON p2.brand_id = b2.brand_id
        WHERE b2.brand_name = sd.brands_detected[1]
        AND fti2.transaction_id IN (
            SELECT transaction_id 
            FROM scout.fact_transactions 
            WHERE transaction_date >= CURRENT_DATE - INTERVAL '30 days'
        )
    ) prev_price ON TRUE
    WHERE sd.detected_at >= CURRENT_DATE - INTERVAL '1 day'
    AND array_length(sd.brands_detected, 1) > 0
    AND sd.brands_detected[1] != b.brand_name -- Only actual substitutions
    ON CONFLICT DO NOTHING;
    
    -- Log the population
    INSERT INTO scout.etl_log (process_name, status, rows_affected)
    VALUES ('populate_fact_substitutions', 'completed', 0);
END;
$$ LANGUAGE plpgsql;

-- Schedule daily population of substitutions
SELECT cron.schedule(
    'populate-fact-substitutions',
    '0 2 * * *', -- 2 AM daily
    'SELECT scout.populate_fact_substitutions();'
);

-- Create summary view for substitution patterns
CREATE OR REPLACE VIEW scout.v_substitution_patterns AS
WITH substitution_summary AS (
    SELECT 
        category,
        detected_brand,
        substitute_to,
        reason,
        COUNT(*) AS substitution_count,
        AVG(confidence_score) AS avg_confidence,
        AVG(price_difference) AS avg_price_diff,
        COUNT(DISTINCT store_key) AS stores_affected,
        COUNT(DISTINCT customer_key) AS customers_affected
    FROM scout.fact_substitutions
    WHERE detected_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY category, detected_brand, substitute_to, reason
)
SELECT 
    *,
    substitution_count::NUMERIC / SUM(substitution_count) OVER (PARTITION BY category) AS category_share,
    RANK() OVER (PARTITION BY category ORDER BY substitution_count DESC) AS category_rank
FROM substitution_summary
ORDER BY category, substitution_count DESC;