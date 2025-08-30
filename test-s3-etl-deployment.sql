-- Test S3 ETL Pipeline Deployment
-- Copy and paste this script into Supabase SQL Editor

-- 1. Check if ETL tables exist
SELECT 'ETL Tables Check' as test_name;
SELECT 
    schemaname,
    tablename,
    tableowner
FROM pg_tables 
WHERE schemaname = 'scout' 
    AND (tablename LIKE '%storage%' 
         OR tablename LIKE '%etl%' 
         OR tablename LIKE '%bronze%' 
         OR tablename LIKE '%silver%')
ORDER BY schemaname, tablename;

-- 2. If tables don't exist, create them (run the migration)
-- First check if scout schema exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'scout') THEN
        CREATE SCHEMA scout;
    END IF;
END
$$;

-- Create external storage config table
CREATE TABLE IF NOT EXISTS scout.external_storage_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    environment TEXT CHECK (environment IN ('development', 'staging', 'production')),
    storage_type TEXT CHECK (storage_type IN ('s3', 'adls2', 'gcs', 'supabase')),
    
    -- S3 Configuration
    s3_bucket TEXT,
    s3_region TEXT DEFAULT 'us-east-1',
    s3_access_key_id TEXT,
    s3_secret_access_key TEXT,
    s3_endpoint TEXT,
    
    -- ADLS2 Configuration
    adls2_account_name TEXT,
    adls2_container TEXT,
    adls2_sas_token TEXT,
    adls2_connection_string TEXT,
    
    -- Common settings
    path_prefix TEXT,
    file_format TEXT CHECK (file_format IN ('parquet', 'csv', 'json', 'avro', 'delta')),
    compression TEXT CHECK (compression IN ('none', 'gzip', 'snappy', 'lz4', 'zstd')),
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(environment, storage_type)
);

-- Insert sample configurations
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

-- Production: Real data bucket (example)
('production', 's3', 'scout-production-data', 'us-east-1', 'prod/', 'parquet', 'snappy')
ON CONFLICT (environment, storage_type) DO UPDATE
SET 
    path_prefix = EXCLUDED.path_prefix,
    file_format = EXCLUDED.file_format,
    updated_at = NOW();

-- Create Bronze layer table
CREATE TABLE IF NOT EXISTS scout.bronze_transactions (
    _raw_id UUID DEFAULT gen_random_uuid(),
    _source_file TEXT NOT NULL,
    _loaded_at TIMESTAMPTZ DEFAULT NOW(),
    _raw_data JSONB,
    
    -- Parsed fields
    transaction_id TEXT,
    store_id TEXT,
    timestamp TEXT,
    total_amount TEXT,
    items JSONB,
    payment_method TEXT,
    customer_segment TEXT,
    
    PRIMARY KEY (_raw_id)
);

-- Create Silver layer table  
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

-- 3. Test configuration
SELECT 'Storage Configuration Check' as test_name;
SELECT 
    environment,
    storage_type,
    s3_bucket,
    path_prefix,
    file_format,
    is_active
FROM scout.external_storage_config
ORDER BY environment, storage_type;

-- 4. Insert sample data for testing
INSERT INTO scout.bronze_transactions (
    _source_file,
    _raw_data,
    transaction_id,
    store_id,
    timestamp,
    total_amount,
    payment_method,
    customer_segment
) VALUES
('samples/transactions/2024/01/sample_data.json', 
 '{"id": "txn_001", "store": "store_001", "amount": 123.45}',
 'txn_001', 'store_001', '2024-01-15 10:30:00', '123.45', 'credit_card', 'premium'),
('samples/transactions/2024/01/sample_data.json',
 '{"id": "txn_002", "store": "store_002", "amount": 67.89}', 
 'txn_002', 'store_002', '2024-01-15 11:45:00', '67.89', 'cash', 'regular')
ON CONFLICT (_raw_id) DO NOTHING;

-- 5. Test Bronze to Silver processing
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
ON CONFLICT (transaction_id) DO UPDATE
SET 
    total_amount = EXCLUDED.total_amount,
    processed_at = NOW();

-- 6. Verify data flow
SELECT 'Data Flow Verification' as test_name;
SELECT 
    'Bronze Layer' as layer,
    COUNT(*) as record_count
FROM scout.bronze_transactions
UNION ALL
SELECT 
    'Silver Layer' as layer,
    COUNT(*) as record_count
FROM scout.silver_transactions;

-- 7. Show sample processed data
SELECT 'Sample Processed Data' as test_name;
SELECT 
    s.transaction_id,
    s.store_id,
    s.transaction_timestamp,
    s.total_amount,
    s.payment_method,
    s.customer_segment,
    s.is_valid,
    b._source_file
FROM scout.silver_transactions s
JOIN scout.bronze_transactions b ON s.bronze_id = b._raw_id
ORDER BY s.transaction_timestamp
LIMIT 5;

SELECT 'ETL Pipeline Test Complete ✅' as status;