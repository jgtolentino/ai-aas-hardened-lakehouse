-- =====================================================
-- MLOps Infrastructure for Scout Analytics Platform
-- Comprehensive monitoring, versioning, and observability
-- =====================================================

-- Create MLOps schema
CREATE SCHEMA IF NOT EXISTS mlops;

-- =====================================================
-- 1. MODEL PERFORMANCE MONITORING
-- =====================================================

-- Model performance metrics tracking
CREATE TABLE mlops.model_performance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  function_name TEXT NOT NULL,
  model_version TEXT NOT NULL,
  request_id TEXT UNIQUE NOT NULL,
  
  -- Performance metrics
  latency_ms INTEGER NOT NULL,
  success BOOLEAN NOT NULL DEFAULT true,
  confidence_score DECIMAL(3,2),
  
  -- Input/Output tracking
  input_tokens INTEGER,
  output_tokens INTEGER,
  query_length INTEGER,
  response_length INTEGER,
  
  -- Cost tracking
  estimated_cost_usd DECIMAL(10,4),
  
  -- Context
  user_id TEXT,
  session_id TEXT,
  error_message TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Indexes for fast queries
  CONSTRAINT valid_confidence CHECK (confidence_score >= 0 AND confidence_score <= 1)
);

-- Indexes for performance
CREATE INDEX idx_model_performance_function_time ON mlops.model_performance(function_name, created_at DESC);
CREATE INDEX idx_model_performance_success ON mlops.model_performance(success, created_at DESC);
CREATE INDEX idx_model_performance_latency ON mlops.model_performance(latency_ms) WHERE success = true;

-- =====================================================
-- 2. MODEL VERSIONING & EXPERIMENT TRACKING
-- =====================================================

-- Model versions registry
CREATE TABLE mlops.model_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  function_name TEXT NOT NULL,
  version TEXT NOT NULL,
  model_id TEXT NOT NULL, -- e.g., "gpt-4o-mini-2024-07-18"
  
  -- Configuration
  parameters JSONB NOT NULL, -- temperature, max_tokens, etc.
  prompt_template TEXT,
  
  -- Deployment info
  deployment_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  deployed_by TEXT,
  rollback_version TEXT,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'deprecated', 'rollback')),
  
  -- Performance benchmarks
  benchmark_latency_p95 INTEGER,
  benchmark_accuracy DECIMAL(5,2),
  benchmark_cost_per_request DECIMAL(8,4),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(function_name, version)
);

-- A/B Testing experiments
CREATE TABLE mlops.experiments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  experiment_id TEXT UNIQUE NOT NULL,
  function_name TEXT NOT NULL,
  
  -- Experiment setup
  hypothesis TEXT NOT NULL,
  control_version TEXT NOT NULL,
  treatment_version TEXT NOT NULL,
  traffic_split DECIMAL(3,2) DEFAULT 0.50, -- % traffic to treatment
  
  -- Status and timeline
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'running', 'paused', 'completed', 'cancelled')),
  start_date TIMESTAMP WITH TIME ZONE,
  end_date TIMESTAMP WITH TIME ZONE,
  target_sample_size INTEGER DEFAULT 1000,
  
  -- Success metrics
  primary_metric TEXT NOT NULL, -- 'latency', 'accuracy', 'user_satisfaction'
  success_criteria JSONB, -- {"metric": "latency_p95", "improvement": 0.1}
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by TEXT
);

-- Experiment assignments
CREATE TABLE mlops.experiment_assignments (
  experiment_id TEXT REFERENCES mlops.experiments(experiment_id),
  user_id TEXT NOT NULL,
  variant TEXT NOT NULL CHECK (variant IN ('control', 'treatment')),
  assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  PRIMARY KEY (experiment_id, user_id)
);

-- =====================================================
-- 3. FEATURE STORE
-- =====================================================

-- Feature definitions
CREATE TABLE mlops.feature_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feature_name TEXT UNIQUE NOT NULL,
  feature_type TEXT NOT NULL CHECK (feature_type IN ('embedding', 'aggregate', 'categorical', 'numerical')),
  
  -- Source and computation
  source_table TEXT NOT NULL,
  transformation_sql TEXT NOT NULL,
  refresh_frequency TEXT DEFAULT 'daily', -- 'realtime', 'hourly', 'daily', 'weekly'
  
  -- Metadata
  description TEXT,
  owner TEXT,
  version INTEGER DEFAULT 1,
  
  -- Data quality
  expected_range JSONB, -- {"min": 0, "max": 1}
  null_tolerance DECIMAL(3,2) DEFAULT 0.05,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Feature values (time-series)
