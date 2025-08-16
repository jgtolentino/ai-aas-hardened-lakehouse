-- QA Browser-Use Results Tables
-- Track automated test runs and findings

-- Test run results
CREATE TABLE IF NOT EXISTS scout.qa_runs (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  flow_id TEXT NOT NULL,
  browser TEXT NOT NULL,
  status TEXT CHECK (status IN ('passed','failed')) NOT NULL,
  logs JSONB NOT NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- QA findings/issues
CREATE TABLE IF NOT EXISTS scout.qa_findings (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  run_id BIGINT REFERENCES scout.qa_runs(id) ON DELETE CASCADE,
  severity TEXT CHECK (severity IN ('low','medium','high')) NOT NULL,
  title TEXT NOT NULL,
  details JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_qa_runs_flow_id ON scout.qa_runs(flow_id);
CREATE INDEX idx_qa_runs_status ON scout.qa_runs(status);
CREATE INDEX idx_qa_runs_started_at ON scout.qa_runs(started_at DESC);
CREATE INDEX idx_qa_findings_run_id ON scout.qa_findings(run_id);
CREATE INDEX idx_qa_findings_severity ON scout.qa_findings(severity);

-- View for QA dashboard
CREATE OR REPLACE VIEW scout.vw_qa_summary AS
SELECT 
  flow_id,
  browser,
  COUNT(*) as total_runs,
  SUM(CASE WHEN status = 'passed' THEN 1 ELSE 0 END) as passed,
  SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed,
  ROUND(100.0 * SUM(CASE WHEN status = 'passed' THEN 1 ELSE 0 END) / COUNT(*), 2) as pass_rate,
  MAX(started_at) as last_run
FROM scout.qa_runs
GROUP BY flow_id, browser;

-- View for recent failures
CREATE OR REPLACE VIEW scout.vw_qa_recent_failures AS
SELECT 
  r.flow_id,
  r.browser,
  r.started_at,
  r.logs,
  COUNT(f.id) as finding_count
FROM scout.qa_runs r
LEFT JOIN scout.qa_findings f ON f.run_id = r.id
WHERE r.status = 'failed'
  AND r.started_at > NOW() - INTERVAL '7 days'
GROUP BY r.id, r.flow_id, r.browser, r.started_at, r.logs
ORDER BY r.started_at DESC
LIMIT 50;