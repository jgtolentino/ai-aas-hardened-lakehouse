-- =====================================================================
-- Scout v5.2 - Streaming Ingestion & Data Quality Pipeline
-- Production-ready streaming from Bronze → Silver → Gold with guardrails
-- =====================================================================
SET search_path TO scout, public;
SET check_function_bodies = off;

-- =====================================================================
-- PART 1: CONTINUOUS INGESTION (Bronze → Silver)
-- =====================================================================

-- Bronze events deduplication constraint
ALTER TABLE scout.bronze_events 
  ADD CONSTRAINT unique_event_hash UNIQUE (event_hash);

-- ETL processing tracking table
CREATE TABLE IF NOT EXISTS scout.etl_processed (
    event_id UUID PRIMARY KEY,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processing_duration_ms INTEGER,
    silver_records_created INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_etl_processed_at ON scout.etl_processed(processed_at);

-- Idempotent Bronze → Silver transformer
CREATE OR REPLACE FUNCTION scout.load_silver_from_bronze(p_limit INTEGER DEFAULT 2000)
RETURNS TABLE(
    events_processed INTEGER,
    transactions_created INTEGER,
    line_items_created INTEGER,
    processing_duration_ms INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE 
    v_start_time TIMESTAMPTZ := clock_timestamp();
    v_events_processed INTEGER := 0;
    v_transactions_created INTEGER := 0;
    v_line_items_created INTEGER := 0;
    v_duration_ms INTEGER;
BEGIN
    -- Process batch with row-level locking to prevent conflicts
    WITH next_events AS (
        SELECT event_id, event_data, ingested_at
        FROM scout.bronze_events
        WHERE event_type = 'transaction.v1'
          AND NOT EXISTS (
            SELECT 1 FROM scout.etl_processed e 
            WHERE e.event_id = bronze_events.event_id
          )
        ORDER BY ingested_at ASC
        LIMIT p_limit
        FOR UPDATE SKIP LOCKED
    ),
    
    -- Insert transactions with conflict resolution
    upsert_transactions AS (
        INSERT INTO scout.silver_transactions (
            transaction_id, 
            store_id, 
            ts, 
            date_key, 
            total_amount, 
            net_amount,
            customer_id, 
            payment_method, 
            item_count, 
            unique_products, 
            basket_size,
            processed_at,
            source_event_id
        )
        SELECT
            (e.event_data->>'transaction_id')::TEXT,
            (e.event_data->>'store_id')::TEXT,
            COALESCE((e.event_data->>'ts')::TIMESTAMPTZ, e.ingested_at),
            COALESCE((e.event_data->>'ts')::DATE, e.ingested_at::DATE),
            COALESCE((e.event_data->>'total_amount')::NUMERIC, 0),
            COALESCE((e.event_data->>'net_amount')::NUMERIC, (e.event_data->>'total_amount')::NUMERIC),
            (e.event_data->>'customer_id')::TEXT,
            COALESCE((e.event_data->>'payment_method')::TEXT, 'unknown'),
            COALESCE(jsonb_array_length(e.event_data->'items'), 0),
            (
                SELECT COUNT(DISTINCT (item->>'product_id')) 
                FROM jsonb_array_elements(e.event_data->'items') AS item
            ),
            COALESCE(jsonb_array_length(e.event_data->'items'), 0),
            NOW(),
            e.event_id
        FROM next_events e
        WHERE e.event_data ? 'transaction_id'
        ON CONFLICT (transaction_id) DO UPDATE SET
            updated_at = NOW(),
            net_amount = COALESCE(excluded.net_amount, silver_transactions.net_amount),
            item_count = excluded.item_count,
            unique_products = excluded.unique_products
        RETURNING transaction_id
    ),
    
    -- Count transactions created/updated
    transaction_stats AS (
        SELECT COUNT(*) AS tx_count FROM upsert_transactions
    ),
    
    -- Insert line items with deduplication
    upsert_line_items AS (
        INSERT INTO scout.silver_line_items (
            transaction_id,
            product_id,
            product_name,
            brand_name,
            category,
            quantity,
            unit_price,
            line_amount,
            discount_amount,
            line_sequence
        )
        SELECT DISTINCT
            (e.event_data->>'transaction_id')::TEXT,
            (item->>'product_id')::TEXT,
            COALESCE((item->>'product_name')::TEXT, 'Unknown Product'),
            COALESCE((item->>'brand')::TEXT, 'Unknown Brand'),
            COALESCE((item->>'category')::TEXT, 'Uncategorized'),
            GREATEST(COALESCE((item->>'qty')::INTEGER, 1), 1),
            GREATEST(COALESCE((item->>'unit_price')::NUMERIC, 0), 0),
            GREATEST(COALESCE((item->>'line_amount')::NUMERIC, 0), 0),
            COALESCE((item->>'discount')::NUMERIC, 0),
            row_number() OVER (PARTITION BY (e.event_data->>'transaction_id') ORDER BY ordinality)
        FROM next_events e,
             jsonb_array_elements(e.event_data->'items') WITH ORDINALITY AS item
        WHERE e.event_data ? 'transaction_id'
        ON CONFLICT (transaction_id, product_id, line_sequence) DO UPDATE SET
            updated_at = NOW(),
            quantity = excluded.quantity,
            unit_price = excluded.unit_price,
            line_amount = excluded.line_amount
        RETURNING 1
    ),
    
    -- Count line items created/updated
    line_item_stats AS (
        SELECT COUNT(*) AS li_count FROM upsert_line_items
    ),
    
    -- Mark events as processed
    mark_processed AS (
        INSERT INTO scout.etl_processed (event_id, processed_at, silver_records_created)
        SELECT 
            e.event_id, 
            NOW(),
            (SELECT tx_count FROM transaction_stats) + (SELECT li_count FROM line_item_stats)
        FROM next_events e
        RETURNING event_id
    )
    
    -- Collect final statistics
    SELECT 
        (SELECT COUNT(*) FROM mark_processed),
        (SELECT COALESCE(tx_count, 0) FROM transaction_stats),
        (SELECT COALESCE(li_count, 0) FROM line_item_stats)
    INTO v_events_processed, v_transactions_created, v_line_items_created;
    
    -- Calculate processing duration
    v_duration_ms := EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000;
    
    -- Update processing stats in etl_processed
    UPDATE scout.etl_processed 
    SET processing_duration_ms = v_duration_ms
    WHERE processed_at >= v_start_time;
    
    -- Return results
    RETURN QUERY SELECT 
        v_events_processed,
        v_transactions_created, 
        v_line_items_created,
        v_duration_ms;
        
END;
$$;

-- =====================================================================
-- PART 2: LINE-ITEM FIDELITY & INTEGRITY
-- =====================================================================

-- Add foreign key constraints for data integrity
DO $$
BEGIN
    -- Foreign key from line items to transactions
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'silver_line_items' 
        AND constraint_name = 'fk_item_transaction'
        AND table_schema = 'scout'
    ) THEN
        ALTER TABLE scout.silver_line_items
        ADD CONSTRAINT fk_item_transaction 
        FOREIGN KEY (transaction_id) 
        REFERENCES scout.silver_transactions(transaction_id) 
        ON DELETE CASCADE;
    END IF;
END $$;

-- Add product linking column for soft FK to dim_products
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'scout' 
        AND table_name = 'silver_line_items' 
        AND column_name = 'product_key'
    ) THEN
        ALTER TABLE scout.silver_line_items 
        ADD COLUMN product_key TEXT;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'scout' 
        AND table_name = 'silver_line_items' 
        AND column_name = 'line_sequence'
    ) THEN
        ALTER TABLE scout.silver_line_items 
        ADD COLUMN line_sequence INTEGER DEFAULT 1;
    END IF;
