-- =====================================================
-- Archive EDA Summary Persistence & Parquet Export Setup
-- =====================================================

-- 1) Archive EDA Summary Table & Data
-- ----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS scout;

CREATE TABLE IF NOT EXISTS scout.archive_eda_summary (
  archive_code TEXT PRIMARY KEY,
  filename     TEXT NOT NULL,
  txn_count    INTEGER NOT NULL,
  store_count  INTEGER NOT NULL,
  morning_cnt  INTEGER NOT NULL,
  afternoon_cnt INTEGER NOT NULL,
  evening_cnt  INTEGER NOT NULL,
  night_cnt    INTEGER NOT NULL,
  dur_avg_s    NUMERIC(6,2) NOT NULL,
  dur_med_s    NUMERIC(6,2) NOT NULL,
  dur_p90_s    NUMERIC(6,2) NOT NULL,
  brand_cov_pct NUMERIC(5,2) NOT NULL,
  cat_cov_pct   NUMERIC(5,2) NOT NULL,
  sku_field_present_pct NUMERIC(5,2) NOT NULL,
  items_present_pct     NUMERIC(5,2) NOT NULL,
  prices_present_pct    NUMERIC(5,2) NOT NULL,
  suggest_accept_pct    NUMERIC(5,2) NOT NULL,
  req_branded_cnt   INTEGER NOT NULL,
  req_unbranded_cnt INTEGER NOT NULL,
  req_point_cnt     INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert EDA data for 4 archives (idempotent upserts)
INSERT INTO scout.archive_eda_summary AS t VALUES
  ('scoutpi-0002','scoutpi-0002-20250814T194516Z-1-001.zip',
    2377,1, 0,2377,0,0, 7.03,5.88,13.14, 57.09,53.22,100.00,0.00,0.00,5.55, 941,1219,217)
ON CONFLICT (archive_code) DO UPDATE SET
  filename=excluded.filename, txn_count=excluded.txn_count, store_count=excluded.store_count,
  morning_cnt=excluded.morning_cnt, afternoon_cnt=excluded.afternoon_cnt,
  evening_cnt=excluded.evening_cnt, night_cnt=excluded.night_cnt,
  dur_avg_s=excluded.dur_avg_s, dur_med_s=excluded.dur_med_s, dur_p90_s=excluded.dur_p90_s,
  brand_cov_pct=excluded.brand_cov_pct, cat_cov_pct=excluded.cat_cov_pct,
  sku_field_present_pct=excluded.sku_field_present_pct, items_present_pct=excluded.items_present_pct,
  prices_present_pct=excluded.prices_present_pct, suggest_accept_pct=excluded.suggest_accept_pct,
  req_branded_cnt=excluded.req_branded_cnt, req_unbranded_cnt=excluded.req_unbranded_cnt, req_point_cnt=excluded.req_point_cnt;

INSERT INTO scout.archive_eda_summary AS t VALUES
  ('scoutpi-0003','scoutpi-0003-20250814T194702Z-1-001.zip',
    7649,1, 746,3506,2116,1281, 6.82,5.86,13.06, 56.09,50.92,100.00,0.00,0.00,5.07, 3023,3991,635)
ON CONFLICT (archive_code) DO UPDATE SET
  filename=excluded.filename, txn_count=excluded.txn_count, store_count=excluded.store_count,
  morning_cnt=excluded.morning_cnt, afternoon_cnt=excluded.afternoon_cnt,
  evening_cnt=excluded.evening_cnt, night_cnt=excluded.night_cnt,
  dur_avg_s=excluded.dur_avg_s, dur_med_s=excluded.dur_med_s, dur_p90_s=excluded.dur_p90_s,
  brand_cov_pct=excluded.brand_cov_pct, cat_cov_pct=excluded.cat_cov_pct,
  sku_field_present_pct=excluded.sku_field_present_pct, items_present_pct=excluded.items_present_pct,
  prices_present_pct=excluded.prices_present_pct, suggest_accept_pct=excluded.suggest_accept_pct,
  req_branded_cnt=excluded.req_branded_cnt, req_unbranded_cnt=excluded.req_unbranded_cnt, req_point_cnt=excluded.req_point_cnt;

INSERT INTO scout.archive_eda_summary AS t VALUES
  ('scoutpi-0006','scoutpi-0006-20250814T194654Z-1-001.zip',
    10936,1, 2210,1372,3712,3642, 7.96,6.04,13.67, 57.18,51.81,100.00,0.00,0.00,5.18, 4445,5656,835)
ON CONFLICT (archive_code) DO UPDATE SET
  filename=excluded.filename, txn_count=excluded.txn_count, store_count=excluded.store_count,
  morning_cnt=excluded.morning_cnt, afternoon_cnt=excluded.afternoon_cnt,
  evening_cnt=excluded.evening_cnt, night_cnt=excluded.night_cnt,
  dur_avg_s=excluded.dur_avg_s, dur_med_s=excluded.dur_med_s, dur_p90_s=excluded.dur_p90_s,
  brand_cov_pct=excluded.brand_cov_pct, cat_cov_pct=excluded.cat_cov_pct,
  sku_field_present_pct=excluded.sku_field_present_pct, items_present_pct=excluded.items_present_pct,
  prices_present_pct=excluded.prices_present_pct, suggest_accept_pct=excluded.suggest_accept_pct,
  req_branded_cnt=excluded.req_branded_cnt, req_unbranded_cnt=excluded.req_unbranded_cnt, req_point_cnt=excluded.req_point_cnt;

INSERT INTO scout.archive_eda_summary AS t VALUES
  ('scoutpi-0009','scoutpi-0009-20250814T194511Z-1-001.zip',
    4901,1, 2803,1381,0,717, 7.17,6.00,13.20, 56.74,51.44,100.00,0.00,0.00,4.75, 1944,2519,438)
ON CONFLICT (archive_code) DO UPDATE SET
  filename=excluded.filename, txn_count=excluded.txn_count, store_count=excluded.store_count,
  morning_cnt=excluded.morning_cnt, afternoon_cnt=excluded.afternoon_cnt,
  evening_cnt=excluded.evening_cnt, night_cnt=excluded.night_cnt,
  dur_avg_s=excluded.dur_avg_s, dur_med_s=excluded.dur_med_s, dur_p90_s=excluded.dur_p90_s,
  brand_cov_pct=excluded.brand_cov_pct, cat_cov_pct=excluded.cat_cov_pct,
  sku_field_present_pct=excluded.sku_field_present_pct, items_present_pct=excluded.items_present_pct,
  prices_present_pct=excluded.prices_present_pct, suggest_accept_pct=excluded.suggest_accept_pct,
  req_branded_cnt=excluded.req_branded_cnt, req_unbranded_cnt=excluded.req_unbranded_cnt, req_point_cnt=excluded.req_point_cnt;

-- DAL view for UI access
CREATE SCHEMA IF NOT EXISTS scout_dal;
CREATE OR REPLACE VIEW scout_dal.v_archive_eda_summary AS
SELECT
  archive_code, filename, txn_count, store_count,
  morning_cnt, afternoon_cnt, evening_cnt, night_cnt,
  dur_avg_s, dur_med_s, dur_p90_s,
  brand_cov_pct, cat_cov_pct, sku_field_present_pct,
  items_present_pct, prices_present_pct, suggest_accept_pct,
  req_branded_cnt, req_unbranded_cnt, req_point_cnt, created_at
FROM scout.archive_eda_summary;

GRANT USAGE ON SCHEMA scout_dal TO anon, authenticated;
GRANT SELECT ON scout_dal.v_archive_eda_summary TO anon, authenticated;

-- Optional: Roll-up to quality_metrics table if present
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='scout' AND table_name='quality_metrics') THEN
    INSERT INTO scout.quality_metrics(metric_name, metric_value, window)
    VALUES
      ('archive_txns_total', 25863, '4-archives'),
      ('archive_brand_cov_pct', 56.76, '4-archives'),
      ('archive_cat_cov_pct',   51.69, '4-archives'),
      ('archive_items_pct',      0.00, '4-archives'),
      ('archive_prices_pct',     0.00, '4-archives'),
      ('archive_suggest_pct',    5.10, '4-archives')
    ON CONFLICT (metric_name, window) DO UPDATE 
    SET metric_value = excluded.metric_value,
        ts = NOW();
  END IF;
