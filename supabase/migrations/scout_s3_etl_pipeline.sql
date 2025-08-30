-- S3/ADLS2 ETL Pipeline Architecture for Scout Dashboard
-- This implementation uses Supabase Edge Functions to pull from S3/ADLS2

-- ============================================
-- STORAGE CONFIGURATION
-- ============================================

-- 1. External Storage Configuration
CREATE TABLE IF NOT EXISTS scout.external_storage_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    environment TEXT CHECK (environment IN ('development', 'staging', 'production')),
    storage_type TEXT CHECK (storage_type IN ('s3', 'adls2', 'gcs', 'supabase')),
    
    -- S3 Configuration
    s3_bucket TEXT,
    s3_region TEXT DEFAULT 'us-east-1',
    s3_access_key_id TEXT, -- Store encrypted
    s3_secret_access_key TEXT, -- Store encrypted
    s3_endpoint TEXT, -- For S3-compatible storage (MinIO, etc.)
    
    -- ADLS2 Configuration
    adls2_account_name TEXT,
    adls2_container TEXT,
    adls2_sas_token TEXT, -- Store encrypted
    adls2_connection_string TEXT, -- Store encrypted
    
    -- Common settings
    path_prefix TEXT, -- e.g., 'raw/', 'processed/', 'archive/'
    file_format TEXT CHECK (file_format IN ('parquet', 'csv', 'json', 'avro', 'delta')),
    compression TEXT CHECK (compression IN ('none', 'gzip', 'snappy', 'lz4', 'zstd')),
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(environment, storage_type)
);

-- 2. Insert configurations for different environments
INSERT INTO scout.external_storage_config (
    environment, 
    storage_type, 
    s3_bucket, 
    s3_region, 
    path_prefix,
    file_format,
    compression
) VALUES
-- Development: Sample data bucket
('development', 's3', 'scout-sample-data', 'us-east-1', 'samples/', 'parquet', 'snappy'),

-- Staging: Pre-production data
('staging', 's3', 'scout-staging-data', 'us-east-1', 'staging/', 'parquet', 'snappy'),

-- Production: Real data bucket
('production', 's3', 'scout-production-data', 'us-east-1', 'prod/', 'parquet', 'snappy'),

-- ADLS2 Alternative for Azure deployments
('production', 'adls2', NULL, NULL, 'datalake/', 'delta', 'snappy')
ON CONFLICT (environment, storage_type) DO UPDATE
SET 
    path_prefix = EXCLUDED.path_prefix,
    file_format = EXCLUDED.file_format,
    updated_at = NOW();

-- ============================================
-- ETL PIPELINE TABLES
-- ============================================