CREATE TABLE mlops.feature_values (
  feature_id UUID REFERENCES mlops.feature_definitions(id),
  entity_id TEXT NOT NULL,
  feature_value JSONB NOT NULL,
  
  -- Metadata
  computed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  data_version TEXT,
  quality_score DECIMAL(3,2), -- 0-1 quality assessment
  
  PRIMARY KEY (feature_id, entity_id, computed_at)
);

-- Partition by month for performance
SELECT create_monthly_partitions('mlops.feature_values', 'computed_at', '2025-01-01'::date, '2026-12-31'::date);

-- =====================================================
-- 4. DATA DRIFT DETECTION
-- =====================================================

-- Data drift monitoring
CREATE TABLE mlops.drift_detection (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feature_name TEXT NOT NULL,
  detection_type TEXT NOT NULL CHECK (detection_type IN ('statistical', 'embedding', 'distribution')),
  
  -- Drift metrics
  drift_score DECIMAL(8,4) NOT NULL,
  p_value DECIMAL(8,4),
  threshold DECIMAL(8,4) DEFAULT 0.05,
  drift_detected BOOLEAN GENERATED ALWAYS AS (drift_score > threshold) STORED,
  
  -- Reference and current data
  reference_period_start TIMESTAMP WITH TIME ZONE NOT NULL,
  reference_period_end TIMESTAMP WITH TIME ZONE NOT NULL,
  current_period_start TIMESTAMP WITH TIME ZONE NOT NULL,
  current_period_end TIMESTAMP WITH TIME ZONE NOT NULL,
  
  -- Additional metrics
  sample_size_reference INTEGER,
  sample_size_current INTEGER,
  drift_details JSONB, -- distribution changes, top drift features
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 5. COST TRACKING & OPTIMIZATION
-- =====================================================

-- Detailed cost tracking
CREATE TABLE mlops.cost_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  function_name TEXT NOT NULL,
  model_version TEXT NOT NULL,
  
  -- Token usage
  prompt_tokens INTEGER NOT NULL DEFAULT 0,
  completion_tokens INTEGER NOT NULL DEFAULT 0,
  total_tokens GENERATED ALWAYS AS (prompt_tokens + completion_tokens) STORED,
  
  -- Costs (in USD)
  prompt_cost DECIMAL(10,4) NOT NULL DEFAULT 0,
  completion_cost DECIMAL(10,4) NOT NULL DEFAULT 0,
  total_cost GENERATED ALWAYS AS (prompt_cost + completion_cost) STORED,
  
  -- Context
  request_id TEXT,
  user_id TEXT,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Rate limiting
  rate_limit_hit BOOLEAN DEFAULT FALSE
);

-- Daily cost aggregates for reporting
CREATE TABLE mlops.daily_cost_summary (
  date DATE NOT NULL,
  function_name TEXT NOT NULL,
  
  -- Aggregates
  total_requests INTEGER NOT NULL DEFAULT 0,
  total_tokens INTEGER NOT NULL DEFAULT 0,
  total_cost DECIMAL(10,2) NOT NULL DEFAULT 0,
  avg_cost_per_request DECIMAL(10,4) NOT NULL DEFAULT 0,
  
  -- Performance
  avg_latency_ms INTEGER,
  p95_latency_ms INTEGER,
  success_rate DECIMAL(5,2),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  PRIMARY KEY (date, function_name)
);

-- =====================================================
-- 6. ALERTING & NOTIFICATIONS
-- =====================================================

-- Alert rules configuration
CREATE TABLE mlops.alert_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_name TEXT UNIQUE NOT NULL,
  function_name TEXT, -- NULL for global rules
  
  -- Alert conditions
  metric_name TEXT NOT NULL, -- 'latency_p95', 'error_rate', 'cost_daily'
  condition_type TEXT NOT NULL CHECK (condition_type IN ('threshold', 'change_rate', 'anomaly')),
  threshold_value DECIMAL(10,4),
  comparison_operator TEXT CHECK (comparison_operator IN ('>', '<', '>=', '<=', '=', '!=')),
  
  -- Time windows
  evaluation_window_minutes INTEGER DEFAULT 5,
  cooldown_minutes INTEGER DEFAULT 60,
  
  -- Notification settings
  severity TEXT DEFAULT 'medium' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  notification_channels TEXT[] DEFAULT ARRAY['email'], -- 'email', 'slack', 'webhook'
  recipients TEXT[],
  
  -- Status
  enabled BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Alert instances (fired alerts)
