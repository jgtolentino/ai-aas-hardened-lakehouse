-- ML Monitoring & Confidence Calibration Schema
-- Production ML operations: predictions, labels, metrics, calibration

CREATE SCHEMA IF NOT EXISTS ml;

-- Prediction event logging
CREATE TABLE IF NOT EXISTS ml.prediction_events (
    id BIGSERIAL PRIMARY KEY,
    model_name VARCHAR(100) NOT NULL,
    model_version VARCHAR(50) NOT NULL,
    
    -- Input/Output
    input_text TEXT,
    predicted_class VARCHAR(100),
    confidence DECIMAL(5,4) NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
    prediction_metadata JSONB,
    
    -- Context
    request_id UUID DEFAULT gen_random_uuid(),
    session_id VARCHAR(100),
    user_id VARCHAR(100),
    store_id VARCHAR(50),
    region VARCHAR(50),
    
    -- Timing
    prediction_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    latency_ms INTEGER,
    
    -- For joining to transactions
    transaction_id VARCHAR(100),
    product_id INTEGER,
    sku_id INTEGER
);

-- Ground truth labels
CREATE TABLE IF NOT EXISTS ml.labels (
    id SERIAL PRIMARY KEY,
    prediction_id BIGINT NOT NULL REFERENCES ml.prediction_events(id),
    true_class VARCHAR(100) NOT NULL,
    labeled_by VARCHAR(100),
    label_source VARCHAR(50), -- 'human', 'auto', 'feedback'
    confidence_score DECIMAL(3,2), -- How sure we are about this label
    labeled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    
    UNIQUE(prediction_id)
);

-- Calibration bins for reliability
CREATE TABLE IF NOT EXISTS ml.calibration_bins (
    id SERIAL PRIMARY KEY,
    model_name VARCHAR(100) NOT NULL,
    model_version VARCHAR(50) NOT NULL,
    date_computed DATE NOT NULL,
    
    bin_index INTEGER NOT NULL,
    confidence_min DECIMAL(5,4) NOT NULL,
    confidence_max DECIMAL(5,4) NOT NULL,
    confidence_avg DECIMAL(5,4) NOT NULL,
    accuracy DECIMAL(5,4) NOT NULL,
    sample_count INTEGER NOT NULL,
    
    UNIQUE(model_name, model_version, date_computed, bin_index)
);

