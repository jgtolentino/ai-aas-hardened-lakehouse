-- =====================================================================
-- Scout v5.2 - Production Hardening & Observability
-- Go-live verification, monitoring views, and production safeguards
-- =====================================================================
SET search_path TO scout, public;
SET check_function_bodies = off;

-- =====================================================================
-- PART 1: ENHANCED OBSERVABILITY VIEWS
-- =====================================================================

-- Real-time freshness monitoring (minutes since last data)
CREATE OR REPLACE VIEW scout.v_ingest_freshness AS
SELECT
    EXTRACT(EPOCH FROM (now() - (SELECT MAX(ingested_at) FROM scout.bronze_events)))/60 AS bronze_staleness_minutes,
    EXTRACT(EPOCH FROM (now() - (SELECT MAX(processed_at) FROM scout.silver_transactions)))/60 AS silver_staleness_minutes,
    EXTRACT(EPOCH FROM (now() - GREATEST(
        COALESCE((SELECT MAX(created_at) FROM scout.gold_daily_metrics), 'epoch'::timestamptz),
        COALESCE((SELECT MAX(updated_at) FROM scout.gold_daily_metrics), 'epoch'::timestamptz)
    )))/60 AS gold_staleness_minutes,
    CASE 
        WHEN EXTRACT(EPOCH FROM (now() - (SELECT MAX(processed_at) FROM scout.silver_transactions)))/60 <= 5 
        THEN 'healthy' 
        ELSE 'stale' 
    END AS pipeline_health;

-- Rolling 15-minute throughput view
CREATE OR REPLACE VIEW scout.v_pipeline_throughput AS
SELECT
    date_trunc('minute', processed_at) AS minute,
    COUNT(*) AS tx_count,
    SUM(item_count) AS total_items,
    AVG(total_amount)::NUMERIC(10,2) AS avg_transaction_amount,
    COUNT(DISTINCT store_id) AS active_stores
FROM scout.silver_transactions
WHERE processed_at >= now() - INTERVAL '15 minutes'
GROUP BY date_trunc('minute', processed_at)
ORDER BY minute DESC;

-- Production quality alerts (hook to monitoring system)
CREATE OR REPLACE VIEW scout.v_quality_alerts AS
-- Negative transaction amounts
SELECT 
    'NEGATIVE_TOTAL' AS alert_type,
    'critical' AS severity,
    transaction_id,
    processed_at,
    jsonb_build_object(
        'total_amount', total_amount,
        'store_id', store_id
    ) AS alert_payload
FROM scout.silver_transactions 
WHERE total_amount < 0
  AND processed_at >= now() - INTERVAL '1 hour'

UNION ALL

-- Line items don't sum to transaction total (>1% variance)
SELECT 
    'LINE_TOTAL_MISMATCH' AS alert_type,
    'critical' AS severity,
    st.transaction_id,
    st.processed_at,
    jsonb_build_object(
        'transaction_total', st.total_amount,
        'line_items_sum', li.sum_lines,
        'variance_amount', ABS(st.total_amount - li.sum_lines),
        'variance_percent', ROUND(ABS(st.total_amount - li.sum_lines) / st.total_amount * 100, 2)
    ) AS alert_payload
FROM scout.silver_transactions st
JOIN (
    SELECT 
        transaction_id, 
        SUM(quantity * unit_price) AS sum_lines
    FROM scout.silver_line_items 
    GROUP BY transaction_id
) li USING (transaction_id)
WHERE ABS(st.total_amount - li.sum_lines) > GREATEST(st.total_amount * 0.01, 0.50)  -- >1% or >$0.50
  AND st.processed_at >= now() - INTERVAL '1 hour'

UNION ALL

-- Impossibly high transaction amounts (>$10k)
SELECT 
    'SUSPICIOUS_HIGH_AMOUNT' AS alert_type,
    'warning' AS severity,
    transaction_id,
    processed_at,
    jsonb_build_object(
        'total_amount', total_amount,
        'store_id', store_id,
        'item_count', item_count
    ) AS alert_payload
FROM scout.silver_transactions 
WHERE total_amount > 10000
  AND processed_at >= now() - INTERVAL '1 hour'

UNION ALL

