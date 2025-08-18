-- Brand Detection Schema Migration
-- Medallion Architecture: Bronze → Silver → Gold → Platinum/AI

-- Ensure scout schema exists
CREATE SCHEMA IF NOT EXISTS scout;

-- ===========================================
-- BRONZE LAYER: Raw Events
-- ===========================================

CREATE TABLE IF NOT EXISTS scout.bronze_raw_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payload JSONB NOT NULL,
    source_file TEXT,
    event_hash BYTEA UNIQUE,
    ingested_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for bronze layer
CREATE INDEX IF NOT EXISTS idx_bronze_events_ingested_at ON scout.bronze_raw_events(ingested_at);
CREATE INDEX IF NOT EXISTS idx_bronze_events_source_file ON scout.bronze_raw_events(source_file);
CREATE INDEX IF NOT EXISTS idx_bronze_events_payload_gin ON scout.bronze_raw_events USING GIN(payload);

-- ===========================================
-- SILVER LAYER: Normalized Events
-- ===========================================

CREATE TABLE IF NOT EXISTS scout.silver_normalized_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bronze_id UUID REFERENCES scout.bronze_raw_events(id),
    text_input TEXT NOT NULL,
    context JSONB DEFAULT '{}',
    source_file TEXT,
    normalized_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for silver layer
CREATE INDEX IF NOT EXISTS idx_silver_events_bronze_id ON scout.silver_normalized_events(bronze_id);
CREATE INDEX IF NOT EXISTS idx_silver_events_normalized_at ON scout.silver_normalized_events(normalized_at);
CREATE INDEX IF NOT EXISTS idx_silver_events_text_gin ON scout.silver_normalized_events USING GIN(to_tsvector('english', text_input));

-- ===========================================
-- GOLD LAYER: Brand Predictions
-- ===========================================

CREATE TABLE IF NOT EXISTS scout.gold_brand_predictions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    silver_id UUID REFERENCES scout.silver_normalized_events(id),
    text_input TEXT NOT NULL,
    brand TEXT NOT NULL,
    confidence DECIMAL(5,4) NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
    model_version TEXT NOT NULL,
    dictionary_version TEXT NOT NULL,
    context JSONB DEFAULT '{}',
    predicted_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for gold layer
CREATE INDEX IF NOT EXISTS idx_gold_predictions_silver_id ON scout.gold_brand_predictions(silver_id);
CREATE INDEX IF NOT EXISTS idx_gold_predictions_brand ON scout.gold_brand_predictions(brand);
CREATE INDEX IF NOT EXISTS idx_gold_predictions_confidence ON scout.gold_brand_predictions(confidence);
CREATE INDEX IF NOT EXISTS idx_gold_predictions_predicted_at ON scout.gold_brand_predictions(predicted_at);
CREATE INDEX IF NOT EXISTS idx_gold_predictions_text_gin ON scout.gold_brand_predictions USING GIN(to_tsvector('english', text_input));

-- ===========================================
-- METADATA & LINEAGE TABLES
-- ===========================================

-- Dictionary versioning
CREATE TABLE IF NOT EXISTS scout.data_dictionary_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version TEXT UNIQUE NOT NULL,
    checksum TEXT NOT NULL,
    dictionary_data JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ETL run tracking
CREATE TABLE IF NOT EXISTS scout.prediction_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bronze_rows INTEGER NOT NULL DEFAULT 0,
    silver_rows INTEGER NOT NULL DEFAULT 0,
    gold_rows INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL CHECK (status IN ('success', 'failed', 'running')),
    error_message TEXT,
    run_at TIMESTAMP DEFAULT NOW(),
    duration_seconds DECIMAL(10,3)
);

-- Model metrics for observability
CREATE TABLE IF NOT EXISTS scout.model_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    value DECIMAL(15,6) NOT NULL,
    labels JSONB DEFAULT '{}',
    recorded_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for metadata tables
CREATE INDEX IF NOT EXISTS idx_dictionary_versions_version ON scout.data_dictionary_versions(version);
CREATE INDEX IF NOT EXISTS idx_prediction_runs_run_at ON scout.prediction_runs(run_at);
CREATE INDEX IF NOT EXISTS idx_prediction_runs_status ON scout.prediction_runs(status);
CREATE INDEX IF NOT EXISTS idx_model_metrics_name ON scout.model_metrics(name);
CREATE INDEX IF NOT EXISTS idx_model_metrics_recorded_at ON scout.model_metrics(recorded_at);
CREATE INDEX IF NOT EXISTS idx_model_metrics_labels_gin ON scout.model_metrics USING GIN(labels);

-- ===========================================
-- PLATINUM LAYER: DAL Views & RPCs
-- ===========================================

-- Create DAL schema for data access layer
CREATE SCHEMA IF NOT EXISTS dal;

-- Brand predictions view with enriched data
CREATE OR REPLACE VIEW dal.vw_brand_predictions AS
SELECT 
    bp.id,
    bp.text_input,
    bp.brand,
    bp.confidence,
    bp.model_version,
    bp.dictionary_version,
    bp.context,
    bp.predicted_at,
    se.source_file,
    se.normalized_at,
    CASE 
        WHEN bp.confidence >= 0.8 THEN 'high'
        WHEN bp.confidence >= 0.5 THEN 'medium'
        ELSE 'low'
    END as confidence_level,
    -- Brand category from context or derived
    COALESCE(
        bp.context->>'category',
        CASE 
            WHEN bp.brand IN ('coke', 'pepsi', 'dr_pepper') THEN 'cola'
            WHEN bp.brand IN ('sprite', 'seven_up') THEN 'lemon_lime'
            WHEN bp.brand IN ('red_bull', 'monster') THEN 'energy_drink'
            WHEN bp.brand IN ('gatorade', 'powerade') THEN 'sports_drink'
            WHEN bp.brand = 'mountain_dew' THEN 'citrus'
            ELSE 'unknown'
        END
    ) as brand_category
