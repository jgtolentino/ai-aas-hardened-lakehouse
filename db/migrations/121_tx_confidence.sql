-- Per-Transaction Confidence System
-- Links ML predictions to transactions and aggregates confidence

CREATE TABLE IF NOT EXISTS ml.prediction_links (
    id SERIAL PRIMARY KEY,
    prediction_id BIGINT NOT NULL REFERENCES ml.prediction_events(id),
    transaction_id VARCHAR(100),
    item_product_id INTEGER,
    item_sku_id INTEGER,
    link_type VARCHAR(20) DEFAULT 'transaction', -- 'transaction', 'item', 'manual'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(prediction_id)
);

CREATE INDEX IF NOT EXISTS idx_ml_links_transaction ON ml.prediction_links(transaction_id);
CREATE INDEX IF NOT EXISTS idx_ml_links_product ON ml.prediction_links(item_product_id);

-- Function to link prediction to transaction
CREATE OR REPLACE FUNCTION ml.link_prediction(
    p_prediction_id BIGINT,
    p_transaction_id VARCHAR,
    p_product_id INTEGER DEFAULT NULL,
    p_sku_id INTEGER DEFAULT NULL
)
RETURNS void AS $$
BEGIN
    INSERT INTO ml.prediction_links (
        prediction_id,
        transaction_id,
        item_product_id,
        item_sku_id
    ) VALUES (
        p_prediction_id,
        p_transaction_id,
        p_product_id,
        p_sku_id
    ) ON CONFLICT (prediction_id) DO UPDATE SET
        transaction_id = EXCLUDED.transaction_id,
        item_product_id = EXCLUDED.item_product_id,
        item_sku_id = EXCLUDED.item_sku_id;
END;
$$ LANGUAGE plpgsql;

-- Function to calibrate confidence based on reliability bins
CREATE OR REPLACE FUNCTION ml.calibrate_confidence(
    p_model_name VARCHAR,
    p_model_version VARCHAR,
    p_raw_confidence DECIMAL
)
RETURNS DECIMAL AS $$
DECLARE
    v_calibrated DECIMAL;
BEGIN
    -- Find the matching bin and return its actual accuracy
    SELECT accuracy INTO v_calibrated
    FROM ml.calibration_bins
    WHERE model_name = p_model_name
      AND model_version = p_model_version
      AND p_raw_confidence >= confidence_min
      AND p_raw_confidence <= confidence_max
      AND date_computed = (
          SELECT MAX(date_computed)
          FROM ml.calibration_bins
          WHERE model_name = p_model_name
            AND model_version = p_model_version
      )
    ORDER BY ABS(confidence_avg - p_raw_confidence)
    LIMIT 1;
    
    -- If no calibration data, return raw
    RETURN COALESCE(v_calibrated, p_raw_confidence);
END;
$$ LANGUAGE plpgsql;

-- View for item-level predictions with calibrated confidence
CREATE OR REPLACE VIEW ml.v_tx_item_predictions AS
SELECT 
    pl.transaction_id,
    pl.item_product_id,
    pl.item_sku_id,
    pe.predicted_class as predicted_brand,
    pe.confidence as raw_confidence,
    ml.calibrate_confidence(pe.model_name, pe.model_version, pe.confidence) as calibrated_confidence,
    pe.model_name,
    pe.model_version,
    pe.prediction_timestamp
FROM ml.prediction_links pl
JOIN ml.prediction_events pe ON pl.prediction_id = pe.id
WHERE pl.transaction_id IS NOT NULL;

-- View for transaction-level brand confidence
CREATE OR REPLACE VIEW ml.v_tx_brand_confidence AS
WITH item_predictions AS (
    SELECT 
        transaction_id,
        predicted_brand,
        AVG(calibrated_confidence) as mean_confidence,
        COUNT(*) as item_count
    FROM ml.v_tx_item_predictions
    GROUP BY transaction_id, predicted_brand
),
transaction_totals AS (
    SELECT 
        transaction_id,
        SUM(item_count) as total_items
    FROM item_predictions
    GROUP BY transaction_id
),
top_brands AS (
    SELECT DISTINCT ON (transaction_id)
        ip.transaction_id,
        ip.predicted_brand as top_brand,
        ip.mean_confidence as base_confidence,
        ip.item_count as top_brand_items,
        tt.total_items,
        ip.item_count::DECIMAL / tt.total_items as agreement
    FROM item_predictions ip
    JOIN transaction_totals tt ON ip.transaction_id = tt.transaction_id
    ORDER BY transaction_id, item_count DESC, mean_confidence DESC
)
SELECT 
    transaction_id,
    top_brand,
    base_confidence,
    agreement,
    -- Penalize confidence based on disagreement
    base_confidence * (0.5 + 0.5 * agreement) as confidence_final,
    top_brand_items,
    total_items
FROM top_brands;

-- Materialized view for performance (optional)
CREATE MATERIALIZED VIEW IF NOT EXISTS ml.mv_tx_brand_confidence AS
SELECT * FROM ml.v_tx_brand_confidence;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_tx_brand_tx ON ml.mv_tx_brand_confidence(transaction_id);

-- Function to refresh transaction confidence
CREATE OR REPLACE FUNCTION ml.refresh_tx_confidence()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY ml.mv_tx_brand_confidence;
END;
$$ LANGUAGE plpgsql;

-- Grants
GRANT SELECT ON ml.v_tx_item_predictions TO PUBLIC;
GRANT SELECT ON ml.v_tx_brand_confidence TO PUBLIC;
GRANT SELECT ON ml.mv_tx_brand_confidence TO PUBLIC;
GRANT EXECUTE ON FUNCTION ml.link_prediction TO PUBLIC;
GRANT EXECUTE ON FUNCTION ml.calibrate_confidence TO PUBLIC;
GRANT EXECUTE ON FUNCTION ml.refresh_tx_confidence TO PUBLIC;