-- Daily metrics
CREATE TABLE IF NOT EXISTS ml.metrics_daily (
    id SERIAL PRIMARY KEY,
    model_name VARCHAR(100) NOT NULL,
    model_version VARCHAR(50) NOT NULL,
    day DATE NOT NULL,
    
    -- Volume
    prediction_count INTEGER NOT NULL DEFAULT 0,
    labeled_count INTEGER NOT NULL DEFAULT 0,
    
    -- Performance (when labels available)
    accuracy DECIMAL(5,4),
    precision_macro DECIMAL(5,4),
    recall_macro DECIMAL(5,4),
    f1_macro DECIMAL(5,4),
    
    -- Calibration
    ece DECIMAL(5,4), -- Expected Calibration Error
    mce DECIMAL(5,4), -- Maximum Calibration Error
    
    -- Confidence distribution
    confidence_mean DECIMAL(5,4),
    confidence_std DECIMAL(5,4),
    confidence_p10 DECIMAL(5,4),
    confidence_p50 DECIMAL(5,4),
    confidence_p90 DECIMAL(5,4),
    
    -- Class distribution
    class_distribution JSONB,
    
    computed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(model_name, model_version, day)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_ml_predictions_timestamp ON ml.prediction_events(prediction_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_ml_predictions_model ON ml.prediction_events(model_name, model_version);
CREATE INDEX IF NOT EXISTS idx_ml_predictions_class ON ml.prediction_events(predicted_class);
CREATE INDEX IF NOT EXISTS idx_ml_predictions_confidence ON ml.prediction_events(confidence);
CREATE INDEX IF NOT EXISTS idx_ml_predictions_transaction ON ml.prediction_events(transaction_id) WHERE transaction_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ml_labels_prediction ON ml.labels(prediction_id);
CREATE INDEX IF NOT EXISTS idx_ml_labels_true_class ON ml.labels(true_class);

-- Function to log predictions
CREATE OR REPLACE FUNCTION ml.log_prediction(
    p_model_name VARCHAR,
    p_model_version VARCHAR,
    p_input_text TEXT,
    p_predicted_class VARCHAR,
    p_confidence DECIMAL,
    p_metadata JSONB DEFAULT '{}',
    p_latency_ms INTEGER DEFAULT NULL,
    p_context JSONB DEFAULT '{}'
)
RETURNS BIGINT AS $$
DECLARE
    v_prediction_id BIGINT;
BEGIN
    INSERT INTO ml.prediction_events (
        model_name,
        model_version,
        input_text,
        predicted_class,
        confidence,
        prediction_metadata,
        latency_ms,
        request_id,
        session_id,
        user_id,
        store_id,
        region,
        transaction_id,
        product_id,
        sku_id
    ) VALUES (
        p_model_name,
        p_model_version,
        p_input_text,
        p_predicted_class,
        p_confidence,
        p_metadata,
        p_latency_ms,
        COALESCE((p_context->>'request_id')::UUID, gen_random_uuid()),
        p_context->>'session_id',
        p_context->>'user_id',
        p_context->>'store_id',
        p_context->>'region',
        p_context->>'transaction_id',
        (p_context->>'product_id')::INTEGER,
        (p_context->>'sku_id')::INTEGER
    ) RETURNING id INTO v_prediction_id;
    
    RETURN v_prediction_id;
END;
$$ LANGUAGE plpgsql;

-- View for reliability analysis (last 30 days)
CREATE OR REPLACE VIEW ml.v_reliability_window AS
WITH predictions_labeled AS (
    SELECT 
        p.model_name,
        p.model_version,
        p.confidence,
        p.predicted_class,
        l.true_class,
        p.predicted_class = l.true_class AS is_correct,
        p.prediction_timestamp
    FROM ml.prediction_events p
    JOIN ml.labels l ON p.id = l.prediction_id
    WHERE p.prediction_timestamp >= CURRENT_DATE - INTERVAL '30 days'
),
binned AS (
    SELECT
        model_name,
        model_version,
        WIDTH_BUCKET(confidence, 0, 1, 10) as bin,
        COUNT(*) as count,
        AVG(confidence) as avg_confidence,
        AVG(is_correct::INT) as accuracy
    FROM predictions_labeled
    GROUP BY model_name, model_version, bin
)
SELECT 
    model_name,
    model_version,
    bin,
    avg_confidence,
    accuracy,
    count,
    ABS(avg_confidence - accuracy) as calibration_error
FROM binned
ORDER BY model_name, model_version, bin;

-- View for ECE calculation
CREATE OR REPLACE VIEW ml.v_ece_window AS
WITH reliability AS (
    SELECT * FROM ml.v_reliability_window
),
totals AS (
    SELECT 
        model_name,
        model_version,
        SUM(count) as total_count
    FROM reliability
    GROUP BY model_name, model_version
)
SELECT 
    r.model_name,
    r.model_version,
    SUM((r.count::DECIMAL / t.total_count) * r.calibration_error) as ece,
    MAX(r.calibration_error) as mce,
    t.total_count as sample_size
FROM reliability r
JOIN totals t ON r.model_name = t.model_name AND r.model_version = t.model_version
GROUP BY r.model_name, r.model_version, t.total_count;

-- Function to compute daily metrics
CREATE OR REPLACE FUNCTION ml.compute_daily_metrics(p_date DATE)
RETURNS void AS $$
DECLARE
    v_model RECORD;
    v_metrics RECORD;
BEGIN
    -- For each model version active on this date
    FOR v_model IN 
        SELECT DISTINCT model_name, model_version
        FROM ml.prediction_events
        WHERE DATE(prediction_timestamp) = p_date
    LOOP
        -- Compute metrics
        WITH predictions AS (
            SELECT p.*, l.true_class
            FROM ml.prediction_events p
            LEFT JOIN ml.labels l ON p.id = l.prediction_id
            WHERE p.model_name = v_model.model_name
              AND p.model_version = v_model.model_version
              AND DATE(p.prediction_timestamp) = p_date
        ),
        stats AS (
            SELECT
                COUNT(*) as prediction_count,
                COUNT(true_class) as labeled_count,
                AVG(CASE WHEN predicted_class = true_class THEN 1.0 ELSE 0.0 END) as accuracy,
                AVG(confidence) as confidence_mean,
                STDDEV(confidence) as confidence_std,
                PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY confidence) as confidence_p10,
                PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY confidence) as confidence_p50,
                PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY confidence) as confidence_p90
            FROM predictions
        ),
        class_dist AS (
            SELECT jsonb_object_agg(predicted_class, count) as distribution
            FROM (
                SELECT predicted_class, COUNT(*) as count
                FROM predictions
                GROUP BY predicted_class
            ) t
        )
        INSERT INTO ml.metrics_daily (
            model_name,
            model_version,
            day,
            prediction_count,
            labeled_count,
            accuracy,
            confidence_mean,
            confidence_std,
            confidence_p10,
            confidence_p50,
            confidence_p90,
            class_distribution
        )
        SELECT
            v_model.model_name,
            v_model.model_version,
            p_date,
            s.prediction_count,
            s.labeled_count,
            s.accuracy,
            s.confidence_mean,
            s.confidence_std,
            s.confidence_p10,
            s.confidence_p50,
            s.confidence_p90,
            c.distribution
        FROM stats s, class_dist c
        ON CONFLICT (model_name, model_version, day) 
        DO UPDATE SET
            prediction_count = EXCLUDED.prediction_count,
            labeled_count = EXCLUDED.labeled_count,
            accuracy = EXCLUDED.accuracy,
            confidence_mean = EXCLUDED.confidence_mean,
            confidence_std = EXCLUDED.confidence_std,
            confidence_p10 = EXCLUDED.confidence_p10,
            confidence_p50 = EXCLUDED.confidence_p50,
            confidence_p90 = EXCLUDED.confidence_p90,
            class_distribution = EXCLUDED.class_distribution,
            computed_at = CURRENT_TIMESTAMP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Grants
GRANT USAGE ON SCHEMA ml TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA ml TO PUBLIC;
GRANT INSERT ON ml.prediction_events, ml.labels TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ml TO PUBLIC;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA ml TO PUBLIC;