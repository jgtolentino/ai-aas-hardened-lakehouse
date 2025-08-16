-- ============================================================================
-- Scout Monitoring and Alerts System
-- Dataset freshness, pipeline health, and automated notifications
-- ============================================================================

-- Create monitoring schema
CREATE SCHEMA IF NOT EXISTS scout_monitoring;

-- Dataset freshness monitoring
CREATE TABLE IF NOT EXISTS scout_monitoring.dataset_freshness (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    dataset_name TEXT NOT NULL,
    layer TEXT NOT NULL CHECK (layer IN ('bronze', 'silver', 'gold', 'platinum')),
    last_updated TIMESTAMPTZ,
    expected_update_interval INTERVAL NOT NULL DEFAULT '1 hour',
    is_stale BOOLEAN GENERATED ALWAYS AS (
        CASE 
            WHEN last_updated IS NULL THEN true
            ELSE (NOW() - last_updated) > expected_update_interval
        END
    ) STORED,
    alert_sent BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(dataset_name, layer)
);

-- Pipeline health metrics
CREATE TABLE IF NOT EXISTS scout_monitoring.pipeline_health (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    pipeline_name TEXT NOT NULL,
    run_id TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('running', 'success', 'failed', 'timeout')),
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    duration_seconds INTEGER GENERATED ALWAYS AS (
        EXTRACT(EPOCH FROM (COALESCE(completed_at, NOW()) - started_at))
    ) STORED,
    records_processed INTEGER,
    records_failed INTEGER,
    error_message TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Alert configuration
CREATE TABLE IF NOT EXISTS scout_monitoring.alert_rules (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    rule_name TEXT NOT NULL UNIQUE,
    rule_type TEXT NOT NULL CHECK (rule_type IN ('freshness', 'error_rate', 'performance', 'volume')),
    target_dataset TEXT,
    condition_sql TEXT NOT NULL,
    threshold_value NUMERIC,
    severity TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'critical')),
    notification_channels TEXT[] DEFAULT ARRAY['email'],
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Alert history
CREATE TABLE IF NOT EXISTS scout_monitoring.alert_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    rule_id UUID REFERENCES scout_monitoring.alert_rules(id),
    triggered_at TIMESTAMPTZ DEFAULT NOW(),
    severity TEXT NOT NULL,
    message TEXT NOT NULL,
    details JSONB,
    acknowledged BOOLEAN DEFAULT false,
    acknowledged_by TEXT,
    acknowledged_at TIMESTAMPTZ,
    resolved BOOLEAN DEFAULT false,
    resolved_at TIMESTAMPTZ
);

-- Data quality metrics
CREATE TABLE IF NOT EXISTS scout_monitoring.data_quality_metrics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    dataset_name TEXT NOT NULL,
    check_name TEXT NOT NULL,
    check_type TEXT NOT NULL CHECK (check_type IN ('completeness', 'accuracy', 'consistency', 'timeliness')),
    check_sql TEXT NOT NULL,
    expected_result TEXT,
    actual_result TEXT,
    passed BOOLEAN,
    score NUMERIC,
    checked_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(dataset_name, check_name, checked_at)
);

-- Create monitoring functions

-- Update dataset freshness
CREATE OR REPLACE FUNCTION scout_monitoring.update_freshness(
    p_dataset_name TEXT,
    p_layer TEXT,
    p_expected_interval INTERVAL DEFAULT '1 hour'
) RETURNS void AS $$
BEGIN
    INSERT INTO scout_monitoring.dataset_freshness (
        dataset_name,
        layer,
        last_updated,
        expected_update_interval
    ) VALUES (
        p_dataset_name,
        p_layer,
        NOW(),
        p_expected_interval
    )
    ON CONFLICT (dataset_name, layer) DO UPDATE SET
        last_updated = NOW(),
        expected_update_interval = EXCLUDED.expected_update_interval,
        alert_sent = false;
END;
$$ LANGUAGE plpgsql;