END $$;

-- Create function to link products with confidence scoring
CREATE OR REPLACE FUNCTION scout.link_products_to_catalog(p_limit INTEGER DEFAULT 1000)
RETURNS TABLE(
    items_processed INTEGER,
    exact_matches INTEGER,
    fuzzy_matches INTEGER,
    unmatched INTEGER
) 
LANGUAGE plpgsql AS $$
DECLARE
    v_items_processed INTEGER := 0;
    v_exact_matches INTEGER := 0;
    v_fuzzy_matches INTEGER := 0;
    v_unmatched INTEGER := 0;
BEGIN
    -- Exact product ID matches
    WITH exact_updates AS (
        UPDATE scout.silver_line_items i
        SET product_key = p.product_id
        FROM scout.dim_product p
        WHERE i.product_id = p.product_id
          AND i.product_key IS NULL
          AND i.updated_at > NOW() - INTERVAL '1 hour'
        RETURNING i.transaction_id
    )
    SELECT COUNT(*) INTO v_exact_matches FROM exact_updates;
    
    -- Fuzzy product name matches (high confidence)
    WITH fuzzy_updates AS (
        UPDATE scout.silver_line_items i
        SET product_key = p.product_id
        FROM scout.dim_product p
        WHERE i.product_key IS NULL
          AND i.updated_at > NOW() - INTERVAL '1 hour'
          AND similarity(lower(i.product_name), lower(p.product_name)) >= 0.8
        RETURNING i.transaction_id
    )
    SELECT COUNT(*) INTO v_fuzzy_matches FROM fuzzy_updates;
    
    -- Count unmatched items
    SELECT COUNT(*) INTO v_unmatched
    FROM scout.silver_line_items
    WHERE product_key IS NULL
      AND updated_at > NOW() - INTERVAL '1 hour';
      
    v_items_processed := v_exact_matches + v_fuzzy_matches + v_unmatched;
    
    RETURN QUERY SELECT 
        v_items_processed,
        v_exact_matches, 
        v_fuzzy_matches,
        v_unmatched;
