-- Usage Analytics Schema for Dataset Publisher
-- Creates tables and views for tracking dataset usage patterns

-- Create usage analytics schema
CREATE SCHEMA IF NOT EXISTS usage_analytics;

-- Usage event types
CREATE TYPE usage_event_type AS ENUM (
  'download',
  'api_call',
  'export',
  'view',
  'search',
  'error'
);

-- Dataset usage logs (raw events)
CREATE TABLE usage_analytics.dataset_usage_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type usage_event_type NOT NULL,
  dataset_name TEXT NOT NULL,
  user_id TEXT,
  session_id TEXT,
  ip_address INET,
  user_agent TEXT,
  metadata JSONB DEFAULT '{}',
  file_size BIGINT,
  format TEXT,
  region TEXT DEFAULT 'unknown',
  response_time_ms INTEGER,
  status_code INTEGER,
  error_message TEXT,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Partitioning by date for performance
CREATE TABLE usage_analytics.dataset_usage_logs_y2025m01 
  PARTITION OF usage_analytics.dataset_usage_logs 
  FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE usage_analytics.dataset_usage_logs_y2025m02 
  PARTITION OF usage_analytics.dataset_usage_logs 
  FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

CREATE TABLE usage_analytics.dataset_usage_logs_y2025m03 
  PARTITION OF usage_analytics.dataset_usage_logs 
  FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');

-- User sessions tracking
CREATE TABLE usage_analytics.user_sessions (
  session_id TEXT PRIMARY KEY,
  user_id TEXT,
  ip_address INET,
  user_agent TEXT,
  region TEXT,
  first_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  total_events INTEGER DEFAULT 0,
  datasets_accessed TEXT[] DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Dataset metadata
CREATE TABLE usage_analytics.dataset_metadata (
  dataset_name TEXT PRIMARY KEY,
  category TEXT,
  description TEXT,
  schema_info JSONB,
  created_date DATE,
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  total_size_bytes BIGINT DEFAULT 0,
  average_file_size BIGINT DEFAULT 0,
  record_count BIGINT DEFAULT 0,
  is_active BOOLEAN DEFAULT true
);

-- Indexes for performance
CREATE INDEX idx_usage_logs_timestamp ON usage_analytics.dataset_usage_logs (timestamp);
CREATE INDEX idx_usage_logs_dataset ON usage_analytics.dataset_usage_logs (dataset_name);
CREATE INDEX idx_usage_logs_user ON usage_analytics.dataset_usage_logs (user_id);
CREATE INDEX idx_usage_logs_event_type ON usage_analytics.dataset_usage_logs (event_type);
CREATE INDEX idx_usage_logs_composite ON usage_analytics.dataset_usage_logs (dataset_name, event_type, timestamp);

CREATE INDEX idx_user_sessions_user_id ON usage_analytics.user_sessions (user_id);
CREATE INDEX idx_user_sessions_last_seen ON usage_analytics.user_sessions (last_seen);

-- Dataset usage summary view (aggregated metrics)
CREATE OR REPLACE VIEW usage_analytics.dataset_usage_summary AS
SELECT 
  dm.dataset_name,
  dm.category,
  dm.description,
  
  -- Download metrics
  COALESCE(usage_stats.total_downloads, 0) as total_downloads,
  COALESCE(usage_stats.downloads_last_7d, 0) as downloads_last_7d,
  COALESCE(usage_stats.downloads_last_30d, 0) as downloads_last_30d,
  
  -- API call metrics
  COALESCE(usage_stats.total_api_calls, 0) as total_api_calls,
  COALESCE(usage_stats.api_calls_last_7d, 0) as api_calls_last_7d,
  
  -- Export metrics
  COALESCE(usage_stats.total_exports, 0) as total_exports,
  
  -- User metrics
  COALESCE(usage_stats.unique_users, 0) as unique_users,
  COALESCE(usage_stats.unique_users_last_7d, 0) as unique_users_last_7d,
  
  -- Performance metrics
  COALESCE(usage_stats.average_response_time, 0) as average_response_time,
  COALESCE(usage_stats.error_rate, 0) as error_rate,
  
  -- Popular formats
  COALESCE(usage_stats.popular_formats, '[]'::jsonb) as popular_formats,
  
  -- Geographic distribution
  COALESCE(usage_stats.geographic_distribution, '[]'::jsonb) as geographic_distribution,
  
  -- Usage trends (last 30 days)
  COALESCE(usage_stats.usage_trend, '[]'::jsonb) as usage_trend,
  
  -- Metadata
  dm.total_size_bytes,
  dm.average_file_size,
  usage_stats.last_accessed,
  usage_stats.peak_usage_hour

FROM usage_analytics.dataset_metadata dm
LEFT JOIN (
  SELECT 
    dataset_name,
    
    -- Counts
    COUNT(*) FILTER (WHERE event_type = 'download') as total_downloads,
    COUNT(*) FILTER (WHERE event_type = 'download' AND timestamp > NOW() - INTERVAL '7 days') as downloads_last_7d,
    COUNT(*) FILTER (WHERE event_type = 'download' AND timestamp > NOW() - INTERVAL '30 days') as downloads_last_30d,
    COUNT(*) FILTER (WHERE event_type = 'api_call') as total_api_calls,
    COUNT(*) FILTER (WHERE event_type = 'api_call' AND timestamp > NOW() - INTERVAL '7 days') as api_calls_last_7d,
    COUNT(*) FILTER (WHERE event_type = 'export') as total_exports,
    
    -- Unique users
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT user_id) FILTER (WHERE timestamp > NOW() - INTERVAL '7 days') as unique_users_last_7d,
    
    -- Performance
    AVG(response_time_ms) as average_response_time,
    (COUNT(*) FILTER (WHERE status_code >= 400) * 100.0 / COUNT(*)) as error_rate,
    
    -- Popular formats
    jsonb_agg(DISTINCT jsonb_build_object('format', format, 'count', 
      (SELECT COUNT(*) FROM usage_analytics.dataset_usage_logs sub 
       WHERE sub.dataset_name = logs.dataset_name AND sub.format = logs.format)
    )) FILTER (WHERE format IS NOT NULL) as popular_formats,
    
    -- Geographic distribution
    jsonb_agg(DISTINCT jsonb_build_object('region', region, 'usage_count',
      (SELECT COUNT(*) FROM usage_analytics.dataset_usage_logs sub 
       WHERE sub.dataset_name = logs.dataset_name AND sub.region = logs.region)
    )) FILTER (WHERE region IS NOT NULL AND region != 'unknown') as geographic_distribution,
    
    -- Daily usage trend (last 30 days)
    jsonb_agg(
      jsonb_build_object(
        'date', trend.date,
        'downloads', trend.downloads,
        'api_calls', trend.api_calls
      ) ORDER BY trend.date
    ) as usage_trend,
    
    -- Timing
    MAX(timestamp) as last_accessed,
    MODE() WITHIN GROUP (ORDER BY EXTRACT(hour FROM timestamp)) as peak_usage_hour
    
  FROM usage_analytics.dataset_usage_logs logs
  LEFT JOIN (
    SELECT 
      dataset_name,
      DATE(timestamp) as date,
      COUNT(*) FILTER (WHERE event_type = 'download') as downloads,
      COUNT(*) FILTER (WHERE event_type = 'api_call') as api_calls
    FROM usage_analytics.dataset_usage_logs 
    WHERE timestamp > NOW() - INTERVAL '30 days'
    GROUP BY dataset_name, DATE(timestamp)
  ) trend ON trend.dataset_name = logs.dataset_name
  
  GROUP BY dataset_name
) usage_stats ON dm.dataset_name = usage_stats.dataset_name
ORDER BY COALESCE(usage_stats.downloads_last_7d, 0) DESC;

