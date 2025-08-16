-- Cross-Region Replication Schema
-- Enables dataset replication across multiple regions for improved availability and performance

-- Create replication schema
CREATE SCHEMA IF NOT EXISTS replication;

-- Region enum
CREATE TYPE replication.region_type AS ENUM (
  'us-east-1',
  'us-west-2',
  'eu-west-1',
  'eu-central-1',
  'ap-southeast-1',
  'ap-northeast-1'
);

-- Replication status enum
CREATE TYPE replication.replication_status AS ENUM (
  'pending',
  'in_progress', 
  'completed',
  'failed',
  'cancelled'
);

-- Replication policy enum
CREATE TYPE replication.replication_policy AS ENUM (
  'immediate',    -- Replicate immediately after upload
  'scheduled',    -- Replicate on schedule
  'on_demand',    -- Manual replication only
  'disabled'      -- No replication
);

-- Region configurations
CREATE TABLE replication.region_configs (
  region replication.region_type PRIMARY KEY,
  is_active BOOLEAN DEFAULT true,
  storage_endpoint TEXT NOT NULL,
  access_key_id TEXT,
  secret_access_key TEXT,
  bucket_name TEXT NOT NULL,
  cdn_endpoint TEXT,
  priority INTEGER DEFAULT 1, -- 1=primary, 2=secondary, etc.
  cost_per_gb DECIMAL(10,4) DEFAULT 0.023, -- Storage cost per GB
  bandwidth_cost_per_gb DECIMAL(10,4) DEFAULT 0.09, -- Transfer cost per GB
  latency_ms INTEGER DEFAULT 100, -- Average latency to region
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Dataset replication rules
CREATE TABLE replication.dataset_replication_rules (
  rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dataset_pattern TEXT NOT NULL, -- Regex pattern for dataset names
  source_region replication.region_type NOT NULL,
  target_regions replication.region_type[] NOT NULL,
  replication_policy replication.replication_policy DEFAULT 'scheduled',
  priority INTEGER DEFAULT 5, -- 1=highest, 10=lowest
  max_file_size_mb INTEGER, -- Skip files larger than this
  file_type_filter TEXT[], -- Only replicate these file types
  retention_days INTEGER DEFAULT 90, -- Keep replicas for N days
  bandwidth_limit_mbps INTEGER DEFAULT 100, -- Rate limit
  schedule_cron TEXT DEFAULT '0 2 * * *', -- Daily at 2 AM
  is_active BOOLEAN DEFAULT true,
  created_by TEXT DEFAULT 'system',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Dataset replica tracking
CREATE TABLE replication.dataset_replicas (
  replica_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dataset_name TEXT NOT NULL,
  file_path TEXT NOT NULL, -- Original file path
  source_region replication.region_type NOT NULL,
  target_region replication.region_type NOT NULL,
  replica_path TEXT NOT NULL, -- Path in target region
  file_size BIGINT NOT NULL,
  checksum TEXT NOT NULL,
  replication_status replication.replication_status DEFAULT 'pending',
  rule_id UUID REFERENCES replication.dataset_replication_rules(rule_id),
  started_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  error_message TEXT,
  transfer_size_bytes BIGINT DEFAULT 0,
  transfer_duration_ms INTEGER,
  cost_estimate DECIMAL(10,4), -- Estimated cost for this replication
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Replication jobs queue
CREATE TABLE replication.replication_jobs (
  job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_type TEXT DEFAULT 'replicate_dataset', -- replicate_dataset, sync_region, cleanup_expired
  dataset_name TEXT,
  source_region replication.region_type,
  target_region replication.region_type,
  file_path TEXT,
  priority INTEGER DEFAULT 5,
  status replication.replication_status DEFAULT 'pending',
  scheduled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  started_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  worker_id TEXT, -- ID of worker processing this job
  error_message TEXT,
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Replication performance metrics
CREATE TABLE replication.replication_metrics (
  metric_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_region replication.region_type NOT NULL,
  target_region replication.region_type NOT NULL,
  metric_date DATE DEFAULT CURRENT_DATE,
  total_files_replicated INTEGER DEFAULT 0,
  total_bytes_transferred BIGINT DEFAULT 0,
  average_transfer_speed_mbps DECIMAL(10,2) DEFAULT 0,
  success_rate DECIMAL(5,2) DEFAULT 100.00, -- Percentage
  average_latency_ms INTEGER DEFAULT 0,
  total_cost DECIMAL(12,4) DEFAULT 0,
  peak_bandwidth_mbps DECIMAL(10,2) DEFAULT 0,
  error_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(source_region, target_region, metric_date)
);

-- Indexes for performance
CREATE INDEX idx_replicas_dataset ON replication.dataset_replicas(dataset_name);
CREATE INDEX idx_replicas_status ON replication.dataset_replicas(replication_status);
CREATE INDEX idx_replicas_regions ON replication.dataset_replicas(source_region, target_region);
CREATE INDEX idx_replicas_created_at ON replication.dataset_replicas(created_at);

CREATE INDEX idx_jobs_status ON replication.replication_jobs(status);
CREATE INDEX idx_jobs_priority ON replication.replication_jobs(priority);
CREATE INDEX idx_jobs_scheduled_at ON replication.replication_jobs(scheduled_at);
CREATE INDEX idx_jobs_worker ON replication.replication_jobs(worker_id);

CREATE INDEX idx_rules_pattern ON replication.dataset_replication_rules(dataset_pattern);
CREATE INDEX idx_rules_active ON replication.dataset_replication_rules(is_active);

CREATE INDEX idx_metrics_date ON replication.replication_metrics(metric_date);
CREATE INDEX idx_metrics_regions ON replication.replication_metrics(source_region, target_region);

-- Views for monitoring and analytics

-- Active replicas summary
CREATE OR REPLACE VIEW replication.replication_summary AS
SELECT 
  source_region,
  target_region,
  COUNT(*) as total_replicas,
  COUNT(*) FILTER (WHERE replication_status = 'completed') as completed_replicas,
  COUNT(*) FILTER (WHERE replication_status = 'in_progress') as in_progress_replicas,
  COUNT(*) FILTER (WHERE replication_status = 'failed') as failed_replicas,
  COALESCE(SUM(file_size) FILTER (WHERE replication_status = 'completed'), 0) as total_replicated_bytes,
  AVG(transfer_duration_ms) FILTER (WHERE replication_status = 'completed') as avg_transfer_time_ms,
  MAX(completed_at) as last_replication_time
FROM replication.dataset_replicas
GROUP BY source_region, target_region
ORDER BY source_region, target_region;

-- Dataset availability across regions
CREATE OR REPLACE VIEW replication.dataset_availability AS
SELECT 
  dataset_name,
  COUNT(DISTINCT target_region) FILTER (WHERE replication_status = 'completed') as available_regions,
  array_agg(DISTINCT target_region) FILTER (WHERE replication_status = 'completed') as regions_list,
  MAX(completed_at) as last_replicated,
  SUM(file_size) FILTER (WHERE replication_status = 'completed') as total_replica_size,
  COUNT(*) FILTER (WHERE replication_status = 'failed') as failed_replications
FROM replication.dataset_replicas
GROUP BY dataset_name
ORDER BY available_regions DESC, dataset_name;

-- Replication job queue status
CREATE OR REPLACE VIEW replication.job_queue_status AS
SELECT 
  status,
  COUNT(*) as job_count,
  MIN(scheduled_at) as oldest_job,
  MAX(scheduled_at) as newest_job,
  AVG(priority) as avg_priority,
  COUNT(*) FILTER (WHERE retry_count > 0) as retried_jobs
FROM replication.replication_jobs
GROUP BY status
ORDER BY 
  CASE status
    WHEN 'pending' THEN 1
    WHEN 'in_progress' THEN 2
    WHEN 'completed' THEN 3
    WHEN 'failed' THEN 4
    WHEN 'cancelled' THEN 5
  END;

-- Functions

-- Get optimal region for dataset access
CREATE OR REPLACE FUNCTION replication.get_optimal_region(
  p_dataset_name TEXT,
  p_user_location TEXT DEFAULT 'us-east-1'
) RETURNS TABLE (
  region replication.region_type,
  replica_path TEXT,
  estimated_latency_ms INTEGER,
  availability_score INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    dr.target_region as region,
    dr.replica_path,
    rc.latency_ms as estimated_latency_ms,
    -- Availability score based on successful replications and region priority
    (100 - rc.priority * 10 + 
     CASE WHEN dr.replication_status = 'completed' THEN 50 ELSE 0 END) as availability_score
  FROM replication.dataset_replicas dr
  JOIN replication.region_configs rc ON dr.target_region = rc.region
  WHERE dr.dataset_name = p_dataset_name
    AND dr.replication_status = 'completed'
    AND rc.is_active = true
  ORDER BY 
    -- Prefer regions with lower latency and higher availability
    rc.latency_ms ASC,
    availability_score DESC,
    rc.priority ASC
  LIMIT 3;
END;
$$ LANGUAGE plpgsql;

-- Calculate replication cost estimate
CREATE OR REPLACE FUNCTION replication.estimate_replication_cost(
  p_file_size_bytes BIGINT,
  p_source_region replication.region_type,
  p_target_region replication.region_type
) RETURNS DECIMAL(10,4) AS $$
DECLARE
  source_config replication.region_configs%ROWTYPE;
  target_config replication.region_configs%ROWTYPE;
  transfer_cost DECIMAL(10,4);
  storage_cost DECIMAL(10,4);
  total_cost DECIMAL(10,4);
BEGIN
  -- Get region configurations
  SELECT * INTO source_config FROM replication.region_configs WHERE region = p_source_region;
  SELECT * INTO target_config FROM replication.region_configs WHERE region = p_target_region;
  
  -- Calculate costs (per GB)
  transfer_cost := (p_file_size_bytes / (1024^3)::DECIMAL) * source_config.bandwidth_cost_per_gb;
  storage_cost := (p_file_size_bytes / (1024^3)::DECIMAL) * target_config.cost_per_gb;
  
  total_cost := transfer_cost + storage_cost;
  
  RETURN total_cost;
END;
$$ LANGUAGE plpgsql;

-- Get replication statistics
CREATE OR REPLACE FUNCTION replication.get_replication_stats(
  p_days INTEGER DEFAULT 30
) RETURNS TABLE (
  total_replications BIGINT,
  successful_replications BIGINT,
  failed_replications BIGINT,
  success_rate DECIMAL(5,2),
  total_data_replicated_gb DECIMAL(12,2),
  average_transfer_speed_mbps DECIMAL(10,2),
  total_estimated_cost DECIMAL(12,4),
  most_replicated_dataset TEXT,
  slowest_region_pair TEXT
) AS $$
BEGIN
  RETURN QUERY
  WITH stats AS (
    SELECT 
      COUNT(*) as total_reps,
      COUNT(*) FILTER (WHERE replication_status = 'completed') as successful_reps,
      COUNT(*) FILTER (WHERE replication_status = 'failed') as failed_reps,
      SUM(file_size) FILTER (WHERE replication_status = 'completed') as total_bytes,
      AVG(transfer_size_bytes::DECIMAL / transfer_duration_ms * 1000 / (1024*1024)) 
        FILTER (WHERE replication_status = 'completed' AND transfer_duration_ms > 0) as avg_speed,
      SUM(cost_estimate) as total_cost
    FROM replication.dataset_replicas
    WHERE created_at > NOW() - INTERVAL '1 day' * p_days
  ),
  top_dataset AS (
    SELECT dataset_name
    FROM replication.dataset_replicas
    WHERE created_at > NOW() - INTERVAL '1 day' * p_days
    GROUP BY dataset_name
    ORDER BY COUNT(*) DESC
    LIMIT 1
  ),
  slowest_pair AS (
    SELECT source_region || ' -> ' || target_region as region_pair
    FROM replication.dataset_replicas
    WHERE created_at > NOW() - INTERVAL '1 day' * p_days
      AND transfer_duration_ms IS NOT NULL
    GROUP BY source_region, target_region
    ORDER BY AVG(transfer_duration_ms) DESC
    LIMIT 1
  )
  SELECT 
    s.total_reps,
    s.successful_reps,
    s.failed_reps,
    CASE WHEN s.total_reps > 0 THEN (s.successful_reps * 100.0 / s.total_reps) ELSE 0 END::DECIMAL(5,2),
    (s.total_bytes / (1024^3)::DECIMAL)::DECIMAL(12,2),
    COALESCE(s.avg_speed, 0)::DECIMAL(10,2),
    COALESCE(s.total_cost, 0)::DECIMAL(12,4),
    td.dataset_name,
    sp.region_pair
  FROM stats s
  CROSS JOIN top_dataset td
  CROSS JOIN slowest_pair sp;
END;
$$ LANGUAGE plpgsql;

-- Triggers

-- Update replication metrics when replica status changes
CREATE OR REPLACE FUNCTION replication.update_replication_metrics()
RETURNS TRIGGER AS $$
BEGIN
  -- Update daily metrics when a replication completes
  IF NEW.replication_status = 'completed' AND OLD.replication_status != 'completed' THEN
    INSERT INTO replication.replication_metrics (
      source_region,
      target_region,
      metric_date,
      total_files_replicated,
      total_bytes_transferred,
      average_transfer_speed_mbps,
      success_rate,
      total_cost
    ) VALUES (
      NEW.source_region,
      NEW.target_region,
      CURRENT_DATE,
      1,
      NEW.file_size,
      CASE 
        WHEN NEW.transfer_duration_ms > 0 THEN 
          (NEW.transfer_size_bytes::DECIMAL / NEW.transfer_duration_ms * 1000 / (1024*1024))
        ELSE 0 
      END,
      100.0,
      COALESCE(NEW.cost_estimate, 0)
    )
    ON CONFLICT (source_region, target_region, metric_date) DO UPDATE SET
      total_files_replicated = replication.replication_metrics.total_files_replicated + 1,
      total_bytes_transferred = replication.replication_metrics.total_bytes_transferred + NEW.file_size,
      average_transfer_speed_mbps = (
        replication.replication_metrics.average_transfer_speed_mbps + 
        CASE 
          WHEN NEW.transfer_duration_ms > 0 THEN 
            (NEW.transfer_size_bytes::DECIMAL / NEW.transfer_duration_ms * 1000 / (1024*1024))
          ELSE 0 
        END
      ) / 2,
      total_cost = replication.replication_metrics.total_cost + COALESCE(NEW.cost_estimate, 0);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_replication_metrics
  AFTER UPDATE ON replication.dataset_replicas
  FOR EACH ROW EXECUTE FUNCTION replication.update_replication_metrics();

-- Insert sample region configurations
INSERT INTO replication.region_configs (region, storage_endpoint, bucket_name, priority, cost_per_gb, bandwidth_cost_per_gb, latency_ms) VALUES
('us-east-1', 's3.amazonaws.com', 'scout-datasets-us-east-1', 1, 0.023, 0.09, 50),
('us-west-2', 's3.us-west-2.amazonaws.com', 'scout-datasets-us-west-2', 2, 0.023, 0.09, 80),
('eu-west-1', 's3.eu-west-1.amazonaws.com', 'scout-datasets-eu-west-1', 2, 0.025, 0.09, 120),
('eu-central-1', 's3.eu-central-1.amazonaws.com', 'scout-datasets-eu-central-1', 3, 0.024, 0.09, 140),
('ap-southeast-1', 's3.ap-southeast-1.amazonaws.com', 'scout-datasets-ap-southeast-1', 3, 0.025, 0.12, 200),
('ap-northeast-1', 's3.ap-northeast-1.amazonaws.com', 'scout-datasets-ap-northeast-1', 4, 0.025, 0.14, 220)
ON CONFLICT (region) DO NOTHING;

-- Insert sample replication rules
INSERT INTO replication.dataset_replication_rules (dataset_pattern, source_region, target_regions, replication_policy, priority, retention_days) VALUES
('daily_.*', 'us-east-1', ARRAY['us-west-2', 'eu-west-1']::replication.region_type[], 'immediate', 1, 30),
('store_.*', 'us-east-1', ARRAY['us-west-2']::replication.region_type[], 'scheduled', 3, 90),
('ml_.*', 'us-east-1', ARRAY['us-west-2', 'eu-west-1', 'ap-southeast-1']::replication.region_type[], 'immediate', 2, 180),
('.*_gold', 'us-east-1', ARRAY['eu-west-1', 'ap-southeast-1']::replication.region_type[], 'scheduled', 4, 60),
('.*_platinum', 'us-east-1', ARRAY['us-west-2', 'eu-west-1']::replication.region_type[], 'immediate', 1, 365)
ON CONFLICT DO NOTHING;

-- Grant permissions
GRANT USAGE ON SCHEMA replication TO authenticated, anon, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA replication TO authenticated, anon;
GRANT ALL ON ALL TABLES IN SCHEMA replication TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA replication TO authenticated, anon, service_role;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA replication TO service_role;

-- Row Level Security
ALTER TABLE replication.region_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE replication.dataset_replication_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE replication.dataset_replicas ENABLE ROW LEVEL SECURITY;
ALTER TABLE replication.replication_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE replication.replication_metrics ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view region configurations" ON replication.region_configs
  FOR SELECT USING (true);

CREATE POLICY "Service role can manage region configs" ON replication.region_configs
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Users can view replication rules" ON replication.dataset_replication_rules
  FOR SELECT USING (true);

CREATE POLICY "Service role can manage replication rules" ON replication.dataset_replication_rules
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Users can view replicas" ON replication.dataset_replicas
  FOR SELECT USING (true);

CREATE POLICY "Service role can manage replicas" ON replication.dataset_replicas
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Users can view replication jobs" ON replication.replication_jobs
  FOR SELECT USING (true);

CREATE POLICY "Service role can manage replication jobs" ON replication.replication_jobs
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Users can view replication metrics" ON replication.replication_metrics
  FOR SELECT USING (true);

CREATE POLICY "Service role can manage replication metrics" ON replication.replication_metrics
  FOR ALL USING (auth.role() = 'service_role');