END;
$$;

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_line_items_transaction ON scout.silver_line_items(transaction_id);
CREATE INDEX IF NOT EXISTS idx_line_items_product ON scout.silver_line_items(product_id);
CREATE INDEX IF NOT EXISTS idx_line_items_product_key ON scout.silver_line_items(product_key) WHERE product_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_line_items_updated ON scout.silver_line_items(updated_at);
CREATE INDEX IF NOT EXISTS idx_silver_transactions_processed ON scout.silver_transactions(processed_at);

-- Unique constraint for line items to prevent duplicates
CREATE UNIQUE INDEX IF NOT EXISTS unique_line_item_per_transaction 
ON scout.silver_line_items(transaction_id, product_id, line_sequence);

-- =====================================================================
-- PART 3: AUTOMATED GOLD/PLATINUM REFRESH
-- =====================================================================

-- Advisory-locked refresh function
CREATE OR REPLACE FUNCTION scout.refresh_gold_platinum()
RETURNS TABLE(
    operation TEXT,
    duration_ms INTEGER,
    status TEXT
) 
LANGUAGE plpgsql AS $$
DECLARE
    got_lock BOOLEAN;
    v_start_time TIMESTAMPTZ;
    v_duration_ms INTEGER;
BEGIN
    -- Try to acquire advisory lock (non-blocking)
    got_lock := pg_try_advisory_lock(94752052);
    
    IF NOT got_lock THEN
        RETURN QUERY SELECT 
            'refresh_gold_platinum'::TEXT,
            0,
            'SKIPPED - refresh already in progress'::TEXT;
        RETURN;
    END IF;

    BEGIN
        -- Refresh Gold layer materialized views in dependency order
        v_start_time := clock_timestamp();
        
        -- Core daily metrics (foundation for other views)
        REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_daily_metrics;
        v_duration_ms := EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000;
        RETURN QUERY SELECT 'gold_daily_metrics'::TEXT, v_duration_ms, 'SUCCESS'::TEXT;
        
        -- Regional choropleth data
        v_start_time := clock_timestamp();
        REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_region_choropleth;
        v_duration_ms := EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000;
        RETURN QUERY SELECT 'gold_region_choropleth'::TEXT, v_duration_ms, 'SUCCESS'::TEXT;
        
        -- Add other gold views here as they're created
        -- REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_brand_competitive_30d;
        -- REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_product_performance;
        
        -- Platinum feature stores (if implemented)
        -- REFRESH MATERIALIZED VIEW CONCURRENTLY scout.platinum_forecasts_14d;
        -- REFRESH MATERIALIZED VIEW CONCURRENTLY scout.platinum_customer_segments;
        
    EXCEPTION WHEN OTHERS THEN
        -- Release lock on error
        PERFORM pg_advisory_unlock(94752052);
        RETURN QUERY SELECT 
            'refresh_gold_platinum'::TEXT,
            0,
            ('ERROR: ' || SQLERRM)::TEXT;
        RETURN;
    END;
    
    -- Release the advisory lock
    PERFORM pg_advisory_unlock(94752052);
    