-- Hourly usage pattern view
CREATE OR REPLACE VIEW usage_analytics.hourly_usage_pattern AS
SELECT 
  EXTRACT(hour FROM timestamp) as hour,
  COUNT(*) as total_events,
  COUNT(*) FILTER (WHERE event_type = 'download') as downloads,
  COUNT(*) FILTER (WHERE event_type = 'api_call') as api_calls,
  COUNT(DISTINCT user_id) as unique_users,
  AVG(response_time_ms) as avg_response_time
FROM usage_analytics.dataset_usage_logs
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY EXTRACT(hour FROM timestamp)
ORDER BY hour;

-- Daily usage trends view
CREATE OR REPLACE VIEW usage_analytics.daily_usage_trends AS
SELECT 
  DATE(timestamp) as date,
  COUNT(*) as total_events,
  COUNT(*) FILTER (WHERE event_type = 'download') as downloads,
  COUNT(*) FILTER (WHERE event_type = 'api_call') as api_calls,
  COUNT(*) FILTER (WHERE event_type = 'export') as exports,
  COUNT(DISTINCT user_id) as unique_users,
  AVG(response_time_ms) as avg_response_time,
  (COUNT(*) FILTER (WHERE status_code >= 400) * 100.0 / COUNT(*)) as error_rate
FROM usage_analytics.dataset_usage_logs
WHERE timestamp > NOW() - INTERVAL '90 days'
GROUP BY DATE(timestamp)
ORDER BY date DESC;

