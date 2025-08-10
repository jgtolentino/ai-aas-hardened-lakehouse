-- ============================================================================
-- Scout Medallion Architecture - Database Schemas
-- Bronze → Silver → Gold → Platinum transformation layers
-- ============================================================================

-- Create medallion schemas
CREATE SCHEMA IF NOT EXISTS scout_bronze;
CREATE SCHEMA IF NOT EXISTS scout_silver;
CREATE SCHEMA IF NOT EXISTS scout_gold;
CREATE SCHEMA IF NOT EXISTS scout_platinum;

-- Grant appropriate permissions
GRANT USAGE ON SCHEMA scout_bronze TO service_role;
GRANT USAGE ON SCHEMA scout_silver TO service_role, authenticated;
GRANT USAGE ON SCHEMA scout_gold TO service_role, authenticated, anon;
GRANT USAGE ON SCHEMA scout_platinum TO service_role, authenticated;

-- Set schema comments for documentation
COMMENT ON SCHEMA scout_bronze IS 'Raw data landing zone from edge devices - no transformations';
COMMENT ON SCHEMA scout_silver IS 'Cleaned, validated, and normalized data with proper types';
COMMENT ON SCHEMA scout_gold IS 'Business-ready aggregates and analytics datasets';
COMMENT ON SCHEMA scout_platinum IS 'ML features, AI training data, and specialized exports';

-- Create a metadata tracking table for lineage
CREATE TABLE IF NOT EXISTS scout.medallion_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    layer TEXT NOT NULL CHECK (layer IN ('bronze', 'silver', 'gold', 'platinum')),
    table_name TEXT NOT NULL,
    source_table TEXT,
    transformation_type TEXT,
    row_count BIGINT,
    data_quality_score DECIMAL(5,2),
    processing_time_ms INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(layer, table_name)
);

-- Index for efficient metadata queries
CREATE INDEX IF NOT EXISTS idx_medallion_metadata_layer 
ON scout.medallion_metadata(layer, updated_at DESC);

-- Function to update medallion metadata
CREATE OR REPLACE FUNCTION scout.update_medallion_metadata(
    p_layer TEXT,
    p_table_name TEXT,
    p_source_table TEXT DEFAULT NULL,
    p_transformation_type TEXT DEFAULT NULL,
    p_row_count BIGINT DEFAULT NULL,
    p_data_quality_score DECIMAL DEFAULT NULL,
    p_processing_time_ms INTEGER DEFAULT NULL
) RETURNS void AS $$
BEGIN
    INSERT INTO scout.medallion_metadata (
        layer,
        table_name,
        source_table,
        transformation_type,
        row_count,
        data_quality_score,
        processing_time_ms
    ) VALUES (
        p_layer,
        p_table_name,
        p_source_table,
        p_transformation_type,
        p_row_count,
        p_data_quality_score,
        p_processing_time_ms
    )
    ON CONFLICT (layer, table_name) 
    DO UPDATE SET
        source_table = EXCLUDED.source_table,
        transformation_type = EXCLUDED.transformation_type,
        row_count = EXCLUDED.row_count,
        data_quality_score = EXCLUDED.data_quality_score,
        processing_time_ms = EXCLUDED.processing_time_ms,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;