END;
$$;

-- Smart refresh: only when new data is available
CREATE OR REPLACE FUNCTION scout.maybe_refresh_gold()
RETURNS TABLE(
    should_refresh BOOLEAN,
    new_silver_records INTEGER,
    last_refresh TIMESTAMPTZ
) 
LANGUAGE plpgsql AS $$
DECLARE
    v_new_records INTEGER;
    v_should_refresh BOOLEAN := FALSE;
BEGIN
    -- Check for new silver data in the last 5 minutes
    SELECT COUNT(*) INTO v_new_records
    FROM scout.silver_transactions
    WHERE processed_at > NOW() - INTERVAL '5 minutes';
    
    -- Refresh if we have new data
    IF v_new_records > 0 THEN
        v_should_refresh := TRUE;
        PERFORM scout.refresh_gold_platinum();
    END IF;
    
    RETURN QUERY SELECT 
        v_should_refresh,
        v_new_records,
        NOW();
END;
$$;

-- =====================================================================
-- PART 4: MATH GUARDRAILS AT INGESTION
-- =====================================================================

-- Data quality checks for silver layer
CREATE OR REPLACE FUNCTION scout.silver_sanity_checks()
RETURNS TABLE(
    check_name TEXT,
    failures INTEGER,
    severity TEXT,
    details JSONB
) 
LANGUAGE sql AS $$
    -- Non-negative line amounts
    SELECT 
        'non_negative_line_amounts'::TEXT,
        COUNT(*)::INTEGER,
        CASE WHEN COUNT(*) = 0 THEN 'ok' ELSE 'critical' END::TEXT,
        jsonb_build_object(
            'sample_transaction_ids', 
            jsonb_agg(DISTINCT transaction_id)
        )
    FROM scout.silver_line_items 
    WHERE line_amount < 0 
      AND updated_at > NOW() - INTERVAL '1 hour'
    
    UNION ALL
    
    -- Non-negative transaction totals
    SELECT 
        'non_negative_transaction_totals'::TEXT,
        COUNT(*)::INTEGER,
        CASE WHEN COUNT(*) = 0 THEN 'ok' ELSE 'critical' END::TEXT,
        jsonb_build_object(
            'sample_transaction_ids', 
            jsonb_agg(DISTINCT transaction_id)
        )
    FROM scout.silver_transactions 
    WHERE total_amount < 0
      AND processed_at > NOW() - INTERVAL '1 hour'
    
    UNION ALL
    
    -- Reasonable transaction amounts (not > $10k)
    SELECT 
        'reasonable_transaction_amounts'::TEXT,
        COUNT(*)::INTEGER,
        CASE WHEN COUNT(*) = 0 THEN 'ok' WHEN COUNT(*) < 10 THEN 'warning' ELSE 'critical' END::TEXT,
        jsonb_build_object(
            'max_amount', MAX(total_amount),
            'sample_transaction_ids', jsonb_agg(DISTINCT transaction_id)
        )
    FROM scout.silver_transactions 
    WHERE total_amount > 10000
      AND processed_at > NOW() - INTERVAL '1 hour'
    
    UNION ALL
    
    -- Line items sum matches transaction total (within 1% tolerance)
    SELECT 
        'line_items_sum_matches_total'::TEXT,
        COUNT(*)::INTEGER,
        CASE WHEN COUNT(*) = 0 THEN 'ok' WHEN COUNT(*) < 5 THEN 'warning' ELSE 'critical' END::TEXT,
        jsonb_build_object(
            'sample_transaction_ids', jsonb_agg(DISTINCT t.transaction_id)
        )
    FROM scout.silver_transactions t
    JOIN (
        SELECT 
            transaction_id,
            SUM(line_amount) as items_total
        FROM scout.silver_line_items
        GROUP BY transaction_id
    ) items ON items.transaction_id = t.transaction_id
    WHERE ABS(t.total_amount - items.items_total) > (t.total_amount * 0.01)
      AND t.processed_at > NOW() - INTERVAL '1 hour'