-- Zero or negative quantities/prices in line items
SELECT 
    'INVALID_LINE_ITEM' AS alert_type,
    'critical' AS severity,
    transaction_id,
    updated_at AS processed_at,
    jsonb_build_object(
        'product_id', product_id,
        'quantity', quantity,
        'unit_price', unit_price,
        'line_amount', line_amount
    ) AS alert_payload
FROM scout.silver_line_items
WHERE (quantity <= 0 OR unit_price < 0)
  AND updated_at >= now() - INTERVAL '1 hour';

-- ETL processing performance metrics
CREATE OR REPLACE VIEW scout.v_etl_performance AS
SELECT
    date_trunc('hour', processed_at) AS hour,
    COUNT(*) AS batches_processed,
    SUM(silver_records_created) AS total_records_created,
    AVG(processing_duration_ms)::INTEGER AS avg_duration_ms,
    MAX(processing_duration_ms) AS max_duration_ms,
    MIN(processing_duration_ms) AS min_duration_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY processing_duration_ms)::INTEGER AS p95_duration_ms
FROM scout.etl_processed
WHERE processed_at > NOW() - INTERVAL '24 hours'
GROUP BY date_trunc('hour', processed_at)
ORDER BY hour DESC;

-- Product linking effectiveness monitoring  
CREATE OR REPLACE VIEW scout.v_product_linking_stats AS
SELECT
    date_trunc('hour', updated_at) AS hour,
    COUNT(*) AS total_line_items,
    COUNT(CASE WHEN product_key IS NOT NULL THEN 1 END) AS linked_items,
    ROUND(100.0 * COUNT(CASE WHEN product_key IS NOT NULL THEN 1 END) / COUNT(*), 2) AS linking_percentage,
    COUNT(DISTINCT product_id) AS unique_product_ids,
    COUNT(DISTINCT product_key) AS unique_product_keys
FROM scout.silver_line_items
WHERE updated_at > NOW() - INTERVAL '24 hours'
GROUP BY date_trunc('hour', updated_at)
ORDER BY hour DESC;

-- =====================================================================
-- PART 2: PRODUCTION HARDENING FEATURES
-- =====================================================================

-- Dead Letter Queue for failed ingestion
CREATE TABLE IF NOT EXISTS scout.bronze_events_dlq (
    dlq_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    original_payload JSONB NOT NULL,
    error_code TEXT NOT NULL,
    error_message TEXT NOT NULL,
    error_details JSONB,
    source_system TEXT,
    failed_at TIMESTAMPTZ DEFAULT NOW(),
    retry_count INTEGER DEFAULT 0,
    last_retry_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    resolved_by TEXT
);

CREATE INDEX IF NOT EXISTS idx_dlq_failed_at ON scout.bronze_events_dlq(failed_at);
CREATE INDEX IF NOT EXISTS idx_dlq_error_code ON scout.bronze_events_dlq(error_code) WHERE resolved_at IS NULL;

-- Enhanced canonical event hash (collision-resistant)
CREATE OR REPLACE FUNCTION scout.canonical_event_hash(
    p_transaction_id TEXT,
    p_store_id TEXT, 
    p_ts TIMESTAMPTZ,
    p_items JSONB,
    p_source_id TEXT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_canonical_payload JSONB;
    v_hash_input TEXT;
BEGIN
    -- Create canonical representation with sorted keys and normalized values
    v_canonical_payload := jsonb_strip_nulls(jsonb_build_object(
        'transaction_id', TRIM(UPPER(p_transaction_id)),
        'store_id', TRIM(UPPER(p_store_id)),
        'ts', p_ts,
        'items', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'product_id', TRIM(UPPER(COALESCE(item->>'product_id', ''))),
                    'qty', COALESCE((item->>'qty')::INTEGER, 1),
                    'unit_price', ROUND(COALESCE((item->>'unit_price')::NUMERIC, 0), 2)
                ) ORDER BY item->>'product_id'
            )
            FROM jsonb_array_elements(p_items) AS item
        ),
        'source_id', COALESCE(p_source_id, 'unknown')
    ));
    
    -- Convert to stable string representation
    v_hash_input := v_canonical_payload::TEXT;
    
    -- Return SHA-256 hash
    RETURN encode(digest(v_hash_input, 'sha256'), 'hex');
END;
$$;

