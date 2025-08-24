-- ===========================================================
-- Scout v5.2 — AI Reasoning Tracking & Monitoring System
-- ===========================================================

-- 1. REASONING CHAIN TRACKING
-- Tracks the entire reasoning process for each AI decision
create table if not exists scout.ai_reasoning_chains(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  
  -- Request context
  request_type text not null, -- 'nl_to_sql', 'transaction_inference', 'recommendation'
  request_id uuid not null, -- Links to original request
  user_id text,
  
  -- Reasoning steps
  reasoning_steps jsonb[] not null default '{}', -- Array of step objects
  final_output jsonb not null,
  
  -- Performance metrics
  total_duration_ms int not null,
  model_used text not null, -- 'claude-3-sonnet', 'gpt-4', 'rules-engine'
  token_count int,
  
  -- Quality metrics
  confidence_score decimal(3,2) not null check (confidence_score between 0 and 1),
  uncertainty_factors text[],
  assumptions_made text[],
  
  -- Validation
  was_validated boolean default false,
  validation_method text, -- 'human', 'automated', 'outcome-based'
  validation_score decimal(3,2),
  
  -- Chain metadata
  parent_chain_id uuid references scout.ai_reasoning_chains(id),
  chain_depth int default 1
);

-- Example reasoning step structure:
-- {
--   "step_number": 1,
--   "step_type": "context_analysis",
--   "input": "₱20 payment, ₱3 change",
--   "reasoning": "Total spent = 20 - 3 = 17. Need to find product combinations.",
--   "output": {"total_spent": 17},
--   "confidence": 1.0,
--   "duration_ms": 45
-- }

create index idx_reasoning_chains_created on scout.ai_reasoning_chains(created_at desc);
create index idx_reasoning_chains_type on scout.ai_reasoning_chains(request_type);
create index idx_reasoning_chains_confidence on scout.ai_reasoning_chains(confidence_score);

-- 2. MODEL PERFORMANCE METRICS
-- Tracks performance of each AI model over time
create table if not exists scout.ai_model_performance(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  
  -- Model identification
  model_name text not null,
  model_version text not null,
  endpoint text not null, -- 'openai', 'anthropic', 'local'
  
  -- Performance window
  window_start timestamptz not null,
  window_end timestamptz not null,
  request_count int not null,
  
  -- Latency metrics (milliseconds)
  latency_p50 int not null,
  latency_p95 int not null,
  latency_p99 int not null,
  latency_mean int not null,
  
  -- Accuracy metrics
  accuracy_score decimal(3,2), -- Based on validation
  precision_score decimal(3,2),
  recall_score decimal(3,2),
  f1_score decimal(3,2),
  
  -- Error tracking
  error_count int not null default 0,
  error_rate decimal(4,3),
  common_errors jsonb default '[]',
  
  -- Cost metrics
  total_tokens_used bigint,
  total_cost_usd decimal(10,4),
  cost_per_request decimal(8,4),
  
  -- Quality metrics
  avg_confidence_score decimal(3,2),
  low_confidence_rate decimal(4,3), -- % of requests < 0.75 confidence
  fallback_rate decimal(4,3), -- % requiring fallback to another model
  
  unique(model_name, model_version, window_start)
);

-- 3. CONFIDENCE CALIBRATION
-- Tracks predicted vs actual confidence to detect miscalibration
create table if not exists scout.ai_confidence_calibration(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  
  -- Prediction details
  reasoning_chain_id uuid references scout.ai_reasoning_chains(id),
  predicted_confidence decimal(3,2) not null,
  confidence_bucket text not null, -- '0.0-0.1', '0.1-0.2', etc.
  
  -- Actual outcome
  outcome_known boolean default false,
  outcome_correct boolean,
  outcome_score decimal(3,2), -- Partial correctness
  outcome_verified_at timestamptz,
  verification_method text,
  
  -- Calibration metrics
  calibration_error decimal(4,3), -- |predicted - actual|
  is_overconfident boolean,
  is_underconfident boolean
);

create index idx_confidence_calibration_bucket on scout.ai_confidence_calibration(confidence_bucket);
create index idx_confidence_calibration_outcome on scout.ai_confidence_calibration(outcome_known) where outcome_known = true;