-- User behavior analysis view
CREATE OR REPLACE VIEW usage_analytics.user_behavior_analysis AS
SELECT 
  user_id,
  COUNT(*) as total_events,
  COUNT(DISTINCT dataset_name) as datasets_accessed,
  COUNT(*) FILTER (WHERE event_type = 'download') as total_downloads,
  COUNT(*) FILTER (WHERE event_type = 'api_call') as total_api_calls,
  MIN(timestamp) as first_access,
  MAX(timestamp) as last_access,
  
  -- Calculate user segment based on activity
  CASE 
    WHEN COUNT(*) >= 100 THEN 'power_user'
    WHEN COUNT(*) >= 20 THEN 'regular_user'
    WHEN COUNT(*) >= 5 THEN 'occasional_user'
    ELSE 'new_user'
  END as user_segment,
  
  -- Preferred formats
  MODE() WITHIN GROUP (ORDER BY format) as preferred_format,
  
  -- Activity pattern
  MODE() WITHIN GROUP (ORDER BY EXTRACT(hour FROM timestamp)) as preferred_hour
  
FROM usage_analytics.dataset_usage_logs
WHERE user_id IS NOT NULL
  AND timestamp > NOW() - INTERVAL '90 days'
GROUP BY user_id
ORDER BY total_events DESC;

-- Functions for analytics API

