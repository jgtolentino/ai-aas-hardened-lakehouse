-- Scout Dashboard Schema Migration
-- Version: 6.0
-- Date: 2025-08-29

-- Create scout schema
CREATE SCHEMA IF NOT EXISTS scout;

-- Enable Row Level Security
ALTER SCHEMA scout OWNER TO postgres;

-- Create bronze layer table (raw data ingestion)
CREATE TABLE scout.bronze_data (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source TEXT NOT NULL,
    raw_payload JSONB NOT NULL,
    ingestion_timestamp TIMESTAMPTZ DEFAULT NOW(),
    meta JSONB
);

-- Create silver layer view (validated data)
CREATE OR REPLACE VIEW scout.silver_data AS
SELECT 
    id,
    source,
    raw_payload,
    ingestion_timestamp
FROM scout.bronze_data
WHERE raw_payload IS NOT NULL;

-- Create gold layer materialized view (AI-ready transformations)
CREATE MATERIALIZED VIEW scout.gold_metrics AS
SELECT 
    source,
    COUNT(*) as total_records,
    AVG((raw_payload->>'value')::NUMERIC) as avg_value,
    MAX((raw_payload->>'timestamp')::TIMESTAMPTZ) as latest_timestamp
FROM scout.silver_data
GROUP BY source;

-- RLS Policies
CREATE POLICY "Enable read access for authenticated users" 
ON scout.bronze_data FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "Enable read access for authenticated users" 
ON scout.silver_data FOR SELECT 
TO authenticated 
USING (true);

-- Indexes for performance
CREATE INDEX idx_bronze_source ON scout.bronze_data(source);
CREATE INDEX idx_bronze_ingestion_timestamp ON scout.bronze_data(ingestion_timestamp);

-- Create function for AI insights
CREATE OR REPLACE FUNCTION scout.generate_ai_insight(
    p_source TEXT, 
    p_timeframe INTERVAL DEFAULT '30 days'
) 
RETURNS JSONB 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    -- Placeholder for AI insight generation logic
    SELECT jsonb_build_object(
        'source', p_source,
        'insight_type', 'trend_analysis',
        'timeframe', p_timeframe::TEXT,
        'confidence_score', 0.85
    ) INTO result;
    
    RETURN result;
END;
$$;

-- Create RPC for dashboard metrics
CREATE OR REPLACE FUNCTION scout.api_get_dashboard_metrics(
    p_brand TEXT DEFAULT NULL,
    p_region TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'kpis', jsonb_build_object(
            'total_records', (SELECT COUNT(*) FROM scout.bronze_data),
            'unique_sources', (SELECT COUNT(DISTINCT source) FROM scout.bronze_data),
            'latest_ingestion', (SELECT MAX(ingestion_timestamp) FROM scout.bronze_data)
        ),
        'ai_insights', scout.generate_ai_insight('default_source')
    ) INTO result;
    
    RETURN result;
END;
$$;

-- Grant execute permissions to authenticated role
GRANT EXECUTE ON FUNCTION scout.api_get_dashboard_metrics(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION scout.generate_ai_insight(TEXT, INTERVAL) TO authenticated;