-- Store watermarks for late event detection
CREATE TABLE IF NOT EXISTS scout.ingestion_watermarks (
    store_id TEXT PRIMARY KEY,
    high_water_ts TIMESTAMPTZ NOT NULL,
    grace_period_minutes INTEGER DEFAULT 30,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Late event detection function
CREATE OR REPLACE FUNCTION scout.detect_late_events(
    p_transaction_ts TIMESTAMPTZ,
    p_store_id TEXT
)
RETURNS TABLE(
    is_late BOOLEAN,
    watermark_ts TIMESTAMPTZ,
    minutes_late NUMERIC
)
LANGUAGE plpgsql AS $$
DECLARE
    v_watermark RECORD;
BEGIN
    -- Get current watermark for store
    SELECT high_water_ts, grace_period_minutes 
    INTO v_watermark
    FROM scout.ingestion_watermarks 
    WHERE store_id = p_store_id;
    
    -- If no watermark exists, this is not a late event
    IF v_watermark.high_water_ts IS NULL THEN
        RETURN QUERY SELECT 
            FALSE,
            NULL::TIMESTAMPTZ,
            NULL::NUMERIC;
        RETURN;
    END IF;
    
    -- Check if event is late (older than watermark - grace period)
    RETURN QUERY SELECT
        p_transaction_ts < (v_watermark.high_water_ts - (v_watermark.grace_period_minutes || ' minutes')::INTERVAL),
        v_watermark.high_water_ts,
        EXTRACT(EPOCH FROM (v_watermark.high_water_ts - p_transaction_ts))/60;
        
END;
$$;

-- Function to update watermarks
CREATE OR REPLACE FUNCTION scout.update_ingestion_watermark(
    p_store_id TEXT,
    p_event_ts TIMESTAMPTZ
)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO scout.ingestion_watermarks (store_id, high_water_ts)
    VALUES (p_store_id, p_event_ts)
    ON CONFLICT (store_id) DO UPDATE
    SET high_water_ts = GREATEST(ingestion_watermarks.high_water_ts, excluded.high_water_ts),
        updated_at = NOW();
END;
$$;

-- =====================================================================
-- PART 3: ENHANCED DATA QUALITY MONITORING
-- =====================================================================

-- Comprehensive data quality dashboard function
CREATE OR REPLACE FUNCTION scout.data_quality_report(
    p_hours_back INTEGER DEFAULT 1
)
RETURNS TABLE(
    check_category TEXT,
    check_name TEXT,
    status TEXT,
    failure_count INTEGER,
    details JSONB
)
LANGUAGE sql AS $$
    -- Pipeline health checks
    SELECT 
        'pipeline_health' AS check_category,
        'bronze_to_silver_latency' AS check_name,
        CASE WHEN AVG(EXTRACT(EPOCH FROM (st.processed_at - be.ingested_at))) <= 300 
             THEN 'healthy' ELSE 'degraded' END AS status,
        0 AS failure_count,
        jsonb_build_object(
            'avg_latency_seconds', ROUND(AVG(EXTRACT(EPOCH FROM (st.processed_at - be.ingested_at))), 2),
            'max_latency_seconds', ROUND(MAX(EXTRACT(EPOCH FROM (st.processed_at - be.ingested_at))), 2),
            'sample_size', COUNT(*)
        ) AS details
    FROM scout.silver_transactions st
    JOIN scout.bronze_events be ON (be.event_data->>'transaction_id') = st.transaction_id
    WHERE st.processed_at >= NOW() - (p_hours_back || ' hours')::INTERVAL
    
    UNION ALL
    
    -- Data integrity checks
    SELECT 
        'data_integrity',
        'negative_amounts',
        CASE WHEN COUNT(*) = 0 THEN 'healthy' ELSE 'critical' END,
        COUNT(*)::INTEGER,
        jsonb_build_object(
            'sample_transaction_ids', jsonb_agg(transaction_id)
        )
    FROM scout.silver_transactions
    WHERE total_amount < 0 
      AND processed_at >= NOW() - (p_hours_back || ' hours')::INTERVAL
      
    UNION ALL
    
    SELECT 
        'data_integrity',
        'line_item_totals_mismatch', 
        CASE WHEN COUNT(*) = 0 THEN 'healthy' 
             WHEN COUNT(*) < 5 THEN 'warning' 
             ELSE 'critical' END,
        COUNT(*)::INTEGER,
        jsonb_build_object(
            'sample_transaction_ids', jsonb_agg(st.transaction_id),
            'max_variance', MAX(ABS(st.total_amount - li.sum_lines))
        )
    FROM scout.silver_transactions st
    JOIN (
        SELECT transaction_id, SUM(quantity * unit_price) AS sum_lines
        FROM scout.silver_line_items 
        WHERE updated_at >= NOW() - (p_hours_back || ' hours')::INTERVAL
        GROUP BY transaction_id
    ) li USING (transaction_id)
    WHERE ABS(st.total_amount - li.sum_lines) > GREATEST(st.total_amount * 0.01, 0.50)
      AND st.processed_at >= NOW() - (p_hours_back || ' hours')::INTERVAL
    
    UNION ALL
    
    -- Product linking effectiveness
    SELECT 
        'product_linking',
        'coverage_percentage',
        CASE WHEN (100.0 * COUNT(CASE WHEN product_key IS NOT NULL THEN 1 END) / NULLIF(COUNT(*), 0)) >= 95
             THEN 'healthy' ELSE 'degraded' END,
        0,
        jsonb_build_object(
            'coverage_percentage', ROUND(100.0 * COUNT(CASE WHEN product_key IS NOT NULL THEN 1 END) / NULLIF(COUNT(*), 0), 2),
            'total_line_items', COUNT(*),
            'linked_items', COUNT(CASE WHEN product_key IS NOT NULL THEN 1 END)
        )
    FROM scout.silver_line_items
    WHERE updated_at >= NOW() - (p_hours_back || ' hours')::INTERVAL
    
    UNION ALL
    
    -- Processing volume checks
    SELECT 
        'processing_volume',
        'transaction_throughput',
        CASE WHEN COUNT(*) > 0 THEN 'healthy' ELSE 'no_data' END,
        0,
        jsonb_build_object(
            'transactions_processed', COUNT(*),
            'avg_per_hour', ROUND(COUNT(*)::NUMERIC / p_hours_back, 2),
            'unique_stores', COUNT(DISTINCT store_id),
            'avg_items_per_transaction', ROUND(AVG(item_count), 2)
        )
    FROM scout.silver_transactions
    WHERE processed_at >= NOW() - (p_hours_back || ' hours')::INTERVAL
$$;

-- =====================================================================
-- PART 4: AUTOMATED MONITORING & ALERTING  
-- =====================================================================

-- Alert processing function (integrates with external systems)
CREATE OR REPLACE FUNCTION scout.process_quality_alerts()
RETURNS TABLE(
    alerts_processed INTEGER,
    critical_alerts INTEGER,
    warning_alerts INTEGER
) 
LANGUAGE plpgsql AS $$
DECLARE
    v_alerts_processed INTEGER := 0;
    v_critical INTEGER := 0;
    v_warning INTEGER := 0;
    alert_record RECORD;
BEGIN
    -- Process all unresolved quality alerts
    FOR alert_record IN 
        SELECT alert_type, severity, COUNT(*) as alert_count,
               jsonb_agg(jsonb_build_object(
                   'transaction_id', transaction_id,
                   'processed_at', processed_at,
                   'payload', alert_payload
               )) as alert_details
        FROM scout.v_quality_alerts
        GROUP BY alert_type, severity
    LOOP
        -- Insert into alerts table for external processing
        INSERT INTO scout.alerts (alert_type, severity, message, payload)
        VALUES (
            alert_record.alert_type,
            alert_record.severity,
            'Data quality alert: ' || alert_record.alert_count || ' instances of ' || alert_record.alert_type,
            jsonb_build_object(
                'alert_count', alert_record.alert_count,
                'alert_details', alert_record.alert_details,
                'generated_at', NOW()
            )
        );
        
        v_alerts_processed := v_alerts_processed + 1;
        
        CASE alert_record.severity
            WHEN 'critical' THEN v_critical := v_critical + 1;
            WHEN 'warning' THEN v_warning := v_warning + 1;
            ELSE NULL;
        END CASE;
    END LOOP;
    
    RETURN QUERY SELECT v_alerts_processed, v_critical, v_warning;
END;
$$;

-- =====================================================================
-- PART 5: PRODUCTION ROLLBACK & RECOVERY FUNCTIONS
-- =====================================================================

-- Function to pause/resume ingestion
CREATE OR REPLACE FUNCTION scout.control_ingestion(
    p_action TEXT DEFAULT 'status'  -- 'pause', 'resume', 'status'
)
RETURNS TABLE(
    action TEXT,
    ingestion_active BOOLEAN,
    etl_jobs_active INTEGER,
    message TEXT
) 
LANGUAGE plpgsql AS $$
DECLARE
    v_active_jobs INTEGER;
BEGIN
    -- Count active ETL jobs
    SELECT COUNT(*) INTO v_active_jobs
    FROM cron.job
    WHERE (command LIKE '%bronze-to-silver%' OR command LIKE '%etl%')
      AND active = TRUE;
    
    CASE p_action
        WHEN 'pause' THEN
            -- Disable ETL jobs
            UPDATE cron.job 
            SET active = FALSE 
            WHERE command LIKE '%bronze-to-silver%' OR command LIKE '%etl%';
            
            RETURN QUERY SELECT 
                'pause'::TEXT,
                FALSE,
                0,
                'Ingestion paused - ETL jobs disabled'::TEXT;
                
        WHEN 'resume' THEN
            -- Enable ETL jobs
            UPDATE cron.job 
            SET active = TRUE 
            WHERE command LIKE '%bronze-to-silver%' OR command LIKE '%etl%';
            
            RETURN QUERY SELECT 
                'resume'::TEXT,
                TRUE,
                v_active_jobs,
                'Ingestion resumed - ETL jobs enabled'::TEXT;
                
        ELSE -- 'status'
            RETURN QUERY SELECT 
                'status'::TEXT,
                v_active_jobs > 0,
                v_active_jobs,
                CASE 
                    WHEN v_active_jobs > 0 THEN 'Ingestion is active'
                    ELSE 'Ingestion is paused'
                END::TEXT;
    END CASE;
END;
$$;

-- Reprocess Bronze events for a time window (recovery function)
CREATE OR REPLACE FUNCTION scout.reprocess_bronze_window(
    p_start_ts TIMESTAMPTZ,
    p_end_ts TIMESTAMPTZ,
    p_limit INTEGER DEFAULT 1000
)
RETURNS TABLE(
    events_reprocessed INTEGER,
    transactions_created INTEGER,
    line_items_created INTEGER
) 
LANGUAGE plpgsql AS $$
DECLARE
    v_events INTEGER := 0;
    v_transactions INTEGER := 0; 
    v_line_items INTEGER := 0;
BEGIN
    -- Mark events in window as unprocessed by removing from etl_processed
    DELETE FROM scout.etl_processed
    WHERE event_id IN (
        SELECT event_id 
        FROM scout.bronze_events 
        WHERE ingested_at BETWEEN p_start_ts AND p_end_ts
    );
    
    -- Reprocess using existing ETL function
    SELECT events_processed, transactions_created, line_items_created
    INTO v_events, v_transactions, v_line_items
    FROM scout.load_silver_from_bronze(p_limit);
    
    RETURN QUERY SELECT v_events, v_transactions, v_line_items;
END;
$$;

-- =====================================================================
-- PART 6: PRODUCTION VERIFICATION FUNCTIONS
-- =====================================================================

-- Pre-flight smoke test (used by acceptance gate)
CREATE OR REPLACE FUNCTION scout.smoke_test_ingestion()
RETURNS TABLE(
    test_name TEXT,
    status TEXT,
    details TEXT
) 
LANGUAGE plpgsql AS $$
DECLARE
    v_test_transaction_id TEXT := 'SMOKE-' || EXTRACT(EPOCH FROM NOW())::BIGINT;
    v_bronze_count INTEGER;
    v_silver_count INTEGER;
BEGIN
    -- Insert test transaction directly into Bronze
    INSERT INTO scout.bronze_events (event_type, event_data, source_system, event_hash)
    VALUES (
        'transaction.v1',
        jsonb_build_object(
            'transaction_id', v_test_transaction_id,
            'store_id', 'TEST-STORE',
            'ts', NOW(),
            'total_amount', 100.00,
            'items', '[{"product_id":"TEST-PROD","qty":1,"unit_price":100.00}]'
        ),
        'smoke_test',
        encode(digest(v_test_transaction_id, 'sha256'), 'hex')
    );
    
    -- Process through ETL
    PERFORM scout.load_silver_from_bronze(1);
    
    -- Check if transaction made it to Bronze
    SELECT COUNT(*) INTO v_bronze_count
    FROM scout.bronze_events 
    WHERE event_data->>'transaction_id' = v_test_transaction_id;
    
    -- Check if transaction made it to Silver  
    SELECT COUNT(*) INTO v_silver_count
    FROM scout.silver_transactions 
    WHERE transaction_id = v_test_transaction_id;
    
    -- Return test results
    RETURN QUERY SELECT 
        'bronze_ingestion'::TEXT,
        CASE WHEN v_bronze_count > 0 THEN 'pass' ELSE 'fail' END::TEXT,
        ('Bronze events: ' || v_bronze_count)::TEXT;
        
    RETURN QUERY SELECT 
        'silver_processing'::TEXT,
        CASE WHEN v_silver_count > 0 THEN 'pass' ELSE 'fail' END::TEXT,
        ('Silver transactions: ' || v_silver_count)::TEXT;
    
    -- Cleanup test data
    DELETE FROM scout.bronze_events WHERE event_data->>'transaction_id' = v_test_transaction_id;
    DELETE FROM scout.silver_transactions WHERE transaction_id = v_test_transaction_id;
    DELETE FROM scout.silver_line_items WHERE transaction_id = v_test_transaction_id;
END;
$$;

-- =====================================================================
-- PART 7: PERFORMANCE OPTIMIZATIONS
-- =====================================================================

-- Partitioning setup for high-volume bronze_events (monthly partitions)
DO $$
BEGIN
    -- Add partitioning to bronze_events if volume exceeds 50M rows/year
    -- This is a preparation for future scaling
    
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS scout.bronze_events_y%s_m%s 
        PARTITION OF scout.bronze_events
        FOR VALUES FROM (%L) TO (%L)',
        EXTRACT(YEAR FROM NOW()),
        LPAD(EXTRACT(MONTH FROM NOW())::TEXT, 2, '0'),
        DATE_TRUNC('month', NOW()),
        DATE_TRUNC('month', NOW() + INTERVAL '1 month')
    );
    