END$$;

-- 2) Parquet Export Setup
-- ----------------------------------------------------
-- Create private datasets bucket (idempotent)
CREATE SCHEMA IF NOT EXISTS storage;
INSERT INTO storage.buckets (id, name, public)
VALUES ('datasets','datasets', false)
ON CONFLICT (id) DO NOTHING;

-- Secure the bucket - deny public reads
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "public read" ON storage.objects;
DROP POLICY IF EXISTS "public upload" ON storage.objects;

-- Allow service role everything on 'datasets' bucket
CREATE POLICY "srw datasets"
ON storage.objects FOR ALL
TO service_role
USING (bucket_id='datasets')
WITH CHECK (bucket_id='datasets');

-- 3) Export Views for Stable Schema
-- ----------------------------------------------------
-- Master items export view with stable schema
CREATE OR REPLACE VIEW scout.v_master_items_export AS
SELECT
  COALESCE(brand_name,'')::TEXT          AS brand_name,
  COALESCE(product_name,'')::TEXT        AS product_name,
  COALESCE(product_category,'')::TEXT    AS product_category,
  pack_size_value::NUMERIC,
  COALESCE(pack_size_unit,'')::TEXT      AS pack_size_unit,
  list_price::NUMERIC,
  currency::TEXT,
  observed_at::TIMESTAMPTZ
FROM scout.master_items;