CREATE TABLE mlops.alert_instances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_id UUID REFERENCES mlops.alert_rules(id),
  
  -- Alert details
  alert_message TEXT NOT NULL,
  severity TEXT NOT NULL,
  metric_value DECIMAL(10,4),
  threshold_value DECIMAL(10,4),
  
  -- Timeline
  fired_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  acknowledged_at TIMESTAMP WITH TIME ZONE,
  resolved_at TIMESTAMP WITH TIME ZONE,
  acknowledged_by TEXT,
  
  -- Context
  function_name TEXT,
  additional_context JSONB
);

-- =====================================================
-- 7. MODEL GOVERNANCE & COMPLIANCE
-- =====================================================

-- Model approval workflow
CREATE TABLE mlops.model_approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  function_name TEXT NOT NULL,
  version TEXT NOT NULL,
  
  -- Approval process
  approval_status TEXT DEFAULT 'pending' CHECK (approval_status IN ('pending', 'approved', 'rejected', 'conditional')),
  requested_by TEXT NOT NULL,
  approved_by TEXT,
  
  -- Review criteria
  performance_review_passed BOOLEAN DEFAULT FALSE,
  security_review_passed BOOLEAN DEFAULT FALSE,
  cost_review_passed BOOLEAN DEFAULT FALSE,
  bias_review_passed BOOLEAN DEFAULT FALSE,
  
  -- Comments and conditions
  review_comments TEXT,
  conditions TEXT,
  
  -- Timeline
  requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  reviewed_at TIMESTAMP WITH TIME ZONE,
  
  FOREIGN KEY (function_name, version) REFERENCES mlops.model_versions(function_name, version)
);

-- =====================================================
-- 8. VIEWS FOR MONITORING DASHBOARDS
-- =====================================================

-- Real-time performance dashboard
CREATE VIEW mlops.performance_dashboard AS
SELECT 
  function_name,
  model_version,
  
  -- Last 24 hours metrics
  COUNT(*) as requests_24h,
  AVG(latency_ms) as avg_latency_ms,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY latency_ms) as p95_latency_ms,
  (COUNT(*) FILTER (WHERE success = true))::decimal / COUNT(*) * 100 as success_rate,
  AVG(confidence_score) as avg_confidence,
  
  -- Cost metrics
  SUM(estimated_cost_usd) as cost_24h,
  AVG(estimated_cost_usd) as avg_cost_per_request,
  
  -- Recent activity
  MAX(created_at) as last_request_time,
  
  -- Error analysis
  COUNT(*) FILTER (WHERE success = false) as error_count,
  string_agg(DISTINCT error_message, '; ') as recent_errors
  
FROM mlops.model_performance 
WHERE created_at >= NOW() - INTERVAL '24 hours'
GROUP BY function_name, model_version;

-- Cost analysis view
CREATE VIEW mlops.cost_analysis AS
SELECT 
  function_name,
  DATE(timestamp) as date,
  
  -- Daily aggregates
  SUM(total_cost) as daily_cost,
  COUNT(*) as daily_requests,
  SUM(total_tokens) as daily_tokens,
  AVG(total_cost) as avg_cost_per_request,
  
  -- Running totals
  SUM(SUM(total_cost)) OVER (PARTITION BY function_name ORDER BY DATE(timestamp)) as cumulative_cost,
  
  -- Efficiency metrics
  SUM(total_tokens)::decimal / COUNT(*) as avg_tokens_per_request,
  SUM(total_cost)::decimal / SUM(total_tokens) * 1000 as cost_per_1k_tokens
  
FROM mlops.cost_tracking 
GROUP BY function_name, DATE(timestamp);

