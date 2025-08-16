-- 030_source_file_tracking.sql
-- Add functions for source file tracking and lineage

-- Function to get source file summary
CREATE OR REPLACE FUNCTION scout.get_source_file_summary()
RETURNS TABLE(
  source_file TEXT,
  transactions BIGINT,
  total_revenue NUMERIC,
  date_range TEXT,
  has_items BOOLEAN,
  data_quality TEXT
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  WITH file_summary AS (
    SELECT 
      COALESCE(t.source_file, 'unknown') as source_file,
      COUNT(DISTINCT t.transaction_id) as transactions,
      SUM(t.total_amount) as total_revenue,
      MIN(t.transaction_date)::TEXT || ' to ' || MAX(t.transaction_date)::TEXT as date_range,
      COUNT(ti.transaction_id) > 0 as has_items,
      CASE 
        WHEN COUNT(ti.transaction_id) > 0 THEN 'good'
        WHEN COUNT(t.transaction_id) > 0 THEN 'warning'
        ELSE 'error'
      END as data_quality
    FROM scout.fact_transactions t
    LEFT JOIN scout.fact_transaction_items ti ON t.transaction_id = ti.transaction_id
    GROUP BY t.source_file
  )
  SELECT * FROM file_summary
  ORDER BY total_revenue DESC;
$$;

-- Function to trace data lineage for a specific transaction
CREATE OR REPLACE FUNCTION scout.trace_transaction_lineage(p_transaction_id UUID)
RETURNS TABLE(
  stage TEXT,
  table_name TEXT,
  record_count BIGINT,
  timestamp TIMESTAMPTZ,
  details JSONB
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  -- Bronze layer
  SELECT 
    'Bronze' as stage,
    'bronze_transactions' as table_name,
    COUNT(*) as record_count,
    MIN(created_at) as timestamp,
    jsonb_build_object(
      'source_file', MIN(source_file),
      'raw_data_status', 'loaded'
    ) as details
  FROM scout.bronze_transactions
  WHERE transaction_id = p_transaction_id
  
  UNION ALL
  
  -- Silver layer
  SELECT 
    'Silver' as stage,
    'silver_transactions' as table_name,
    COUNT(*) as record_count,
    MIN(created_at) as timestamp,
    jsonb_build_object(
      'validation_status', 'passed',
      'transformations', 'cleaned'
    ) as details
  FROM scout.silver_transactions
  WHERE transaction_id = p_transaction_id
  
  UNION ALL
  
  -- Gold layer
  SELECT 
    'Gold' as stage,
    'fact_transactions' as table_name,
    COUNT(*) as record_count,
    MIN(created_at) as timestamp,
    jsonb_build_object(
      'enrichments', 'complete',
      'ready_for_analytics', true
    ) as details
  FROM scout.fact_transactions
  WHERE transaction_id = p_transaction_id
  
  ORDER BY timestamp;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION scout.get_source_file_summary TO anon, authenticated, dash_ro;
GRANT EXECUTE ON FUNCTION scout.trace_transaction_lineage TO anon, authenticated, dash_ro;