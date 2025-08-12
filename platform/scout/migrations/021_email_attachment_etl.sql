-- ============================================================================
-- Email Attachment ETL Pipeline
-- Processes JSON/ZIP attachments from Eugene Valencia and other sources
-- ============================================================================

BEGIN;

-- 1) Email attachments tracking table
CREATE TABLE IF NOT EXISTS scout.email_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_email TEXT NOT NULL,
    sender_name TEXT,
    subject TEXT,
    filename TEXT NOT NULL,
    file_size BIGINT,
    mime_type TEXT,
    gmail_message_id TEXT UNIQUE,
    gmail_attachment_id TEXT,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Processing status
    processing_status TEXT DEFAULT 'pending' CHECK (processing_status IN ('pending', 'processing', 'completed', 'failed')),
    processed_at TIMESTAMPTZ,
    s3_path TEXT,
    records_processed INTEGER DEFAULT 0,
    records_failed INTEGER DEFAULT 0,
    error_message TEXT,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for efficient querying
CREATE INDEX idx_email_attachments_status ON scout.email_attachments(processing_status, received_at);
CREATE INDEX idx_email_attachments_sender ON scout.email_attachments(sender_email, received_at DESC);

-- 2) Bronze layer for email-sourced transactions
CREATE TABLE IF NOT EXISTS scout.bronze_email_transactions (
    source_type TEXT DEFAULT 'email_attachment',
    source_file TEXT NOT NULL,
    entry_name TEXT NOT NULL,
    sender_email TEXT,
    device_id TEXT,
    transaction_id TEXT,
    captured_at TIMESTAMPTZ,
    payload JSONB NOT NULL,
    ingested_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Data quality
    validation_status TEXT DEFAULT 'pending',
    validation_errors JSONB,
    
    PRIMARY KEY (source_file, entry_name)
);

-- 3) ETL watermarks for idempotency
CREATE TABLE IF NOT EXISTS scout.email_etl_watermarks (
    attachment_id UUID REFERENCES scout.email_attachments(id),
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    status TEXT NOT NULL,
    records_processed INTEGER DEFAULT 0,
    error_details JSONB,
    
    PRIMARY KEY (attachment_id)
);

-- 4) Transform function: Bronze → Silver
CREATE OR REPLACE FUNCTION scout.transform_email_bronze_to_silver()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = scout, public
AS $$
DECLARE
    v_processed INTEGER := 0;
    v_errors INTEGER := 0;
BEGIN
    -- Insert new records into silver layer
    WITH transformed AS (
        INSERT INTO scout.silver_transactions (
            id,
            ts,
            store_id,
            device_id,
            region,
            province,
            city,
            barangay,
            product_category,
            brand_name,
            sku,
            units_per_transaction,
            peso_value,
            basket_size,
            payment_method,
            customer_type,
            source_system
        )
        SELECT 
            COALESCE(payload->>'transaction_id', payload->>'id', gen_random_uuid()::text) AS id,
            COALESCE(
                (payload->>'timestamp')::timestamptz,
                (payload->>'captured_at')::timestamptz,
                captured_at
            ) AS ts,
            COALESCE(payload->>'store_id', device_id) AS store_id,
            device_id,
            COALESCE(payload->>'region', 'Unknown') AS region,
            COALESCE(payload->>'province', 'Unknown') AS province,
            COALESCE(payload->>'city', 'Unknown') AS city,
            COALESCE(payload->>'barangay', 'Unknown') AS barangay,
            COALESCE(payload->>'category', payload->>'product_category', 'Unknown') AS product_category,
            COALESCE(payload->>'brand', payload->>'brand_name', 'Unknown') AS brand_name,
            COALESCE(payload->>'sku', payload->>'product_code', 'Unknown') AS sku,
            COALESCE((payload->>'quantity')::integer, 1) AS units_per_transaction,
            COALESCE((payload->>'amount')::decimal, (payload->>'total')::decimal, 0) AS peso_value,
            COALESCE((payload->>'item_count')::integer, 1) AS basket_size,
            COALESCE(payload->>'payment_method', 'cash') AS payment_method,
            COALESCE(payload->>'customer_type', 'regular') AS customer_type,
            'email_attachment' AS source_system
        FROM scout.bronze_email_transactions
        WHERE validation_status = 'pending'
        ON CONFLICT (id) DO UPDATE SET
            ts = EXCLUDED.ts,
            updated_at = NOW()
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_processed FROM transformed;
    
    -- Mark processed records
    UPDATE scout.bronze_email_transactions
    SET validation_status = 'processed'
    WHERE validation_status = 'pending';
    
    -- Refresh Gold layer views
    REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_txn_daily;
    REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_product_mix;
    
    processed_count := v_processed;
    error_count := v_errors;
    RETURN NEXT;
END;
$$;

-- 5) Seed Eugene Valencia's pending attachments
INSERT INTO scout.email_attachments (
    sender_email,
    sender_name,
    subject,
    filename,
    file_size,
    mime_type,
    gmail_message_id,
    received_at,
    processing_status
) VALUES 
    ('eugene.valencia@tbwa.com', 'Eugene Valencia', 'Scout Device Data Batch 1', 'scout-device-batch1.zip', 1070080, 'application/zip', 'msg_batch1_' || gen_random_uuid(), NOW() - INTERVAL '2 days', 'pending'),
    ('eugene.valencia@tbwa.com', 'Eugene Valencia', 'Scout Device Data Batch 2', 'scout-device-batch2.zip', 576716, 'application/zip', 'msg_batch2_' || gen_random_uuid(), NOW() - INTERVAL '1 day', 'pending')
