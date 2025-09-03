-- ============================================================================
-- Agent Trace Metrics System
-- Comprehensive tracking for agentic analytics performance and evaluation
-- ============================================================================

-- Create agentdash schema for agent-specific analytics
CREATE SCHEMA IF NOT EXISTS agentdash;

-- Agent trace metrics table - core tracking for all agent activities
CREATE TABLE IF NOT EXISTS agentdash.agent_trace_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent TEXT NOT NULL,
    task TEXT NOT NULL,
    metric TEXT NOT NULL,
    score NUMERIC(5,2) CHECK (score BETWEEN 0 AND 100),
    execution_time_ms INTEGER DEFAULT 0,
    tool_calls JSONB DEFAULT '[]'::jsonb,
    error_count INTEGER DEFAULT 0,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    session_id UUID,
    trace_id UUID NOT NULL DEFAULT gen_random_uuid(),
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Ensure data integrity
    CONSTRAINT valid_agent_name CHECK (LENGTH(agent) > 0),
    CONSTRAINT valid_task_name CHECK (LENGTH(task) > 0),
    CONSTRAINT valid_metric_name CHECK (LENGTH(metric) > 0)
);

-- Agent definitions table - configuration and capabilities
CREATE TABLE IF NOT EXISTS agentdash.agent_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    version TEXT NOT NULL DEFAULT '1.0.0',
    routes TEXT[] DEFAULT ARRAY[]::TEXT[],
    capabilities TEXT[] DEFAULT ARRAY[]::TEXT[],
    metrics TEXT[] DEFAULT ARRAY[]::TEXT[],
    dependencies TEXT[] DEFAULT ARRAY[]::TEXT[],
    config JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Agent performance aggregation table
CREATE TABLE IF NOT EXISTS agentdash.agent_performance_summary (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent TEXT NOT NULL,
    task TEXT NOT NULL,
    metric TEXT NOT NULL,
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,
    avg_score NUMERIC(5,2),
    min_score NUMERIC(5,2),
    max_score NUMERIC(5,2),
    execution_count INTEGER DEFAULT 0,
    success_rate NUMERIC(5,2),
    avg_execution_time_ms INTEGER,
    total_errors INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(agent, task, metric, period_start, period_end)
);

-- Task execution sessions table
CREATE TABLE IF NOT EXISTS agentdash.agent_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL UNIQUE,
    agent TEXT NOT NULL,
    task_type TEXT NOT NULL,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    status TEXT DEFAULT 'running' CHECK (status IN ('running', 'completed', 'failed', 'timeout')),
    total_steps INTEGER DEFAULT 0,
    successful_steps INTEGER DEFAULT 0,
    failed_steps INTEGER DEFAULT 0,
    final_result JSONB,
    error_message TEXT,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Knowledge graph entities table for agent interactions
CREATE TABLE IF NOT EXISTS agentdash.knowledge_entities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type TEXT NOT NULL CHECK (entity_type IN ('Agent', 'Metric', 'Brand', 'Benchmark', 'Tool', 'Task')),
    entity_id TEXT NOT NULL,
    name TEXT NOT NULL,
    properties JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(entity_type, entity_id)
);