-- Log pipeline run
CREATE OR REPLACE FUNCTION scout_monitoring.log_pipeline_run(
    p_pipeline_name TEXT,
    p_run_id TEXT,
    p_status TEXT,
    p_records_processed INTEGER DEFAULT NULL,
    p_records_failed INTEGER DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_pipeline_id UUID;
BEGIN
    -- If completing a run, update existing record
    IF p_status IN ('success', 'failed', 'timeout') THEN
        UPDATE scout_monitoring.pipeline_health
        SET 
            status = p_status,
            completed_at = NOW(),
            records_processed = COALESCE(p_records_processed, records_processed),
            records_failed = COALESCE(p_records_failed, records_failed),
            error_message = p_error_message,
            metadata = COALESCE(p_metadata, metadata)
        WHERE pipeline_name = p_pipeline_name 
            AND run_id = p_run_id
            AND status = 'running'
        RETURNING id INTO v_pipeline_id;
    END IF;
    
    -- If no existing run or starting new, insert
    IF v_pipeline_id IS NULL THEN
        INSERT INTO scout_monitoring.pipeline_health (
            pipeline_name,
            run_id,
            status,
            started_at,
            completed_at,
            records_processed,
            records_failed,
            error_message,
            metadata
        ) VALUES (
            p_pipeline_name,
            p_run_id,
            p_status,
            NOW(),
            CASE WHEN p_status != 'running' THEN NOW() ELSE NULL END,
            p_records_processed,
            p_records_failed,
            p_error_message,
            p_metadata
        )
        RETURNING id INTO v_pipeline_id;
    END IF;
    
    RETURN v_pipeline_id;
END;
$$ LANGUAGE plpgsql;

-- Check and trigger alerts
CREATE OR REPLACE FUNCTION scout_monitoring.check_alerts() RETURNS void AS $$
DECLARE
    v_rule RECORD;
    v_result BOOLEAN;
    v_details JSONB;
BEGIN
    FOR v_rule IN 
        SELECT * FROM scout_monitoring.alert_rules 
        WHERE enabled = true
    LOOP
        -- Execute rule condition
        EXECUTE v_rule.condition_sql INTO v_result;
        
        IF v_result THEN
            -- Build alert details
            v_details := jsonb_build_object(
                'rule_name', v_rule.rule_name,
                'rule_type', v_rule.rule_type,
                'threshold', v_rule.threshold_value,
                'target_dataset', v_rule.target_dataset
            );
            
            -- Check if alert already exists and is unresolved
            IF NOT EXISTS (
                SELECT 1 FROM scout_monitoring.alert_history
                WHERE rule_id = v_rule.id
                    AND resolved = false
                    AND triggered_at > NOW() - INTERVAL '1 hour'
            ) THEN
                -- Create new alert
                INSERT INTO scout_monitoring.alert_history (
                    rule_id,
                    severity,
                    message,
                    details
                ) VALUES (
                    v_rule.id,
                    v_rule.severity,
                    format('Alert: %s triggered for %s', v_rule.rule_name, v_rule.target_dataset),
                    v_details
                );
                
                -- TODO: Send notifications based on notification_channels
            END IF;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Data quality check function
CREATE OR REPLACE FUNCTION scout_monitoring.run_quality_check(
    p_dataset_name TEXT,
    p_check_name TEXT,
    p_check_type TEXT,
    p_check_sql TEXT,
    p_expected_result TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_actual_result TEXT;
    v_passed BOOLEAN;
    v_score NUMERIC;
BEGIN
    -- Execute the check SQL
    EXECUTE p_check_sql INTO v_actual_result;
    
    -- Determine if check passed
    IF p_expected_result IS NOT NULL THEN
        v_passed := (v_actual_result = p_expected_result);
    ELSE
        -- For numeric results, consider it passed if > 0
        v_passed := (v_actual_result::NUMERIC > 0);
    END IF;
    
    -- Calculate score (0-100)
    v_score := CASE 
        WHEN v_passed THEN 100
        WHEN p_check_type = 'completeness' THEN GREATEST(0, v_actual_result::NUMERIC)
        ELSE 0
    END;
    
    -- Log the result
    INSERT INTO scout_monitoring.data_quality_metrics (
        dataset_name,
        check_name,
        check_type,
        check_sql,
        expected_result,
        actual_result,
        passed,
        score
    ) VALUES (
        p_dataset_name,
        p_check_name,
        p_check_type,
        p_check_sql,
        p_expected_result,
        v_actual_result,
        v_passed,
        v_score
    );
    
    RETURN v_passed;
END;
$$ LANGUAGE plpgsql;

-- Insert default alert rules
INSERT INTO scout_monitoring.alert_rules (rule_name, rule_type, target_dataset, condition_sql, threshold_value, severity) VALUES
    ('Bronze Data Staleness', 'freshness', 'bronze_edge_raw', 
     'SELECT COUNT(*) > 0 FROM scout_monitoring.dataset_freshness WHERE dataset_name = ''bronze_edge_raw'' AND is_stale = true',
     1, 'warning'),
    
    ('Gold Layer Update Failure', 'freshness', 'gold_layer_views',
     'SELECT COUNT(*) > 0 FROM scout_monitoring.dataset_freshness WHERE layer = ''gold'' AND is_stale = true',
     1, 'critical'),
    
    ('High Pipeline Failure Rate', 'error_rate', 'all_pipelines',
     'SELECT COUNT(*) FILTER (WHERE status = ''failed'') * 100.0 / NULLIF(COUNT(*), 0) > 20 FROM scout_monitoring.pipeline_health WHERE created_at > NOW() - INTERVAL ''1 hour''',
     20, 'critical'),
    
    ('Low Data Volume', 'volume', 'bronze_edge_raw',
     'SELECT COUNT(*) < 100 FROM scout.bronze_edge_raw WHERE ingested_at > NOW() - INTERVAL ''1 hour''',
     100, 'warning'),
    
    ('Data Quality Degradation', 'performance', 'all_datasets',
     'SELECT AVG(score) < 80 FROM scout_monitoring.data_quality_metrics WHERE checked_at > NOW() - INTERVAL ''1 day''',
     80, 'warning');

-- Create monitoring views

-- Current system status
CREATE OR REPLACE VIEW scout_monitoring.system_status AS
SELECT 
    'Dataset Freshness' as component,
    COUNT(*) FILTER (WHERE NOT is_stale) as healthy,
    COUNT(*) FILTER (WHERE is_stale) as unhealthy,
    ROUND(COUNT(*) FILTER (WHERE NOT is_stale) * 100.0 / NULLIF(COUNT(*), 0), 1) as health_percentage
FROM scout_monitoring.dataset_freshness
UNION ALL
SELECT 
    'Pipeline Health' as component,
    COUNT(*) FILTER (WHERE status = 'success') as healthy,
    COUNT(*) FILTER (WHERE status = 'failed') as unhealthy,
    ROUND(COUNT(*) FILTER (WHERE status = 'success') * 100.0 / NULLIF(COUNT(*), 0), 1) as health_percentage
FROM scout_monitoring.pipeline_health
WHERE created_at > NOW() - INTERVAL '24 hours'
UNION ALL
SELECT 
    'Data Quality' as component,
    COUNT(*) FILTER (WHERE passed = true) as healthy,
    COUNT(*) FILTER (WHERE passed = false) as unhealthy,
    ROUND(AVG(score), 1) as health_percentage
FROM scout_monitoring.data_quality_metrics
WHERE checked_at > NOW() - INTERVAL '24 hours';

-- Active alerts
CREATE OR REPLACE VIEW scout_monitoring.active_alerts AS
SELECT 
    ah.id,
    ar.rule_name,
    ar.rule_type,
    ah.severity,
    ah.message,
    ah.triggered_at,
    ah.acknowledged,
    ah.details,
    EXTRACT(EPOCH FROM (NOW() - ah.triggered_at))/3600 as hours_active
FROM scout_monitoring.alert_history ah
JOIN scout_monitoring.alert_rules ar ON ah.rule_id = ar.id
WHERE ah.resolved = false
ORDER BY 
    CASE ah.severity 
        WHEN 'critical' THEN 1
        WHEN 'warning' THEN 2
        WHEN 'info' THEN 3
    END,
    ah.triggered_at DESC;

-- Grant permissions
GRANT SELECT ON ALL TABLES IN SCHEMA scout_monitoring TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA scout_monitoring TO service_role;

-- Create scheduled job to check alerts (requires pg_cron)
-- SELECT cron.schedule('check-alerts', '*/5 * * * *', 'SELECT scout_monitoring.check_alerts();');