ON CONFLICT (gmail_message_id) DO NOTHING;

-- 6) Create scheduled job function
CREATE OR REPLACE FUNCTION scout.process_pending_email_attachments()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- Call the Edge Function
    SELECT content::jsonb INTO v_result
    FROM http((
        'POST',
        current_setting('app.settings.supabase_url') || '/functions/v1/process-email-attachments',
        ARRAY[http_header('Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'))],
        'application/json',
        '{}'::text
    )::http_request);
    
    RETURN v_result;
END;
$$;

-- 7) Create trigger for automatic processing
CREATE OR REPLACE FUNCTION scout.trigger_auto_process_attachments()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- When a new attachment is inserted, schedule processing
    IF NEW.processing_status = 'pending' AND 
       NEW.mime_type IN ('application/zip', 'application/x-zip-compressed', 'application/json') THEN
        -- Queue for processing (could call Edge Function here)
        NOTIFY email_attachment_ready, NEW.id::text;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER auto_process_email_attachments
AFTER INSERT ON scout.email_attachments
FOR EACH ROW
EXECUTE FUNCTION scout.trigger_auto_process_attachments();

-- 8) View for monitoring email attachment pipeline
CREATE OR REPLACE VIEW scout.v_email_attachment_pipeline AS
SELECT 
    ea.sender_email,
    ea.sender_name,
    COUNT(*) AS total_attachments,
    COUNT(*) FILTER (WHERE processing_status = 'pending') AS pending,
    COUNT(*) FILTER (WHERE processing_status = 'processing') AS processing,
    COUNT(*) FILTER (WHERE processing_status = 'completed') AS completed,
    COUNT(*) FILTER (WHERE processing_status = 'failed') AS failed,
    SUM(records_processed) AS total_records_processed,
    SUM(records_failed) AS total_records_failed,
    MIN(received_at) AS first_attachment,
    MAX(received_at) AS last_attachment
FROM scout.email_attachments ea
GROUP BY ea.sender_email, ea.sender_name;

-- 9) Grant permissions
GRANT SELECT ON scout.email_attachments TO authenticated;
GRANT SELECT ON scout.v_email_attachment_pipeline TO authenticated;
GRANT EXECUTE ON FUNCTION scout.process_pending_email_attachments() TO authenticated;

COMMIT;

-- Show current status
SELECT * FROM scout.v_email_attachment_pipeline;
SELECT * FROM scout.email_attachments ORDER BY received_at DESC;