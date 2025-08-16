-- Create ETL Metadata Table for tracking data processing

-- Create table for ETL job tracking
CREATE TABLE IF NOT EXISTS etl_metadata (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_type VARCHAR(50) NOT NULL, -- 'storage', 'xata', 's3', 'api'
  source_name VARCHAR(255) NOT NULL, -- bucket name, endpoint, etc.
  started_at TIMESTAMP WITH TIME ZONE NOT NULL,
  completed_at TIMESTAMP WITH TIME ZONE,
  status VARCHAR(20) DEFAULT 'running', -- 'running', 'completed', 'failed'
  bronze_processed INTEGER DEFAULT 0,
  silver_processed INTEGER DEFAULT 0,
  gold_processed INTEGER DEFAULT 0,
  error_message TEXT,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for performance
CREATE INDEX idx_etl_metadata_source ON etl_metadata(source_type, source_name);
CREATE INDEX idx_etl_metadata_status ON etl_metadata(status);
CREATE INDEX idx_etl_metadata_created ON etl_metadata(created_at DESC);

-- Create function to get latest ETL status
CREATE OR REPLACE FUNCTION get_latest_etl_status(p_source_type VARCHAR DEFAULT NULL)
RETURNS TABLE (
  source_type VARCHAR,
  source_name VARCHAR,
  last_run TIMESTAMP WITH TIME ZONE,
  status VARCHAR,
  records_processed INTEGER,
  duration_seconds INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT ON (em.source_type, em.source_name)
    em.source_type,
    em.source_name,
    em.completed_at as last_run,
    em.status,
    COALESCE(em.bronze_processed, 0) + COALESCE(em.silver_processed, 0) as records_processed,
    EXTRACT(EPOCH FROM (em.completed_at - em.started_at))::INTEGER as duration_seconds
  FROM etl_metadata em
  WHERE (p_source_type IS NULL OR em.source_type = p_source_type)
    AND em.status = 'completed'
  ORDER BY em.source_type, em.source_name, em.completed_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Create view for ETL dashboard
CREATE OR REPLACE VIEW v_etl_dashboard AS
SELECT 
  source_type,
  source_name,
  COUNT(*) as total_runs,
  COUNT(CASE WHEN status = 'completed' THEN 1 END) as successful_runs,
  COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_runs,
  MAX(completed_at) as last_successful_run,
  SUM(bronze_processed) as total_bronze_processed,
  SUM(silver_processed) as total_silver_processed,
  AVG(EXTRACT(EPOCH FROM (completed_at - started_at))) as avg_duration_seconds
FROM etl_metadata
GROUP BY source_type, source_name;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON etl_metadata TO authenticated;
GRANT SELECT ON v_etl_dashboard TO authenticated;
GRANT EXECUTE ON FUNCTION get_latest_etl_status TO authenticated;