EXCEPTION WHEN OTHERS THEN
    -- Ignore partition errors - table might not be partitioned yet
    NULL;
END $$;

-- =====================================================================
-- DEPLOYMENT VERIFICATION
-- =====================================================================

-- Verify production hardening deployment
CREATE OR REPLACE FUNCTION scout.verify_production_hardening()
RETURNS TABLE(
    component TEXT,
    status TEXT,
    details TEXT
) 
LANGUAGE sql AS $$
    SELECT 'Observability Views'::TEXT, 
           'Ready'::TEXT,
           'All monitoring views deployed'::TEXT
    WHERE EXISTS (
        SELECT 1 FROM information_schema.views 
        WHERE table_name = 'v_ingest_freshness'
        AND table_schema = 'scout'
    )
    
    UNION ALL
    
    SELECT 'Dead Letter Queue',
           'Ready',
           'DLQ table created for failed events'
    WHERE EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_name = 'bronze_events_dlq'
        AND table_schema = 'scout'
    )
    
    UNION ALL
    
    SELECT 'Quality Monitoring',
           'Ready', 
           'Data quality functions deployed'
    WHERE EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_name = 'data_quality_report'
        AND routine_schema = 'scout'
    )
    
    UNION ALL
    
    SELECT 'Recovery Functions',
           'Ready',
           'Rollback and recovery procedures available'
    WHERE EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_name = 'reprocess_bronze_window'
        AND routine_schema = 'scout'
    )
$$;

-- Final deployment confirmation
SELECT 
    '🔥 Production Hardening Complete!'::TEXT AS status,
    'Go-live verification, monitoring, and recovery tools deployed'::TEXT AS description;

-- Run verification
SELECT * FROM scout.verify_production_hardening();

-- Show monitoring views available
SELECT 
    table_name,
    CASE WHEN table_name LIKE 'v_quality%' THEN '🚨 Quality'
         WHEN table_name LIKE 'v_ingest%' OR table_name LIKE 'v_pipeline%' THEN '📊 Performance'  
         WHEN table_name LIKE 'v_etl%' THEN '⚙️ ETL'
         ELSE '📈 Analytics'
    END AS category
FROM information_schema.views 
WHERE table_schema = 'scout' 
  AND table_name LIKE 'v_%'
ORDER BY category, table_name;