-- Get usage summary
CREATE OR REPLACE FUNCTION usage_analytics.get_usage_summary(
  start_date TIMESTAMP WITH TIME ZONE,
  end_date TIMESTAMP WITH TIME ZONE
) RETURNS TABLE (
  total_datasets BIGINT,
  total_downloads_today BIGINT,
  total_api_calls_today BIGINT,
  active_users_today BIGINT,
  storage_used_gb NUMERIC,
  bandwidth_used_gb NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (SELECT COUNT(*) FROM usage_analytics.dataset_metadata WHERE is_active = true) as total_datasets,
    (SELECT COUNT(*) FROM usage_analytics.dataset_usage_logs 
     WHERE event_type = 'download' AND timestamp::date = CURRENT_DATE) as total_downloads_today,
    (SELECT COUNT(*) FROM usage_analytics.dataset_usage_logs 
     WHERE event_type = 'api_call' AND timestamp::date = CURRENT_DATE) as total_api_calls_today,
    (SELECT COUNT(DISTINCT user_id) FROM usage_analytics.dataset_usage_logs 
     WHERE timestamp::date = CURRENT_DATE) as active_users_today,
    (SELECT COALESCE(SUM(total_size_bytes), 0) / (1024^3)::numeric 
     FROM usage_analytics.dataset_metadata) as storage_used_gb,
    (SELECT COALESCE(SUM(file_size), 0) / (1024^3)::numeric 
     FROM usage_analytics.dataset_usage_logs 
     WHERE timestamp BETWEEN start_date AND end_date) as bandwidth_used_gb;
END;
$$ LANGUAGE plpgsql;

-- Get hourly usage pattern
CREATE OR REPLACE FUNCTION usage_analytics.get_hourly_usage_pattern(
  start_date TIMESTAMP WITH TIME ZONE,
  end_date TIMESTAMP WITH TIME ZONE
) RETURNS TABLE (
  hour INTEGER,
  usage BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    EXTRACT(hour FROM timestamp)::integer as hour,
    COUNT(*) as usage
  FROM usage_analytics.dataset_usage_logs
  WHERE timestamp BETWEEN start_date AND end_date
  GROUP BY EXTRACT(hour FROM timestamp)
  ORDER BY hour;
END;
$$ LANGUAGE plpgsql;

-- Get daily usage trends
CREATE OR REPLACE FUNCTION usage_analytics.get_daily_usage_trends(
  start_date TIMESTAMP WITH TIME ZONE,
  end_date TIMESTAMP WITH TIME ZONE
) RETURNS TABLE (
  date DATE,
  downloads BIGINT,
  api_calls BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    timestamp::date as date,
    COUNT(*) FILTER (WHERE event_type = 'download') as downloads,
    COUNT(*) FILTER (WHERE event_type = 'api_call') as api_calls
  FROM usage_analytics.dataset_usage_logs
  WHERE timestamp BETWEEN start_date AND end_date
  GROUP BY timestamp::date
  ORDER BY date;
END;
$$ LANGUAGE plpgsql;

-- Get format preferences
CREATE OR REPLACE FUNCTION usage_analytics.get_format_preferences(
  start_date TIMESTAMP WITH TIME ZONE,
  end_date TIMESTAMP WITH TIME ZONE
) RETURNS TABLE (
  format TEXT,
  percentage NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  WITH format_counts AS (
    SELECT 
      COALESCE(format, 'unknown') as format,
      COUNT(*) as count
    FROM usage_analytics.dataset_usage_logs
    WHERE timestamp BETWEEN start_date AND end_date
      AND format IS NOT NULL
    GROUP BY COALESCE(format, 'unknown')
  )
  SELECT 
    fc.format,
    (fc.count * 100.0 / SUM(fc.count) OVER ())::numeric(5,2) as percentage
  FROM format_counts fc
  ORDER BY percentage DESC;
END;
$$ LANGUAGE plpgsql;

-- Get user analytics
CREATE OR REPLACE FUNCTION usage_analytics.get_user_analytics(
  start_date TIMESTAMP WITH TIME ZONE,
  end_date TIMESTAMP WITH TIME ZONE
) RETURNS TABLE (
  new_users_today BIGINT,
  returning_users BIGINT,
  user_segments JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (SELECT COUNT(DISTINCT user_id) FROM usage_analytics.dataset_usage_logs 
     WHERE timestamp::date = CURRENT_DATE 
       AND user_id NOT IN (
         SELECT DISTINCT user_id FROM usage_analytics.dataset_usage_logs 
         WHERE timestamp::date < CURRENT_DATE
       )) as new_users_today,
    (SELECT COUNT(DISTINCT user_id) FROM usage_analytics.dataset_usage_logs 
     WHERE timestamp::date = CURRENT_DATE 
       AND user_id IN (
         SELECT DISTINCT user_id FROM usage_analytics.dataset_usage_logs 
         WHERE timestamp::date < CURRENT_DATE
       )) as returning_users,
    (SELECT jsonb_agg(jsonb_build_object('segment', user_segment, 'count', user_count))
     FROM (
       SELECT 
         user_segment,
         COUNT(*) as user_count
       FROM usage_analytics.user_behavior_analysis
       GROUP BY user_segment
     ) segments) as user_segments;
END;
$$ LANGUAGE plpgsql;

-- Get performance metrics
CREATE OR REPLACE FUNCTION usage_analytics.get_performance_metrics(
  start_date TIMESTAMP WITH TIME ZONE,
  end_date TIMESTAMP WITH TIME ZONE
) RETURNS TABLE (
  average_response_time NUMERIC,
  error_rate NUMERIC,
  cache_hit_rate NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(AVG(response_time_ms), 0)::numeric(10,2) as average_response_time,
    COALESCE((COUNT(*) FILTER (WHERE status_code >= 400) * 100.0 / NULLIF(COUNT(*), 0)), 0)::numeric(5,2) as error_rate,
    -- Cache hit rate would be calculated based on cache headers or separate tracking
    80.0 as cache_hit_rate  -- Placeholder value
  FROM usage_analytics.dataset_usage_logs
  WHERE timestamp BETWEEN start_date AND end_date;
END;
$$ LANGUAGE plpgsql;

-- Insert some sample datasets
INSERT INTO usage_analytics.dataset_metadata (dataset_name, category, description, created_date, total_size_bytes, record_count) VALUES
('daily_transactions', 'gold', 'Daily aggregated transaction data', '2025-01-01', 50*1024*1024, 10000),
('store_rankings', 'gold', 'Store performance rankings', '2025-01-01', 5*1024*1024, 500),
('hourly_patterns', 'gold', 'Hourly transaction patterns', '2025-01-01', 20*1024*1024, 5000),
('store_features', 'platinum', 'ML features for stores', '2025-01-01', 30*1024*1024, 1000),
('ml_predictions', 'platinum', 'Model predictions', '2025-01-01', 15*1024*1024, 2000),
('payment_trends', 'gold', 'Payment method trends', '2025-01-01', 10*1024*1024, 3000)
ON CONFLICT (dataset_name) DO NOTHING;

-- Grant permissions
GRANT USAGE ON SCHEMA usage_analytics TO authenticated, anon, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA usage_analytics TO authenticated, anon;
GRANT ALL ON ALL TABLES IN SCHEMA usage_analytics TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA usage_analytics TO authenticated, anon, service_role;

-- Row Level Security
ALTER TABLE usage_analytics.dataset_usage_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE usage_analytics.user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE usage_analytics.dataset_metadata ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view aggregated usage data" ON usage_analytics.dataset_usage_logs
  FOR SELECT USING (true); -- Allow reading aggregated data

CREATE POLICY "Service role can manage all usage data" ON usage_analytics.dataset_usage_logs
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Users can view dataset metadata" ON usage_analytics.dataset_metadata
  FOR SELECT USING (true);

CREATE POLICY "Service role can manage dataset metadata" ON usage_analytics.dataset_metadata
  FOR ALL USING (auth.role() = 'service_role');