$$;

-- Alerts table for critical issues
CREATE TABLE IF NOT EXISTS scout.alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_type TEXT NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'critical')),
    message TEXT,
    payload JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolved_by TEXT
);

CREATE INDEX IF NOT EXISTS idx_alerts_created_at ON scout.alerts(created_at);
CREATE INDEX IF NOT EXISTS idx_alerts_severity ON scout.alerts(severity) WHERE resolved_at IS NULL;

-- =====================================================================
-- PART 5: OBSERVABILITY & MONITORING
-- =====================================================================

-- Pipeline throughput monitoring
CREATE OR REPLACE VIEW scout.v_pipeline_throughput AS
SELECT
    date_trunc('minute', ingested_at) AS minute,
    COUNT(*) AS events_ingested,
    COUNT(DISTINCT event_data->>'store_id') AS unique_stores,
    AVG(jsonb_array_length(event_data->'items'))::NUMERIC(10,2) AS avg_items_per_transaction
FROM scout.bronze_events
WHERE ingested_at > NOW() - INTERVAL '24 hours'
  AND event_type = 'transaction.v1'
GROUP BY date_trunc('minute', ingested_at)
ORDER BY minute DESC;

-- Bronze to Silver processing latency
CREATE OR REPLACE VIEW scout.v_ingest_latency AS
SELECT
    t.transaction_id,
    b.ingested_at AS bronze_ingested_at,
    t.processed_at AS silver_processed_at,
    EXTRACT(EPOCH FROM (t.processed_at - b.ingested_at))::INTEGER AS latency_seconds,
    CASE 
        WHEN EXTRACT(EPOCH FROM (t.processed_at - b.ingested_at)) <= 60 THEN 'excellent'
        WHEN EXTRACT(EPOCH FROM (t.processed_at - b.ingested_at)) <= 300 THEN 'good'
        WHEN EXTRACT(EPOCH FROM (t.processed_at - b.ingested_at)) <= 900 THEN 'acceptable'
        ELSE 'poor'
    END AS latency_rating
FROM scout.silver_transactions t
JOIN scout.bronze_events b ON (b.event_data->>'transaction_id') = t.transaction_id
WHERE t.processed_at > NOW() - INTERVAL '24 hours'
ORDER BY t.processed_at DESC;

-- Gold layer freshness monitoring
CREATE OR REPLACE VIEW scout.v_gold_freshness AS
SELECT
    'gold_daily_metrics'::TEXT AS materialized_view,
    (
        SELECT MAX(processed_at) 
        FROM scout.silver_transactions
    ) AS latest_silver_data,
    NOW() AS current_time,
    EXTRACT(EPOCH FROM (NOW() - (
        SELECT MAX(processed_at) 
        FROM scout.silver_transactions
    )))::INTEGER AS seconds_behind
-- Add more gold views here as they're implemented
;

-- ETL performance metrics
CREATE OR REPLACE VIEW scout.v_etl_performance AS
SELECT
    date_trunc('hour', processed_at) AS hour,
    COUNT(*) AS batches_processed,
    SUM(silver_records_created) AS total_records_created,
    AVG(processing_duration_ms)::INTEGER AS avg_duration_ms,
    MAX(processing_duration_ms) AS max_duration_ms,
    MIN(processing_duration_ms) AS min_duration_ms
FROM scout.etl_processed
WHERE processed_at > NOW() - INTERVAL '24 hours'
GROUP BY date_trunc('hour', processed_at)
ORDER BY hour DESC;

-- =====================================================================
-- PART 6: SCHEDULED JOBS (pg_cron)
-- =====================================================================

-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Bronze to Silver processing every minute
SELECT cron.schedule(
    'bronze-to-silver-etl',
    '* * * * *',
    'SELECT scout.load_silver_from_bronze(2000);'
);

-- Product linking every 5 minutes
SELECT cron.schedule(
    'product-linking',
    '*/5 * * * *', 
    'SELECT scout.link_products_to_catalog(1000);'
);

-- Smart gold refresh every 5 minutes (only when new data)
SELECT cron.schedule(
    'smart-gold-refresh',
    '*/5 * * * *',
    'SELECT scout.maybe_refresh_gold();'
);

