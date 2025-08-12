-- ============================================================================
-- Automatic ETL Pipeline for Edge-Inbox ZIP Files
-- No manual processing - fully automated with Storage Webhook
-- ============================================================================

BEGIN;

-- 2.1 Watermark to prevent reprocessing the same object
CREATE TABLE IF NOT EXISTS scout.etl_watermarks (
  obj_id TEXT PRIMARY KEY,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ok BOOLEAN NOT NULL DEFAULT false,
  msg TEXT
);

-- 2.2 Bronze table (if not present)
CREATE TABLE IF NOT EXISTS scout.bronze_edge_raw (
  source_file TEXT NOT NULL,
  entry_name TEXT NOT NULL,
  txn_id TEXT,
  payload JSONB NOT NULL,
  ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (source_file, entry_name)
);

ALTER TABLE scout.bronze_edge_raw ENABLE ROW LEVEL SECURITY;

-- Service role bypasses RLS; keep anon blocked:
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename='bronze_edge_raw' 
    AND schemaname='scout'
    AND policyname='read_none'
  ) THEN
    CREATE POLICY read_none ON scout.bronze_edge_raw FOR SELECT USING (false);
  END IF;
END $$;

-- 2.3 Promote Bronze -> Silver (replace with your real mapping)
CREATE OR REPLACE FUNCTION scout.transform_edge_bronze_to_silver()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = scout, public
AS $$
BEGIN
  -- Example: upsert into silver_transactions from bronze payload
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
    store_type,
    economic_class,
    units_per_transaction,
    peso_value,
    basket_size,
    duration_seconds,
    time_of_day,
    is_tbwa_client,
    suggestion_accepted,
    payment_method,
    customer_type,
    campaign_influenced,
    handshake_score,
    request_mode,
    request_type,
    gender,
    age_bracket
  )
  SELECT
    COALESCE(b.txn_id, (b.payload->>'transaction_id'), (b.payload->>'id'), gen_random_uuid()::text),
    COALESCE(
      (b.payload->>'timestamp')::timestamptz,
      (b.payload->>'ts')::timestamptz,
      b.ingested_at
    ),
    COALESCE(b.payload->>'store_id', b.payload->>'device_id', 'unknown'),
    COALESCE(b.payload->>'device_id', b.payload->>'store_id', 'unknown'),
    COALESCE(b.payload->>'region', 'NCR'),
    COALESCE(b.payload->>'province', 'Metro Manila'),
    COALESCE(b.payload->>'city', 'Makati'),
    COALESCE(b.payload->>'barangay', 'Poblacion'),
    COALESCE(b.payload->>'product_category', b.payload->>'category', 'general'),
    COALESCE(b.payload->>'brand_name', b.payload->>'brand', 'generic'),
    COALESCE(b.payload->>'sku', b.payload->>'product_code', 'SKU001'),
    COALESCE(b.payload->>'store_type', 'convenience'),
    COALESCE(b.payload->>'economic_class', 'C'),
    COALESCE((b.payload->>'quantity')::integer, (b.payload->>'units')::integer, 1),
    COALESCE((b.payload->>'amount')::decimal, (b.payload->>'peso_value')::decimal, (b.payload->>'total')::decimal, 0),
    COALESCE((b.payload->>'basket_size')::integer, (b.payload->'items')::jsonb ? 'length', 1),
    COALESCE((b.payload->>'duration_seconds')::integer, 60),
    CASE 
      WHEN EXTRACT(hour FROM COALESCE((b.payload->>'timestamp')::timestamptz, b.ingested_at)) BETWEEN 4 AND 6 THEN 'dawn'
      WHEN EXTRACT(hour FROM COALESCE((b.payload->>'timestamp')::timestamptz, b.ingested_at)) BETWEEN 6 AND 12 THEN 'morning'
      WHEN EXTRACT(hour FROM COALESCE((b.payload->>'timestamp')::timestamptz, b.ingested_at)) BETWEEN 12 AND 18 THEN 'afternoon'
      WHEN EXTRACT(hour FROM COALESCE((b.payload->>'timestamp')::timestamptz, b.ingested_at)) BETWEEN 18 AND 21 THEN 'evening'
      ELSE 'night'
    END,
    COALESCE((b.payload->>'is_tbwa_client')::boolean, false),
    COALESCE((b.payload->>'suggestion_accepted')::boolean, false),
    COALESCE(b.payload->>'payment_method', 'cash'),
    COALESCE(b.payload->>'customer_type', 'regular'),
    COALESCE((b.payload->>'campaign_influenced')::boolean, false),
    COALESCE((b.payload->>'handshake_score')::decimal, 0.5),
    COALESCE(b.payload->>'request_mode', 'standard'),
    COALESCE(b.payload->>'request_type', 'purchase'),
    COALESCE(b.payload->>'gender', 'unknown'),
    COALESCE(b.payload->>'age_bracket', 'unknown')
  FROM scout.bronze_edge_raw b
  LEFT JOIN scout.silver_transactions s ON s.id = COALESCE(b.txn_id, (b.payload->>'transaction_id'), (b.payload->>'id'))
  WHERE s.id IS NULL -- Only insert new records
  ON CONFLICT (id) DO UPDATE SET 
    ts = EXCLUDED.ts,
    updated_at = NOW();

  -- Process line items if present
  INSERT INTO scout.silver_combo_items (
    id,
    position,
    sku,
    quantity,
    price
  )
  SELECT
    COALESCE(b.txn_id, (b.payload->>'transaction_id'), (b.payload->>'id')),
    (item_data->>'position')::integer,
    item_data->>'sku',
    COALESCE((item_data->>'quantity')::decimal, 1),
    COALESCE((item_data->>'price')::decimal, 0)
  FROM scout.bronze_edge_raw b,
       jsonb_array_elements(b.payload->'items') AS item_data
  WHERE b.payload ? 'items'
  ON CONFLICT (id, position) DO NOTHING;

  -- Optionally refresh Gold materialized views
  REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_txn_daily;
  REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_product_mix;
  REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_basket_patterns;
  
  -- Update Platinum features
  REFRESH MATERIALIZED VIEW CONCURRENTLY scout.platinum_features_sales_7d;
END;
$$;

-- Create view to monitor ETL pipeline status
CREATE OR REPLACE VIEW scout.v_etl_pipeline_status AS
SELECT 
  'Watermarks' as layer,
  COUNT(*) as total_records,
  COUNT(*) FILTER (WHERE ok = true) as successful,
  COUNT(*) FILTER (WHERE ok = false) as failed,
  MAX(processed_at) as last_processed
FROM scout.etl_watermarks
UNION ALL
SELECT 
  'Bronze' as layer,
  COUNT(*) as total_records,
  COUNT(DISTINCT source_file) as unique_files,
  COUNT(*) FILTER (WHERE payload ? '_parse_error') as parse_errors,
  MAX(ingested_at) as last_processed
FROM scout.bronze_edge_raw
UNION ALL
SELECT 
  'Silver' as layer,
  COUNT(*) as total_records,
  COUNT(DISTINCT store_id) as unique_stores,
  COUNT(DISTINCT DATE(ts)) as days_of_data,
  MAX(ts) as last_processed
FROM scout.silver_transactions
WHERE source_system = 'edge_device' OR id IN (
  SELECT DISTINCT COALESCE(txn_id, payload->>'transaction_id', payload->>'id') 
  FROM scout.bronze_edge_raw
);

-- Grant permissions
GRANT SELECT ON scout.v_etl_pipeline_status TO authenticated;

COMMIT;

-- Show current pipeline status
SELECT * FROM scout.v_etl_pipeline_status;