FROM scout.gold_brand_predictions bp
LEFT JOIN scout.silver_normalized_events se ON bp.silver_id = se.id
WHERE bp.predicted_at >= NOW() - INTERVAL '30 days';

-- KPI summary view
CREATE OR REPLACE VIEW dal.vw_kpis AS
SELECT 
    COUNT(*) as total_predictions,
    COUNT(DISTINCT brand) as unique_brands,
    AVG(confidence) as avg_confidence,
    COUNT(*) FILTER (WHERE confidence >= 0.8) as high_confidence_predictions,
    COUNT(*) FILTER (WHERE confidence < 0.5) as low_confidence_predictions,
    COUNT(*) FILTER (WHERE predicted_at >= NOW() - INTERVAL '1 day') as predictions_last_24h,
    COUNT(*) FILTER (WHERE predicted_at >= NOW() - INTERVAL '7 days') as predictions_last_7d,
    -- Top brands
    (
        SELECT json_agg(json_build_object('brand', brand, 'count', cnt))
        FROM (
            SELECT brand, COUNT(*) as cnt
            FROM scout.gold_brand_predictions 
            WHERE predicted_at >= NOW() - INTERVAL '7 days'
            GROUP BY brand 
            ORDER BY cnt DESC 
            LIMIT 5
        ) top_brands
    ) as top_brands_7d
FROM scout.gold_brand_predictions
WHERE predicted_at >= NOW() - INTERVAL '30 days';

-- ===========================================
-- STORED PROCEDURES
-- ===========================================

-- Brand prediction RPC
CREATE OR REPLACE FUNCTION dal.predict_brand(input_text TEXT)
RETURNS TABLE(
    brand TEXT,
    confidence DECIMAL,
    model_version TEXT,
    dictionary_version TEXT
) 
LANGUAGE plpgsql
AS $$
BEGIN
    -- This is a placeholder - actual prediction logic would call the API
    -- or implement the matching logic in PL/pgSQL
    RETURN QUERY
    SELECT 
        'generic'::TEXT as brand,
        0.1::DECIMAL as confidence,
        '1.0.0'::TEXT as model_version,
        'default'::TEXT as dictionary_version;
END;
$$;

-- Get brand statistics RPC
CREATE OR REPLACE FUNCTION dal.get_brand_stats(days_back INTEGER DEFAULT 7)
RETURNS TABLE(
    brand TEXT,
    prediction_count BIGINT,
    avg_confidence DECIMAL,
    first_seen TIMESTAMP,
    last_seen TIMESTAMP
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        bp.brand,
        COUNT(*)::BIGINT as prediction_count,
        AVG(bp.confidence) as avg_confidence,
        MIN(bp.predicted_at) as first_seen,
        MAX(bp.predicted_at) as last_seen
    FROM scout.gold_brand_predictions bp
    WHERE bp.predicted_at >= NOW() - (days_back || ' days')::INTERVAL
    GROUP BY bp.brand
    ORDER BY prediction_count DESC;
END;
$$;

-- ETL metrics RPC
CREATE OR REPLACE FUNCTION dal.get_etl_metrics(hours_back INTEGER DEFAULT 24)
RETURNS TABLE(
    total_runs BIGINT,
    successful_runs BIGINT,
    failed_runs BIGINT,
    avg_bronze_rows DECIMAL,
    avg_silver_rows DECIMAL,
    avg_gold_rows DECIMAL,
    avg_duration_seconds DECIMAL
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_runs,
        COUNT(*) FILTER (WHERE status = 'success')::BIGINT as successful_runs,
        COUNT(*) FILTER (WHERE status = 'failed')::BIGINT as failed_runs,
        AVG(bronze_rows) as avg_bronze_rows,
        AVG(silver_rows) as avg_silver_rows,
        AVG(gold_rows) as avg_gold_rows,
        AVG(duration_seconds) as avg_duration_seconds
    FROM scout.prediction_runs
    WHERE run_at >= NOW() - (hours_back || ' hours')::INTERVAL;
END;
$$;

-- ===========================================
-- PERMISSIONS & SECURITY
-- ===========================================

-- Grant permissions on the DAL views and functions
GRANT USAGE ON SCHEMA dal TO PUBLIC;
GRANT SELECT ON dal.vw_brand_predictions TO PUBLIC;
GRANT SELECT ON dal.vw_kpis TO PUBLIC;
GRANT EXECUTE ON FUNCTION dal.predict_brand(TEXT) TO PUBLIC;
GRANT EXECUTE ON FUNCTION dal.get_brand_stats(INTEGER) TO PUBLIC;
GRANT EXECUTE ON FUNCTION dal.get_etl_metrics(INTEGER) TO PUBLIC;

-- Row Level Security (optional)
-- ALTER TABLE scout.gold_brand_predictions ENABLE ROW LEVEL SECURITY;

COMMENT ON SCHEMA scout IS 'Brand detection medallion architecture: Bronze → Silver → Gold';
COMMENT ON SCHEMA dal IS 'Data Access Layer for brand detection API and dashboards';
COMMENT ON TABLE scout.bronze_raw_events IS 'Bronze layer: Raw event ingestion with deduplication';
COMMENT ON TABLE scout.silver_normalized_events IS 'Silver layer: Normalized and cleaned events';
COMMENT ON TABLE scout.gold_brand_predictions IS 'Gold layer: Brand predictions with confidence scores';
COMMENT ON VIEW dal.vw_brand_predictions IS 'Enriched brand predictions for API consumption';
COMMENT ON VIEW dal.vw_kpis IS 'KPI dashboard metrics for monitoring';