-- Experiment performance view
CREATE VIEW mlops.experiment_results AS
SELECT 
  e.experiment_id,
  e.function_name,
  e.primary_metric,
  e.status,
  
  -- Assignment counts
  COUNT(ea.user_id) as total_users,
  COUNT(ea.user_id) FILTER (WHERE ea.variant = 'control') as control_users,
  COUNT(ea.user_id) FILTER (WHERE ea.variant = 'treatment') as treatment_users,
  
  -- Performance comparison (from model_performance table)
  AVG(mp.latency_ms) FILTER (WHERE ea.variant = 'control') as control_avg_latency,
  AVG(mp.latency_ms) FILTER (WHERE ea.variant = 'treatment') as treatment_avg_latency,
  AVG(mp.confidence_score) FILTER (WHERE ea.variant = 'control') as control_avg_confidence,
  AVG(mp.confidence_score) FILTER (WHERE ea.variant = 'treatment') as treatment_avg_confidence,
  
  -- Statistical significance (basic)
  COUNT(*) FILTER (WHERE mp.success = true AND ea.variant = 'control') as control_successes,
  COUNT(*) FILTER (WHERE mp.success = true AND ea.variant = 'treatment') as treatment_successes
  
FROM mlops.experiments e
LEFT JOIN mlops.experiment_assignments ea ON e.experiment_id = ea.experiment_id
LEFT JOIN mlops.model_performance mp ON mp.user_id = ea.user_id 
  AND mp.function_name = e.function_name
  AND mp.created_at >= e.start_date
GROUP BY e.experiment_id, e.function_name, e.primary_metric, e.status;

-- =====================================================
-- 9. FUNCTIONS FOR AUTOMATION
-- =====================================================