-- 4. MODEL DRIFT DETECTION
-- Monitors for changes in model behavior over time
create table if not exists scout.ai_model_drift(
  id uuid primary key default gen_random_uuid(),
  detected_at timestamptz not null default now(),
  
  -- Drift identification
  model_name text not null,
  drift_type text not null, -- 'performance', 'distribution', 'concept'
  severity text not null check (severity in ('low', 'medium', 'high', 'critical')),
  
  -- Drift metrics
  baseline_window jsonb not null, -- {"start": "2024-01-01", "end": "2024-01-31"}
  current_window jsonb not null,
  
  -- Statistical measures
  drift_score decimal(5,4) not null, -- 0-1, higher = more drift
  statistical_test text, -- 'ks_test', 'chi_square', 'psi'
  p_value decimal(6,5),
  
  -- Specific changes detected
  metric_changes jsonb not null, -- {"accuracy": {"before": 0.95, "after": 0.87}}
  distribution_changes jsonb,
  
  -- Response
  auto_mitigated boolean default false,
  mitigation_action text,
  human_review_required boolean default true,
  reviewed_by text,
  reviewed_at timestamptz
);

-- 5. FEEDBACK LOOP SYSTEM
-- Captures and processes user feedback on AI outputs
create table if not exists scout.ai_feedback(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  
  -- Feedback source
  reasoning_chain_id uuid references scout.ai_reasoning_chains(id),
  user_id text,
  feedback_type text not null, -- 'explicit', 'implicit', 'outcome-based'
  
  -- Feedback content
  is_positive boolean not null,
  rating int check (rating between 1 and 5),
  feedback_text text,
  corrections jsonb, -- User-provided corrections
  
  -- Learning signals
  should_retrain boolean default false,
  improvement_category text, -- 'accuracy', 'relevance', 'completeness'
  specific_issue text,
  
  -- Processing
  processed boolean default false,
  processed_at timestamptz,
  incorporated_into_model text, -- Model version that incorporated this feedback
  impact_score decimal(3,2) -- How much this feedback influenced the model
);

create index idx_ai_feedback_unprocessed on scout.ai_feedback(processed) where processed = false;
create index idx_ai_feedback_should_retrain on scout.ai_feedback(should_retrain) where should_retrain = true;

-- 6. A/B TESTING FRAMEWORK
-- For testing different models/prompts/strategies
create table if not exists scout.ai_experiments(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  
  -- Experiment setup
  experiment_name text not null unique,
  experiment_type text not null, -- 'model', 'prompt', 'strategy'
  status text not null default 'active' check (status in ('planning', 'active', 'completed', 'aborted')),
  
  -- Variants
  control_config jsonb not null,
  treatment_configs jsonb[] not null, -- Array of variant configs
  
  -- Assignment
  assignment_method text not null default 'random', -- 'random', 'deterministic', 'contextual'
  traffic_allocation jsonb not null, -- {"control": 0.5, "treatment_a": 0.25, "treatment_b": 0.25}
  
  -- Schedule
  start_time timestamptz not null,
  end_time timestamptz,
  
  -- Success metrics
  primary_metric text not null, -- 'accuracy', 'confidence', 'user_satisfaction'
  secondary_metrics text[],
  minimum_sample_size int not null default 1000,
  
  -- Results
  results jsonb,
  winner text,
  statistical_significance decimal(4,3),
  recommendation text
);

-- 7. REASONING EXPLANATION GENERATION
-- Stores human-readable explanations of AI reasoning
create table if not exists scout.ai_explanations(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  
  reasoning_chain_id uuid references scout.ai_reasoning_chains(id),
  
  -- Explanation levels
  summary text not null, -- One-line summary
  detailed_explanation text not null, -- Full reasoning
  technical_details jsonb, -- For developers
  
  -- Explanation quality
  clarity_score decimal(3,2), -- From user feedback
  completeness_score decimal(3,2),
  accuracy_score decimal(3,2),
  
  -- Usage tracking
  shown_to_users int default 0,
  helpful_votes int default 0,
  unhelpful_votes int default 0
);