-- Knowledge graph relationships table
CREATE TABLE IF NOT EXISTS agentdash.knowledge_relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_entity_type TEXT NOT NULL,
    from_entity_id TEXT NOT NULL,
    relationship_type TEXT NOT NULL,
    to_entity_type TEXT NOT NULL,
    to_entity_id TEXT NOT NULL,
    properties JSONB DEFAULT '{}'::jsonb,
    strength NUMERIC(3,2) DEFAULT 1.0 CHECK (strength BETWEEN 0 AND 1),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Foreign key constraints to entities
    FOREIGN KEY (from_entity_type, from_entity_id) REFERENCES agentdash.knowledge_entities(entity_type, entity_id),
    FOREIGN KEY (to_entity_type, to_entity_id) REFERENCES agentdash.knowledge_entities(entity_type, entity_id),
    
    UNIQUE(from_entity_type, from_entity_id, relationship_type, to_entity_type, to_entity_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_agent_metrics_timestamp ON agentdash.agent_trace_metrics(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_agent_metrics_agent ON agentdash.agent_trace_metrics(agent);
CREATE INDEX IF NOT EXISTS idx_agent_metrics_task ON agentdash.agent_trace_metrics(task);
CREATE INDEX IF NOT EXISTS idx_agent_metrics_metric ON agentdash.agent_trace_metrics(metric);
CREATE INDEX IF NOT EXISTS idx_agent_metrics_score ON agentdash.agent_trace_metrics(score DESC);
CREATE INDEX IF NOT EXISTS idx_agent_metrics_trace_id ON agentdash.agent_trace_metrics(trace_id);
CREATE INDEX IF NOT EXISTS idx_agent_metrics_session_id ON agentdash.agent_trace_metrics(session_id);

CREATE INDEX IF NOT EXISTS idx_agent_performance_period ON agentdash.agent_performance_summary(period_start DESC, period_end DESC);
CREATE INDEX IF NOT EXISTS idx_agent_sessions_status ON agentdash.agent_sessions(status);
CREATE INDEX IF NOT EXISTS idx_agent_sessions_started ON agentdash.agent_sessions(started_at DESC);

CREATE INDEX IF NOT EXISTS idx_knowledge_entities_type ON agentdash.knowledge_entities(entity_type);
CREATE INDEX IF NOT EXISTS idx_knowledge_relationships_from ON agentdash.knowledge_relationships(from_entity_type, from_entity_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_relationships_to ON agentdash.knowledge_relationships(to_entity_type, to_entity_id);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Insert trace metric function
CREATE OR REPLACE FUNCTION agentdash.insert_trace_metric(
    p_agent TEXT,
    p_task TEXT,
    p_metric TEXT,
    p_score NUMERIC,
    p_execution_time_ms INTEGER DEFAULT NULL,
    p_tool_calls JSONB DEFAULT NULL,
    p_error_count INTEGER DEFAULT 0,
    p_session_id UUID DEFAULT NULL,
    p_trace_id UUID DEFAULT NULL,
    p_metadata JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_trace_id UUID;
BEGIN
    -- Use provided trace_id or generate new one
    v_trace_id := COALESCE(p_trace_id, gen_random_uuid());
    
    INSERT INTO agentdash.agent_trace_metrics (
        agent,
        task,
        metric,
        score,
        execution_time_ms,
        tool_calls,
        error_count,
        session_id,
        trace_id,
        metadata
    ) VALUES (
        p_agent,
        p_task,
        p_metric,
        p_score,
        p_execution_time_ms,
        COALESCE(p_tool_calls, '[]'::jsonb),
        p_error_count,
        p_session_id,
        v_trace_id,
        COALESCE(p_metadata, '{}'::jsonb)
    );
    
    RETURN v_trace_id;
END;
$$ LANGUAGE plpgsql;

-- Aggregate performance function
CREATE OR REPLACE FUNCTION agentdash.aggregate_performance(
    p_period_hours INTEGER DEFAULT 24
) RETURNS void AS $$
DECLARE
    v_period_start TIMESTAMPTZ;
    v_period_end TIMESTAMPTZ;
BEGIN
    v_period_end := DATE_TRUNC('hour', NOW());
    v_period_start := v_period_end - INTERVAL '1 hour' * p_period_hours;
    
    -- Aggregate metrics for the period
    INSERT INTO agentdash.agent_performance_summary (
        agent,
        task,
        metric,
        period_start,
        period_end,
        avg_score,
        min_score,
        max_score,
        execution_count,
        success_rate,
        avg_execution_time_ms,
        total_errors
    )
    SELECT 
        agent,
        task,
        metric,
        v_period_start,
        v_period_end,
        ROUND(AVG(score), 2),
        MIN(score),
        MAX(score),
        COUNT(*),
        ROUND(COUNT(*) FILTER (WHERE error_count = 0) * 100.0 / COUNT(*), 2),
        ROUND(AVG(execution_time_ms)),
        SUM(error_count)
    FROM agentdash.agent_trace_metrics
    WHERE timestamp >= v_period_start 
        AND timestamp < v_period_end
    GROUP BY agent, task, metric
    ON CONFLICT (agent, task, metric, period_start, period_end) 
    DO UPDATE SET
        avg_score = EXCLUDED.avg_score,
        min_score = EXCLUDED.min_score,
        max_score = EXCLUDED.max_score,
        execution_count = EXCLUDED.execution_count,
        success_rate = EXCLUDED.success_rate,
        avg_execution_time_ms = EXCLUDED.avg_execution_time_ms,
        total_errors = EXCLUDED.total_errors;
END;
$$ LANGUAGE plpgsql;

-- Get agent performance function
CREATE OR REPLACE FUNCTION agentdash.get_agent_performance(
    p_agent TEXT DEFAULT NULL,
    p_hours INTEGER DEFAULT 24
) RETURNS TABLE (
    agent TEXT,
    task TEXT,
    metric TEXT,
    avg_score NUMERIC,
    success_rate NUMERIC,
    execution_count BIGINT,
    avg_execution_time_ms NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        atm.agent,
        atm.task,
        atm.metric,
        ROUND(AVG(atm.score), 2) as avg_score,
        ROUND(COUNT(*) FILTER (WHERE atm.error_count = 0) * 100.0 / COUNT(*), 2) as success_rate,
        COUNT(*) as execution_count,
        ROUND(AVG(atm.execution_time_ms)) as avg_execution_time_ms
    FROM agentdash.agent_trace_metrics atm
    WHERE (p_agent IS NULL OR atm.agent = p_agent)
        AND atm.timestamp >= NOW() - INTERVAL '1 hour' * p_hours
    GROUP BY atm.agent, atm.task, atm.metric
    ORDER BY atm.agent, avg_score DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Agent performance dashboard view
CREATE OR REPLACE VIEW agentdash.agent_dashboard AS
SELECT 
    agent,
    COUNT(DISTINCT task) as tasks_handled,
    COUNT(DISTINCT metric) as metrics_tracked,
    ROUND(AVG(score), 2) as overall_score,
    ROUND(COUNT(*) FILTER (WHERE error_count = 0) * 100.0 / COUNT(*), 2) as success_rate,
    COUNT(*) as total_executions,
    ROUND(AVG(execution_time_ms)) as avg_execution_time_ms,
    MAX(timestamp) as last_activity
FROM agentdash.agent_trace_metrics
WHERE timestamp >= NOW() - INTERVAL '24 hours'
GROUP BY agent
ORDER BY overall_score DESC;

-- Real-time agent status
CREATE OR REPLACE VIEW agentdash.agent_status AS
SELECT 
    agent,
    task,
    COUNT(*) FILTER (WHERE timestamp >= NOW() - INTERVAL '5 minutes') as recent_activity,
    COUNT(*) FILTER (WHERE timestamp >= NOW() - INTERVAL '5 minutes' AND error_count > 0) as recent_errors,
    AVG(score) FILTER (WHERE timestamp >= NOW() - INTERVAL '5 minutes') as recent_avg_score,
    MAX(timestamp) as last_seen
FROM agentdash.agent_trace_metrics
WHERE timestamp >= NOW() - INTERVAL '1 hour'
GROUP BY agent, task
ORDER BY last_seen DESC;

-- Top failing agents/tasks
CREATE OR REPLACE VIEW agentdash.failing_agents AS
SELECT 
    agent,
    task,
    metric,
    COUNT(*) as failure_count,
    ROUND(AVG(score), 2) as avg_score,
    ROUND(COUNT(*) FILTER (WHERE error_count > 0) * 100.0 / COUNT(*), 2) as error_rate,
    MAX(timestamp) as last_failure
FROM agentdash.agent_trace_metrics
WHERE timestamp >= NOW() - INTERVAL '24 hours'
    AND (score < 50 OR error_count > 0)
GROUP BY agent, task, metric
HAVING COUNT(*) >= 5
ORDER BY error_rate DESC, failure_count DESC;

-- ============================================================================
-- PERMISSIONS
-- ============================================================================

-- Grant permissions
GRANT USAGE ON SCHEMA agentdash TO authenticated, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA agentdash TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA agentdash TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA agentdash TO authenticated, service_role;

-- Row Level Security
ALTER TABLE agentdash.agent_trace_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE agentdash.agent_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE agentdash.agent_performance_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE agentdash.agent_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE agentdash.knowledge_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE agentdash.knowledge_relationships ENABLE ROW LEVEL SECURITY;

-- Policies (allow all for service_role, authenticated users can read)
CREATE POLICY "Allow service_role full access" ON agentdash.agent_trace_metrics
    FOR ALL TO service_role USING (true);

CREATE POLICY "Allow authenticated read access" ON agentdash.agent_trace_metrics
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow service_role full access" ON agentdash.agent_definitions
    FOR ALL TO service_role USING (true);

CREATE POLICY "Allow authenticated read access" ON agentdash.agent_definitions
    FOR SELECT TO authenticated USING (true);

-- Apply similar policies to other tables
DO $$
DECLARE
    table_name TEXT;
BEGIN
    FOR table_name IN 
        SELECT t.table_name 
        FROM information_schema.tables t
        WHERE t.table_schema = 'agentdash'
            AND t.table_name NOT IN ('agent_trace_metrics', 'agent_definitions')
    LOOP
        EXECUTE format('CREATE POLICY "Allow service_role full access" ON agentdash.%I FOR ALL TO service_role USING (true)', table_name);
        EXECUTE format('CREATE POLICY "Allow authenticated read access" ON agentdash.%I FOR SELECT TO authenticated USING (true)', table_name);
    END LOOP;
END $$;

-- ============================================================================
-- INITIAL DATA SEEDING
-- ============================================================================

-- Insert core agent definitions
INSERT INTO agentdash.agent_definitions (
    agent_name,
    description,
    routes,
    capabilities,
    metrics,
    dependencies
) VALUES 
(
    'CESAI',
    'Creative Effectiveness Scoring AI',
    ARRAY['insight_templates', 'benchmark_scorer'],
    ARRAY['creative_scoring', 'roi_calculation', 'award_prediction'],
    ARRAY['ToolErrorRate', 'FinalResultRelevance', 'CreativeScore'],
    ARRAY['scout.deep_research', 'scout.benchmarks']
),
(
    'Claudia',
    'Master Agent Orchestrator',
    ARRAY['agent_coordination', 'fallback_handler'],
    ARRAY['task_delegation', 'error_recovery', 'result_aggregation'],
    ARRAY['FlowAdherence', 'OrchestrationEfficiency', 'TaskCompletionRate'],
    ARRAY['agentdash.agent_trace_metrics']
),
(
    'Echo',
    'Signal Extraction Agent',
    ARRAY['raw_data_parsing', 'signal_extraction'],
    ARRAY['text_extraction', 'entity_recognition', 'sentiment_analysis'],
    ARRAY['ExtractionAccuracy', 'ProcessingSpeed', 'DataCompleteness'],
    ARRAY['scout.bronze_edge_raw']
)
ON CONFLICT (agent_name) DO UPDATE SET
    description = EXCLUDED.description,
    routes = EXCLUDED.routes,
    capabilities = EXCLUDED.capabilities,
    metrics = EXCLUDED.metrics,
    dependencies = EXCLUDED.dependencies,
    updated_at = NOW();

-- Insert knowledge graph entities for agents
INSERT INTO agentdash.knowledge_entities (entity_type, entity_id, name, properties) VALUES
    ('Agent', 'CESAI', 'Creative Effectiveness Scoring AI', '{"type": "scoring", "domain": "creative"}'),
    ('Agent', 'Claudia', 'Master Agent Orchestrator', '{"type": "orchestration", "domain": "coordination"}'),
    ('Agent', 'Echo', 'Signal Extraction Agent', '{"type": "extraction", "domain": "data_processing"}'),
    ('Metric', 'ToolErrorRate', 'Tool Error Rate', '{"unit": "percentage", "direction": "lower_better"}'),
    ('Metric', 'FinalResultRelevance', 'Final Result Relevance', '{"unit": "score", "direction": "higher_better"}'),
    ('Metric', 'FlowAdherence', 'Flow Adherence', '{"unit": "percentage", "direction": "higher_better"}'),
    ('Metric', 'CreativeScore', 'Creative Effectiveness Score', '{"unit": "score", "range": "0-100"}')
ON CONFLICT (entity_type, entity_id) DO UPDATE SET
    name = EXCLUDED.name,
    properties = EXCLUDED.properties,
    updated_at = NOW();

-- Insert relationships
INSERT INTO agentdash.knowledge_relationships (
    from_entity_type, from_entity_id, relationship_type, to_entity_type, to_entity_id, strength
) VALUES
    ('Agent', 'CESAI', 'MEASURES', 'Metric', 'ToolErrorRate', 1.0),
    ('Agent', 'CESAI', 'MEASURES', 'Metric', 'FinalResultRelevance', 1.0),
    ('Agent', 'CESAI', 'MEASURES', 'Metric', 'CreativeScore', 1.0),
    ('Agent', 'Claudia', 'ORCHESTRATES', 'Agent', 'CESAI', 0.9),
    ('Agent', 'Claudia', 'ORCHESTRATES', 'Agent', 'Echo', 0.9),
    ('Agent', 'Claudia', 'MEASURES', 'Metric', 'FlowAdherence', 1.0)
ON CONFLICT (from_entity_type, from_entity_id, relationship_type, to_entity_type, to_entity_id) 
DO UPDATE SET strength = EXCLUDED.strength;

COMMENT ON SCHEMA agentdash IS 'Agent dashboard and trace metrics for agentic analytics system';
COMMENT ON TABLE agentdash.agent_trace_metrics IS 'Core metrics tracking for all agent activities and performance';
COMMENT ON TABLE agentdash.agent_definitions IS 'Agent configuration and capabilities definitions';
COMMENT ON TABLE agentdash.knowledge_entities IS 'Knowledge graph entities for agent ecosystem';
COMMENT ON TABLE agentdash.knowledge_relationships IS 'Relationships between knowledge graph entities';