-- Function to log model performance
CREATE OR REPLACE FUNCTION mlops.log_model_performance(
  p_function_name TEXT,
  p_model_version TEXT,
  p_request_id TEXT,
  p_latency_ms INTEGER,
  p_success BOOLEAN,
  p_confidence_score DECIMAL DEFAULT NULL,
  p_input_tokens INTEGER DEFAULT NULL,
  p_output_tokens INTEGER DEFAULT NULL,
  p_estimated_cost DECIMAL DEFAULT NULL,
  p_user_id TEXT DEFAULT NULL,
  p_error_message TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  record_id UUID;
BEGIN
  INSERT INTO mlops.model_performance (
    function_name, model_version, request_id, latency_ms, success,
    confidence_score, input_tokens, output_tokens, estimated_cost_usd,
    user_id, error_message
  ) VALUES (
    p_function_name, p_model_version, p_request_id, p_latency_ms, p_success,
    p_confidence_score, p_input_tokens, p_output_tokens, p_estimated_cost,
    p_user_id, p_error_message
  ) RETURNING id INTO record_id;
  
  RETURN record_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get experiment assignment
CREATE OR REPLACE FUNCTION mlops.get_experiment_assignment(
  p_experiment_id TEXT,
  p_user_id TEXT
) RETURNS TEXT AS $$
DECLARE
  assignment TEXT;
  experiment_active BOOLEAN;
  traffic_split DECIMAL;
  user_hash BIGINT;
BEGIN
  -- Check if experiment is active
  SELECT 
    status = 'running' AND 
    start_date <= NOW() AND 
    (end_date IS NULL OR end_date > NOW()),
    experiments.traffic_split
  INTO experiment_active, traffic_split
  FROM mlops.experiments 
  WHERE experiment_id = p_experiment_id;
  
  IF NOT experiment_active THEN
    RETURN 'control'; -- Default to control if experiment not active
  END IF;
  
  -- Check existing assignment
  SELECT variant INTO assignment
  FROM mlops.experiment_assignments
  WHERE experiment_id = p_experiment_id AND user_id = p_user_id;
  
  IF assignment IS NOT NULL THEN
    RETURN assignment;
  END IF;
  
  -- Create new assignment based on hash
  SELECT ('x' || substr(md5(p_user_id || p_experiment_id), 1, 16))::bit(64)::bigint INTO user_hash;
  
  IF (user_hash % 100)::decimal / 100 < traffic_split THEN
    assignment := 'treatment';
  ELSE
    assignment := 'control';
  END IF;
  
  -- Store assignment
  INSERT INTO mlops.experiment_assignments (experiment_id, user_id, variant)
  VALUES (p_experiment_id, p_user_id, assignment);
  
  RETURN assignment;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to detect data drift (placeholder for statistical tests)
CREATE OR REPLACE FUNCTION mlops.detect_drift(
  p_feature_name TEXT,
  p_reference_start TIMESTAMP,
  p_reference_end TIMESTAMP,
  p_current_start TIMESTAMP,
  p_current_end TIMESTAMP
) RETURNS DECIMAL AS $$
DECLARE
  drift_score DECIMAL;
  -- This is a simplified example - real implementation would use proper statistical tests
BEGIN
  -- Placeholder: In reality, you'd implement KS test, Chi-square, etc.
  -- For now, return a random drift score between 0 and 1
  SELECT RANDOM() INTO drift_score;
  
  -- Log the drift detection
  INSERT INTO mlops.drift_detection (
    feature_name, detection_type, drift_score,
    reference_period_start, reference_period_end,
    current_period_start, current_period_end
  ) VALUES (
    p_feature_name, 'statistical', drift_score,
    p_reference_start, p_reference_end,
    p_current_start, p_current_end
  );
  
  RETURN drift_score;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 10. ROW LEVEL SECURITY
-- =====================================================

-- Enable RLS on sensitive tables
ALTER TABLE mlops.model_performance ENABLE ROW LEVEL SECURITY;
ALTER TABLE mlops.cost_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE mlops.experiments ENABLE ROW LEVEL SECURITY;

-- Allow ML engineers and admins to see everything
CREATE POLICY mlops_admin_access ON mlops.model_performance
  FOR ALL USING (auth.jwt() ->> 'role' IN ('ml_engineer', 'admin', 'service_role'));

CREATE POLICY mlops_cost_admin_access ON mlops.cost_tracking
  FOR ALL USING (auth.jwt() ->> 'role' IN ('ml_engineer', 'admin', 'finance', 'service_role'));

-- Experiments can be viewed by their creators and admins
CREATE POLICY mlops_experiment_access ON mlops.experiments
  FOR ALL USING (
    auth.jwt() ->> 'role' IN ('admin', 'service_role') OR 
    created_by = auth.jwt() ->> 'email'
  );

-- =====================================================
-- INITIAL DATA SETUP
-- =====================================================

-- Insert current model versions
INSERT INTO mlops.model_versions (function_name, version, model_id, parameters) VALUES
('ai-generate-insight', 'v1.0', 'gpt-4o-mini', '{"temperature": 0.3, "max_tokens": 1500}'),
('semantic-calc', 'v1.0', 'gpt-4o-mini', '{"temperature": 0.1, "max_tokens": 1000}'),
('semantic-suggest', 'v1.0', 'text-embedding-3-small', '{"dimensions": 1536}'),
('semantic-proxy', 'v1.0', 'gpt-4o-mini', '{"temperature": 0.2, "max_tokens": 800}'),
('process-documents', 'v1.0', 'text-embedding-3-small', '{"chunk_size": 1000}'),
('export-platinum', 'v1.0', 'internal', '{}'),
('ingest-bronze', 'v1.0', 'internal', '{}');

-- Insert default alert rules
INSERT INTO mlops.alert_rules (rule_name, metric_name, condition_type, threshold_value, comparison_operator) VALUES
('High Latency Alert', 'latency_p95', 'threshold', 5000, '>'),
('High Error Rate Alert', 'error_rate', 'threshold', 5, '>'),
('Daily Cost Alert', 'cost_daily', 'threshold', 100, '>'),
('Low Success Rate Alert', 'success_rate', 'threshold', 95, '<');

-- Create indexes for performance
CREATE INDEX CONCURRENTLY idx_model_perf_created_at ON mlops.model_performance(created_at DESC);
CREATE INDEX CONCURRENTLY idx_cost_tracking_timestamp ON mlops.cost_tracking(timestamp DESC);
CREATE INDEX CONCURRENTLY idx_feature_values_computed_at ON mlops.feature_values(computed_at DESC);

COMMENT ON SCHEMA mlops IS 'MLOps infrastructure for model lifecycle management, monitoring, and governance';
COMMENT ON TABLE mlops.model_performance IS 'Tracks performance metrics for all ML models in production';
COMMENT ON TABLE mlops.experiments IS 'A/B testing framework for model experiments';
COMMENT ON TABLE mlops.feature_definitions IS 'Feature store for ML feature management';
COMMENT ON TABLE mlops.cost_tracking IS 'Detailed cost tracking for AI model usage';