-- 3. ETL Pipeline Configuration
CREATE TABLE IF NOT EXISTS scout.etl_pipelines (
    pipeline_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pipeline_name TEXT NOT NULL UNIQUE,
    pipeline_type TEXT CHECK (pipeline_type IN ('batch', 'streaming', 'hybrid')),
    
    -- Source configuration
    source_storage_id UUID REFERENCES scout.external_storage_config(id),
    source_path_pattern TEXT, -- e.g., 'transactions/year={year}/month={month}/*.parquet'
    
    -- Processing configuration
    processing_steps JSONB DEFAULT '[]', -- Array of transformation steps
    
    -- Target configuration
    target_schema TEXT NOT NULL DEFAULT 'scout',
    target_table_prefix TEXT NOT NULL,
    
    -- Schedule
    schedule_cron TEXT, -- e.g., '0 */6 * * *' for every 6 hours
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. ETL Job Runs
CREATE TABLE IF NOT EXISTS scout.etl_job_runs (
    run_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pipeline_id UUID REFERENCES scout.etl_pipelines(pipeline_id),
    
    -- Run details
    run_type TEXT CHECK (run_type IN ('scheduled', 'manual', 'triggered', 'backfill')),
    status TEXT CHECK (status IN ('pending', 'running', 'completed', 'failed', 'cancelled')),
    
    -- Source details
    source_files TEXT[], -- Array of files processed
    source_bytes BIGINT,
    
    -- Processing metrics
    records_read BIGINT DEFAULT 0,
    records_processed BIGINT DEFAULT 0,
    records_failed BIGINT DEFAULT 0,
    records_written BIGINT DEFAULT 0,
    
    -- Timing
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    duration_seconds INTEGER GENERATED ALWAYS AS (
        EXTRACT(EPOCH FROM (completed_at - started_at))::INTEGER
    ) STORED,
    
    -- Error handling
    error_message TEXT,
    error_details JSONB,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- DATA LAKE LAYERS (Medallion Architecture)
-- ============================================

-- 5. Bronze Layer (Raw data from S3/ADLS2)
CREATE TABLE IF NOT EXISTS scout.bronze_transactions (
    -- Metadata
    _raw_id UUID DEFAULT gen_random_uuid(),
    _source_file TEXT NOT NULL,
    _loaded_at TIMESTAMPTZ DEFAULT NOW(),
    _raw_data JSONB, -- Original raw data
    
    -- Parsed fields (may have quality issues)
    transaction_id TEXT,
    store_id TEXT,
    timestamp TEXT, -- Keep as text initially
    total_amount TEXT, -- Keep as text initially
    items JSONB,
    payment_method TEXT,
    customer_segment TEXT,
    
    PRIMARY KEY (_raw_id)
);

-- 6. Silver Layer (Cleaned and validated)
CREATE TABLE IF NOT EXISTS scout.silver_transactions (
    transaction_id TEXT PRIMARY KEY,
    store_id TEXT NOT NULL,
    transaction_timestamp TIMESTAMPTZ NOT NULL,
    total_amount NUMERIC(10,2) NOT NULL,
    payment_method TEXT NOT NULL,
    customer_segment TEXT,
    
    -- Data quality flags
    is_valid BOOLEAN DEFAULT true,
    validation_errors TEXT[],
    
    -- Lineage
    bronze_id UUID REFERENCES scout.bronze_transactions(_raw_id),
    processed_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Partitioning hint
    year INTEGER GENERATED ALWAYS AS (EXTRACT(YEAR FROM transaction_timestamp)) STORED,
    month INTEGER GENERATED ALWAYS AS (EXTRACT(MONTH FROM transaction_timestamp)) STORED
);

-- 7. Gold Layer is already defined (scout_gold_transactions, etc.)
-- Just add source tracking
ALTER TABLE scout.scout_gold_transactions 
ADD COLUMN IF NOT EXISTS source_system TEXT DEFAULT 's3',
ADD COLUMN IF NOT EXISTS silver_id TEXT;

ALTER TABLE scout.scout_gold_transaction_items
ADD COLUMN IF NOT EXISTS source_system TEXT DEFAULT 's3';

-- ============================================
-- ETL FUNCTIONS
-- ============================================

-- 8. Function to initiate S3/ADLS2 data load
CREATE OR REPLACE FUNCTION scout.initiate_external_data_load(
    p_environment TEXT DEFAULT 'development',
    p_pipeline_name TEXT DEFAULT 'transactions_daily'
) RETURNS UUID AS $$
DECLARE
    v_run_id UUID;
    v_pipeline_id UUID;
    v_storage_config RECORD;
BEGIN
    -- Get pipeline configuration
    SELECT pipeline_id INTO v_pipeline_id
    FROM scout.etl_pipelines
    WHERE pipeline_name = p_pipeline_name
    AND is_active = true;
    
    IF v_pipeline_id IS NULL THEN
        RAISE EXCEPTION 'Pipeline % not found or inactive', p_pipeline_name;
    END IF;
    
    -- Get storage configuration
    SELECT * INTO v_storage_config
    FROM scout.external_storage_config
    WHERE environment = p_environment
    AND is_active = true
    LIMIT 1;
    
    -- Create job run
    INSERT INTO scout.etl_job_runs (
        pipeline_id,
        run_type,
        status,
        started_at
    ) VALUES (
        v_pipeline_id,
        'manual',
        'pending',
        NOW()
    ) RETURNING run_id INTO v_run_id;
    
    -- The actual data loading would be done by an Edge Function
    -- that reads from S3/ADLS2 and writes to bronze layer
    
    RETURN v_run_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Process Bronze to Silver
CREATE OR REPLACE FUNCTION scout.process_bronze_to_silver(
    p_batch_size INTEGER DEFAULT 1000
) RETURNS INTEGER AS $$
DECLARE
    v_processed INTEGER := 0;
BEGIN
    INSERT INTO scout.silver_transactions (
        transaction_id,
        store_id,
        transaction_timestamp,
        total_amount,
        payment_method,
        customer_segment,
        bronze_id
    )
    SELECT 
        transaction_id,
        store_id,
        timestamp::TIMESTAMPTZ,
        total_amount::NUMERIC,
        COALESCE(payment_method, 'cash'),
        COALESCE(customer_segment, 'regular'),
        _raw_id
    FROM scout.bronze_transactions
    WHERE _raw_id NOT IN (
        SELECT bronze_id FROM scout.silver_transactions 
        WHERE bronze_id IS NOT NULL
    )
    LIMIT p_batch_size
    ON CONFLICT (transaction_id) DO UPDATE
    SET 
        total_amount = EXCLUDED.total_amount,
        processed_at = NOW();
    
    GET DIAGNOSTICS v_processed = ROW_COUNT;
    RETURN v_processed;
END;
$$ LANGUAGE plpgsql;

-- 10. Process Silver to Gold
CREATE OR REPLACE FUNCTION scout.process_silver_to_gold(
    p_batch_size INTEGER DEFAULT 1000
) RETURNS INTEGER AS $$
DECLARE
    v_processed INTEGER := 0;
BEGIN
    INSERT INTO scout.scout_gold_transactions (
        transaction_id,
        store_id,
        ts_utc,
        total_amount,
        source_system,
        silver_id,
        created_at
    )
    SELECT 
        transaction_id,
        store_id,
        transaction_timestamp,
        total_amount,
        's3',
        transaction_id,
        NOW()
    FROM scout.silver_transactions
    WHERE is_valid = true
    AND transaction_id NOT IN (
        SELECT transaction_id FROM scout.scout_gold_transactions
    )
    LIMIT p_batch_size
    ON CONFLICT (transaction_id) DO NOTHING;
    
    GET DIAGNOSTICS v_processed = ROW_COUNT;
    RETURN v_processed;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- SAMPLE PIPELINES
-- ============================================

-- 11. Create sample pipelines
INSERT INTO scout.etl_pipelines (
    pipeline_name,
    pipeline_type,
    source_path_pattern,
    target_schema,
    target_table_prefix,
    schedule_cron,
    processing_steps
) VALUES
-- Daily transaction load
('transactions_daily', 'batch', 
 'transactions/dt={date}/*.parquet', 
 'scout', 'transactions',
 '0 2 * * *', -- 2 AM daily
 '[
    {"step": "validate", "rules": ["not_null", "date_format"]},
    {"step": "deduplicate", "key": "transaction_id"},
    {"step": "enrich", "lookup": "store_metadata"}
 ]'::JSONB),

-- Hourly incremental
('transactions_hourly', 'batch',
 'transactions/realtime/hour={hour}/*.json',
 'scout', 'transactions',
 '0 * * * *', -- Every hour
 '[
    {"step": "parse_json"},
    {"step": "validate"},
    {"step": "append"}
 ]'::JSONB),

-- Customer segments
('customer_segments', 'batch',
 'analytics/segments/dt={date}/*.parquet',
 'scout', 'segments',
 '0 6 * * *', -- 6 AM daily
 '[
    {"step": "validate"},
    {"step": "calculate_metrics"},
    {"step": "merge"}
 ]'::JSONB)
ON CONFLICT (pipeline_name) DO NOTHING;

-- ============================================
-- MONITORING & ALERTS
-- ============================================

-- 12. ETL Monitoring View
CREATE OR REPLACE VIEW scout.etl_monitoring AS
SELECT 
    p.pipeline_name,
    p.pipeline_type,
    r.run_id,
    r.status,
    r.started_at,
    r.completed_at,
    r.duration_seconds,
    r.records_processed,
    r.records_failed,
    CASE 
        WHEN r.records_processed > 0 
        THEN ROUND(100.0 * r.records_failed / r.records_processed, 2)
        ELSE 0
    END as error_rate_pct,
    r.error_message
FROM scout.etl_pipelines p
LEFT JOIN LATERAL (
    SELECT * FROM scout.etl_job_runs
    WHERE pipeline_id = p.pipeline_id
    ORDER BY created_at DESC
    LIMIT 1
) r ON true
WHERE p.is_active = true;

-- Grant permissions
GRANT SELECT ON scout.etl_monitoring TO anon, authenticated;