-- 8. CONTINUOUS LEARNING PIPELINE
-- Tracks model improvements over time
create table if not exists scout.ai_model_versions(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  
  -- Version info
  model_name text not null,
  version_number text not null,
  parent_version text,
  
  -- Training details
  training_data_snapshot text, -- Reference to training data version
  training_completed_at timestamptz,
  training_metrics jsonb,
  
  -- Improvements
  improvements_from_parent jsonb, -- What changed
  feedback_incorporated int, -- Number of feedback items used
  
  -- Deployment
  deployed_at timestamptz,
  deployment_status text,
  rollback_version text,
  
  -- Performance vs parent
  performance_delta jsonb, -- {"accuracy": +0.03, "latency": -50}
  
  unique(model_name, version_number)
);

-- 9. ANOMALY DETECTION FOR AI BEHAVIOR
-- Detects unusual AI outputs or behaviors
create table if not exists scout.ai_anomalies(
  id uuid primary key default gen_random_uuid(),
  detected_at timestamptz not null default now(),
  
  -- Anomaly identification
  reasoning_chain_id uuid references scout.ai_reasoning_chains(id),
  anomaly_type text not null, -- 'output', 'latency', 'confidence', 'pattern'
  severity text not null check (severity in ('low', 'medium', 'high', 'critical')),
  
  -- Detection details
  detection_method text not null, -- 'statistical', 'rule-based', 'ml-based'
  anomaly_score decimal(5,4) not null,
  expected_value jsonb,
  actual_value jsonb,
  
  -- Context
  contributing_factors text[],
  similar_anomalies int default 0,
  
  -- Resolution
  auto_handled boolean default false,
  handling_action text,
  requires_investigation boolean default true,
  investigated_by text,
  investigation_notes text,
  root_cause text
);

-- 10. REAL-TIME MONITORING VIEWS
-- Materialized views for dashboards

create materialized view scout.ai_monitoring_summary as
with recent_window as (
  select current_timestamp - interval '1 hour' as start_time
),
model_stats as (
  select
    model_used,
    count(*) as request_count,
    avg(confidence_score) as avg_confidence,
    avg(total_duration_ms) as avg_latency,
    count(case when confidence_score < 0.75 then 1 end)::decimal / count(*) as low_confidence_rate
  from scout.ai_reasoning_chains
  cross join recent_window
  where created_at >= recent_window.start_time
  group by model_used
),
feedback_stats as (
  select
    count(*) as feedback_count,
    avg(case when is_positive then 1 else 0 end) as satisfaction_rate,
    count(case when should_retrain then 1 end) as retraining_signals
  from scout.ai_feedback
  cross join recent_window
  where created_at >= recent_window.start_time
),
anomaly_stats as (
  select
    count(*) as anomaly_count,
    count(case when severity in ('high', 'critical') then 1 end) as critical_anomalies
  from scout.ai_anomalies
  cross join recent_window
  where detected_at >= recent_window.start_time
)
select
  current_timestamp as snapshot_time,
  (select jsonb_agg(row_to_json(model_stats.*)) from model_stats) as model_performance,
  (select row_to_json(feedback_stats.*) from feedback_stats) as feedback_metrics,
  (select row_to_json(anomaly_stats.*) from anomaly_stats) as anomaly_metrics;

-- Refresh function
create or replace function scout.refresh_ai_monitoring()
returns void
language sql
security definer
as $$
  refresh materialized view scout.ai_monitoring_summary;
$$;

-- Indexes for performance
create index idx_ai_reasoning_validation on scout.ai_reasoning_chains(was_validated) where was_validated = false;
create index idx_model_performance_window on scout.ai_model_performance(window_start desc);
create index idx_model_drift_severity on scout.ai_model_drift(severity, detected_at desc);
create index idx_experiments_active on scout.ai_experiments(status) where status = 'active';

-- RLS policies
alter table scout.ai_reasoning_chains enable row level security;
alter table scout.ai_model_performance enable row level security;
alter table scout.ai_feedback enable row level security;

-- Read access for authenticated users
create policy ai_reasoning_read on scout.ai_reasoning_chains
  for select using (true);

create policy ai_performance_read on scout.ai_model_performance
  for select using (true);

create policy ai_feedback_write on scout.ai_feedback
  for insert using (auth.uid() is not null);

-- Grant permissions
grant select on all tables in schema scout to authenticated;
grant execute on function scout.refresh_ai_monitoring() to authenticated;