-- Archive EDA export view
CREATE OR REPLACE VIEW scout.v_archive_eda_export AS
SELECT
  archive_code::TEXT,
  filename::TEXT,
  txn_count::INTEGER,
  store_count::INTEGER,
  morning_cnt::INTEGER,
  afternoon_cnt::INTEGER,
  evening_cnt::INTEGER,
  night_cnt::INTEGER,
  dur_avg_s::NUMERIC(6,2),
  dur_med_s::NUMERIC(6,2),
  dur_p90_s::NUMERIC(6,2),
  brand_cov_pct::NUMERIC(5,2),
  cat_cov_pct::NUMERIC(5,2),
  sku_field_present_pct::NUMERIC(5,2),
  items_present_pct::NUMERIC(5,2),
  prices_present_pct::NUMERIC(5,2),
  suggest_accept_pct::NUMERIC(5,2),
  req_branded_cnt::INTEGER,
  req_unbranded_cnt::INTEGER,
  req_point_cnt::INTEGER,
  created_at::TIMESTAMPTZ
FROM scout.archive_eda_summary;

-- 4) Scheduled Parquet Export Functions
-- ----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS suqi;

-- Daily parquet export function
CREATE OR REPLACE FUNCTION suqi.fn_schedule_parquet_exports()
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE 
  p TEXT := TO_CHAR(NOW() AT TIME ZONE 'Asia/Manila','YYYY-MM-DD');
  url TEXT;
  auth_header TEXT;
BEGIN
  -- Get settings (these need to be set via ALTER DATABASE or session)
  url := current_setting('app.supabase_url', true);
  auth_header := 'Bearer ' || current_setting('app.service_key', true);
  
  -- Export master items
  PERFORM net.http_post(
    url := url || '/functions/v1/export-parquet',
    headers := jsonb_build_object(
      'Authorization', auth_header,
      'content-type', 'application/json'
    ),
    body := jsonb_build_object(
      'target', jsonb_build_object(
        'type','supabase-storage',
        'bucket','datasets',
        'path', format('scout/master_items/dt=%s/master_items_%s.parquet',p,p)
      ),
      'query', 'select * from scout.v_master_items_export',
      'format', jsonb_build_object(
        'type','parquet',
        'compression','zstd',
        'row_group_size',128000
      )
    )
  );
  
  -- Export archive EDA summary
  PERFORM net.http_post(
    url := url || '/functions/v1/export-parquet',
    headers := jsonb_build_object(
      'Authorization', auth_header,
      'content-type', 'application/json'
    ),
    body := jsonb_build_object(
      'target', jsonb_build_object(
        'type','supabase-storage',
        'bucket','datasets',
        'path', format('scout/archive_eda/dt=%s/archive_eda_%s.parquet',p,p)
      ),
      'query', 'select * from scout.v_archive_eda_export',
      'format', jsonb_build_object(
        'type','parquet',
        'compression','zstd'
      )
    )
  );
END$$;

-- Note: To schedule the cron job, run these commands with proper credentials:
-- SELECT set_config('app.supabase_url', 'https://cxzllzyxwpyptfretryc.supabase.co', false);
-- SELECT set_config('app.service_key', '<SERVICE_ROLE_KEY>', false);
-- SELECT cron.schedule('parquet-exports-daily','20 2 * * *', $$ SELECT suqi.fn_schedule_parquet_exports() $$);

-- 5) Helper Views for Analytics
-- ----------------------------------------------------
-- Time of day distribution view
CREATE OR REPLACE VIEW scout_dal.v_archive_time_distribution AS
SELECT 
  archive_code,
  'Morning (6AM-12PM)' AS time_period, morning_cnt AS transaction_count
FROM scout.archive_eda_summary
UNION ALL
SELECT 
  archive_code,
  'Afternoon (12PM-6PM)', afternoon_cnt
FROM scout.archive_eda_summary
UNION ALL
SELECT 
  archive_code,
  'Evening (6PM-12AM)', evening_cnt
FROM scout.archive_eda_summary
UNION ALL
SELECT 
  archive_code,
  'Night (12AM-6AM)', night_cnt
FROM scout.archive_eda_summary
ORDER BY archive_code, time_period;

GRANT SELECT ON scout_dal.v_archive_time_distribution TO anon, authenticated;

-- Summary statistics view
CREATE OR REPLACE VIEW scout_dal.v_archive_summary_stats AS
SELECT
  COUNT(*) AS total_archives,
  SUM(txn_count) AS total_transactions,
  AVG(brand_cov_pct) AS avg_brand_coverage,
  AVG(cat_cov_pct) AS avg_category_coverage,
  AVG(dur_avg_s) AS avg_transaction_duration,
  MIN(created_at) AS earliest_archive,
  MAX(created_at) AS latest_archive
FROM scout.archive_eda_summary;

GRANT SELECT ON scout_dal.v_archive_summary_stats TO anon, authenticated;