-- Data quality monitoring every 10 minutes
SELECT cron.schedule(
    'data-quality-alerts',
    '*/10 * * * *',
    $$
    DO $$
    DECLARE 
        critical_count INTEGER;
    BEGIN
        SELECT COUNT(*) INTO critical_count
        FROM scout.silver_sanity_checks()
        WHERE severity = 'critical' AND failures > 0;
        
        IF critical_count > 0 THEN
            INSERT INTO scout.alerts(alert_type, severity, message, payload)
            SELECT 
                'data_quality_failure',
                'critical',
                'Critical data quality issues detected: ' || STRING_AGG(check_name, ', '),
                jsonb_build_object(
                    'failed_checks', jsonb_agg(jsonb_build_object(
                        'check', check_name,
                        'failures', failures,
                        'details', details
                    )),
                    'timestamp', NOW()
                )
            FROM scout.silver_sanity_checks()
            WHERE severity = 'critical' AND failures > 0;
        END IF;
    END $$;
    $$
);

-- =====================================================================
-- PART 7: SECURITY & PERMISSIONS
-- =====================================================================

-- Create edge_ingest role for API ingestion
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'edge_ingest') THEN
        CREATE ROLE edge_ingest NOLOGIN;
    END IF;
END $$;

-- Grant minimal permissions to edge_ingest role
GRANT INSERT ON scout.bronze_events TO edge_ingest;
GRANT SELECT ON scout.bronze_events TO edge_ingest;
GRANT USAGE ON SCHEMA scout TO edge_ingest;

-- Dashboard role for read-only analytics
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dashboard_reader') THEN
        CREATE ROLE dashboard_reader NOLOGIN;
    END IF;
END $$;

GRANT SELECT ON ALL TABLES IN SCHEMA scout TO dashboard_reader;
GRANT SELECT ON ALL VIEWS IN SCHEMA scout TO dashboard_reader;
GRANT USAGE ON SCHEMA scout TO dashboard_reader;

-- =====================================================================
-- DEPLOYMENT VERIFICATION
-- =====================================================================

-- Verify streaming ingestion deployment
CREATE OR REPLACE FUNCTION scout.verify_streaming_deployment()
RETURNS TABLE(
    component TEXT,
    status TEXT,
    details TEXT
) 
LANGUAGE sql AS $$
    SELECT 'Bronze Events Table'::TEXT, 
           'Ready'::TEXT,
           'Deduplication constraint active'::TEXT
    WHERE EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'bronze_events' 
        AND constraint_name = 'unique_event_hash'
    )
    
    UNION ALL
    
    SELECT 'ETL Processing Function',
           'Ready',
           'Bronze to Silver transformer deployed'
    WHERE EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_name = 'load_silver_from_bronze'
        AND routine_schema = 'scout'
    )
    
    UNION ALL
    
    SELECT 'Data Quality Checks',
           'Ready', 
           'Sanity check functions deployed'
    WHERE EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_name = 'silver_sanity_checks'
        AND routine_schema = 'scout'
    )
    
    UNION ALL
    
    SELECT 'Scheduled Jobs',
           CASE WHEN COUNT(*) >= 4 THEN 'Ready' ELSE 'Partial' END,
           COUNT(*)::TEXT || ' cron jobs scheduled'
    FROM cron.job
    WHERE jobname LIKE '%-etl' OR jobname LIKE '%-refresh' OR jobname LIKE '%-alerts'
    
    UNION ALL
    
    SELECT 'Observability Views',
           'Ready',
           'Pipeline monitoring views available'
    WHERE EXISTS (
        SELECT 1 FROM information_schema.views 
        WHERE table_name = 'v_pipeline_throughput'
        AND table_schema = 'scout'
    )
$$;

-- Final deployment confirmation
SELECT 
    '🚀 Scout v5.2 Streaming Ingestion Deployed!'::TEXT AS status,
    'Bronze → Silver → Gold pipeline active with data quality guardrails'::TEXT AS description;

-- Run verification
SELECT * FROM scout.verify_streaming_deployment();

-- Show cron job status
SELECT jobname, schedule, active FROM cron.job 
WHERE jobname IN ('bronze-to-silver-etl', 'smart-gold-refresh', 'data-quality-alerts', 'product-linking');