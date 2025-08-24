-- ============================================================
-- SCOUT CONNECTIVITY LAYER ENHANCEMENTS
-- Auto-registration, dashboard functions, and health monitoring
-- ============================================================

SET search_path TO scout, public;

-- ============================================================
-- AUTO-REGISTRATION SYSTEM
-- ============================================================

-- Device auto-registration with unique device fingerprinting
CREATE OR REPLACE FUNCTION scout.fn_auto_register_device(
    p_device_fingerprint JSONB,
    p_store_location TEXT DEFAULT NULL,
    p_device_capabilities JSONB DEFAULT '{}'
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_device_id UUID;
    v_store_id UUID;
    v_device_name TEXT;
    v_mac_address TEXT;
    v_device_type TEXT;
    v_existing_device UUID;
BEGIN
    -- Extract device info from fingerprint
    v_mac_address := p_device_fingerprint->>'mac_address';
    v_device_type := COALESCE(p_device_fingerprint->>'device_type', 'raspberry_pi_5');
    
    -- Generate unique device name
    v_device_name := COALESCE(
        p_device_fingerprint->>'hostname',
        'Device-' || RIGHT(v_mac_address, 8)
    );
    
    -- Try to find store by location or use default
    IF p_store_location IS NOT NULL THEN
        SELECT store_id INTO v_store_id
        FROM scout.dim_stores 
        WHERE store_name ILIKE '%' || p_store_location || '%'
           OR region ILIKE '%' || p_store_location || '%'
        LIMIT 1;
    END IF;
    
    -- Check if device already exists (by MAC address)
    SELECT device_id INTO v_existing_device
    FROM scout.edge_devices
    WHERE mac_address = v_mac_address;
    
    IF v_existing_device IS NOT NULL THEN
        -- Update existing device
        UPDATE scout.edge_devices 
        SET 
            last_checkin = NOW(),
            updated_at = NOW(),
            device_config = device_config || p_device_capabilities,
            is_active = true
        WHERE device_id = v_existing_device;
        
        -- Log reconnection
        INSERT INTO scout.sync_logs (device_id, sync_type, success, sync_metadata)
        VALUES (v_existing_device, 'reconnection', true, 
                json_build_object('reconnected_at', NOW(), 'capabilities', p_device_capabilities));
        
        RETURN v_existing_device;
    ELSE
        -- Create new device
        INSERT INTO scout.edge_devices (
            device_name,
            device_type,
            store_id,
            mac_address,
            ip_address,
            firmware_version,
            device_config,
            registration_date,
            last_checkin
        ) VALUES (
            v_device_name,
            v_device_type,
            v_store_id,
            v_mac_address,
            CAST(p_device_fingerprint->>'ip_address' AS INET),
            COALESCE(p_device_fingerprint->>'firmware_version', 'v1.0.0'),
            json_build_object(
                'auto_registered', true,
                'registration_timestamp', NOW(),
                'capabilities', p_device_capabilities,
                'initial_fingerprint', p_device_fingerprint
            ),
            NOW(),
            NOW()
        ) RETURNING device_id INTO v_device_id;
        
        -- Log initial registration
        INSERT INTO scout.sync_logs (device_id, sync_type, success, sync_metadata)
        VALUES (v_device_id, 'auto_registration', true, 
                json_build_object('registered_at', NOW(), 'fingerprint', p_device_fingerprint));
        
        -- Create welcome alert
        INSERT INTO scout.alerts (
            alert_type, device_id, store_id, title, message, severity, alert_data
        ) VALUES (
            'device_registered',
            v_device_id,
            v_store_id,
            'New Device Auto-Registered: ' || v_device_name,
            'Device automatically registered and is now being monitored',
            'info',
            json_build_object('device_name', v_device_name, 'auto_registered', true)
        );
        
        RETURN v_device_id;
    END IF;
END;
$$;

-- ============================================================
-- CONNECTIVITY DASHBOARD FUNCTIONS
-- ============================================================

-- Comprehensive connectivity dashboard
CREATE OR REPLACE FUNCTION scout.get_connectivity_dashboard(
    p_store_id UUID DEFAULT NULL,
    p_time_window INTERVAL DEFAULT '24 hours'
) RETURNS TABLE (
    store_summary JSONB,
    device_health JSONB,
    alert_summary JSONB,
    sync_performance JSONB,
    network_status JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_cutoff_time TIMESTAMPTZ := NOW() - p_time_window;
BEGIN
    RETURN QUERY
    SELECT 
        -- Store Summary
        json_build_object(
            'total_stores', COUNT(DISTINCT CASE WHEN p_store_id IS NULL THEN d.store_id ELSE NULL END),
            'total_devices', COUNT(d.device_id),
            'online_devices', COUNT(d.device_id) FILTER (WHERE d.last_checkin > NOW() - INTERVAL '5 minutes'),
            'offline_devices', COUNT(d.device_id) FILTER (WHERE d.last_checkin <= NOW() - INTERVAL '5 minutes'),
            'auto_registered_devices', COUNT(d.device_id) FILTER (WHERE d.device_config->>'auto_registered' = 'true'),
            'device_types', json_agg(DISTINCT d.device_type)
        ) as store_summary,
        
        -- Device Health Aggregation
        json_build_object(
            'avg_cpu_usage', ROUND(AVG(h.cpu_usage)::numeric, 2),
            'avg_memory_usage', ROUND(AVG(h.memory_usage)::numeric, 2),
            'avg_temperature', ROUND(AVG(h.temperature_celsius)::numeric, 2),
            'avg_detection_accuracy', ROUND(AVG(h.brand_detection_accuracy)::numeric, 3),
            'total_transactions_today', SUM(h.transactions_processed_today),
            'devices_by_status', json_build_object(
                'healthy', COUNT(h.device_id) FILTER (WHERE h.status = 'healthy'),
                'warning', COUNT(h.device_id) FILTER (WHERE h.status = 'warning'),
                'critical', COUNT(h.device_id) FILTER (WHERE h.status = 'critical'),
                'offline', COUNT(h.device_id) FILTER (WHERE h.status = 'offline')
            )
        ) as device_health,
        
        -- Alert Summary
        json_build_object(
            'active_alerts', COUNT(a.id) FILTER (WHERE a.status = 'active'),
            'critical_alerts', COUNT(a.id) FILTER (WHERE a.status = 'active' AND a.severity = 'critical'),
            'alerts_by_type', json_agg(
                DISTINCT json_build_object(
                    'alert_type', a.alert_type,
                    'count', COUNT(a.id) FILTER (WHERE a.alert_type IS NOT NULL)
                )
            ) FILTER (WHERE a.alert_type IS NOT NULL),
            'recent_alerts', json_agg(
                json_build_object(
                    'title', a.title,
                    'severity', a.severity,
                    'created_at', a.created_at
                ) ORDER BY a.created_at DESC
            ) FILTER (WHERE a.created_at > v_cutoff_time)
        ) as alert_summary,
        
        -- Sync Performance
        json_build_object(
            'successful_syncs', COUNT(s.id) FILTER (WHERE s.success = true AND s.sync_started > v_cutoff_time),
            'failed_syncs', COUNT(s.id) FILTER (WHERE s.success = false AND s.sync_started > v_cutoff_time),
            'avg_sync_duration', ROUND(AVG(s.duration_ms) FILTER (WHERE s.success = true)::numeric, 0),
            'total_bytes_transferred', SUM(s.bytes_transferred) FILTER (WHERE s.sync_started > v_cutoff_time),
            'sync_types_distribution', json_agg(
                DISTINCT json_build_object(
                    'sync_type', s.sync_type,
                    'count', COUNT(s.id) FILTER (WHERE s.sync_type IS NOT NULL AND s.sync_started > v_cutoff_time)
                )
            ) FILTER (WHERE s.sync_type IS NOT NULL)
        ) as sync_performance,
        
        -- Network Status
        json_build_object(
            'avg_latency', ROUND(AVG(h.network_latency_ms)::numeric, 1),
            'avg_wifi_signal', ROUND(AVG(h.wifi_signal_strength)::numeric, 1),
            'connectivity_issues', COUNT(h.device_id) FILTER (WHERE h.network_latency_ms > 100 OR h.wifi_signal_strength < -70),
            'network_performance_trend', json_agg(
                json_build_object(
                    'hour', EXTRACT(HOUR FROM h.timestamp),
                    'avg_latency', AVG(h.network_latency_ms),
                    'device_count', COUNT(h.device_id)
                ) ORDER BY EXTRACT(HOUR FROM h.timestamp)
            ) FILTER (WHERE h.timestamp > v_cutoff_time)
        ) as network_status
        
    FROM scout.edge_devices d
    LEFT JOIN LATERAL (
        SELECT *
        FROM scout.edge_health h2
        WHERE h2.device_id = d.device_id
          AND h2.timestamp > v_cutoff_time
        ORDER BY h2.timestamp DESC
        LIMIT 1
    ) h ON true
    LEFT JOIN scout.alerts a ON a.device_id = d.device_id AND a.created_at > v_cutoff_time
    LEFT JOIN scout.sync_logs s ON s.device_id = d.device_id
    WHERE (p_store_id IS NULL OR d.store_id = p_store_id)
      AND d.is_active = true;
END;
$$;

-- Connectivity health checker
CREATE OR REPLACE FUNCTION scout.check_connectivity_health(
    p_store_id UUID DEFAULT NULL
) RETURNS TABLE (
    device_id UUID,
    device_name TEXT,
    health_score NUMERIC,
    issues JSONB,
    recommendations JSONB,
    last_health_check TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH device_health_analysis AS (
        SELECT 
            d.device_id,
            d.device_name,
            d.device_type,
            d.last_checkin,
            h.cpu_usage,
            h.memory_usage,
            h.disk_usage,
            h.temperature_celsius,
            h.network_latency_ms,
            h.wifi_signal_strength,
            h.brand_detection_accuracy,
            h.status,
            h.timestamp as last_health_timestamp,
            
            -- Calculate health score (0-100)
            GREATEST(0, LEAST(100,
                100 
                - (CASE WHEN h.cpu_usage > 80 THEN (h.cpu_usage - 80) * 2 ELSE 0 END)
                - (CASE WHEN h.memory_usage > 85 THEN (h.memory_usage - 85) * 3 ELSE 0 END)
                - (CASE WHEN h.temperature_celsius > 60 THEN (h.temperature_celsius - 60) * 2 ELSE 0 END)
                - (CASE WHEN h.network_latency_ms > 100 THEN (h.network_latency_ms - 100) / 10 ELSE 0 END)
                - (CASE WHEN h.wifi_signal_strength < -70 THEN ABS(h.wifi_signal_strength + 70) ELSE 0 END)
                - (CASE WHEN h.brand_detection_accuracy < 0.9 THEN (0.9 - h.brand_detection_accuracy) * 50 ELSE 0 END)
                - (CASE WHEN d.last_checkin < NOW() - INTERVAL '10 minutes' THEN 50 ELSE 0 END)
            )) as health_score,
            
            -- Identify issues
            json_build_object(
                'offline', d.last_checkin < NOW() - INTERVAL '10 minutes',
                'high_cpu', h.cpu_usage > 80,
                'high_memory', h.memory_usage > 85,
                'high_temperature', h.temperature_celsius > 60,
                'slow_network', h.network_latency_ms > 100,
                'weak_wifi', h.wifi_signal_strength < -70,
                'low_accuracy', h.brand_detection_accuracy < 0.9,
                'disk_space_low', h.disk_usage > 90
            ) as issues
            
        FROM scout.edge_devices d
        LEFT JOIN LATERAL (
            SELECT *
            FROM scout.edge_health h2
            WHERE h2.device_id = d.device_id
            ORDER BY h2.timestamp DESC
            LIMIT 1
        ) h ON true
        WHERE (p_store_id IS NULL OR d.store_id = p_store_id)
          AND d.is_active = true
    )
    SELECT 
        dha.device_id,
        dha.device_name,
        ROUND(dha.health_score, 1) as health_score,
        dha.issues,
        
        -- Generate recommendations based on issues
        json_build_object(
            'actions', CASE 
                WHEN (dha.issues->>'offline')::boolean THEN 
                    json_build_array('Check device power and network connection', 'Verify device is responsive')
                WHEN (dha.issues->>'high_cpu')::boolean OR (dha.issues->>'high_memory')::boolean THEN
                    json_build_array('Restart device services', 'Check for resource-intensive processes', 'Consider firmware update')
                WHEN (dha.issues->>'high_temperature')::boolean THEN
                    json_build_array('Check device ventilation', 'Verify cooling systems', 'Monitor ambient temperature')
                WHEN (dha.issues->>'slow_network')::boolean OR (dha.issues->>'weak_wifi')::boolean THEN
                    json_build_array('Check network configuration', 'Verify WiFi signal strength', 'Test internet connectivity')
                WHEN (dha.issues->>'low_accuracy')::boolean THEN
                    json_build_array('Recalibrate brand detection model', 'Check camera/sensor alignment', 'Update detection algorithms')
                ELSE json_build_array('Device operating normally')
            END,
            'priority', CASE 
                WHEN dha.health_score < 30 THEN 'critical'
                WHEN dha.health_score < 60 THEN 'high'
                WHEN dha.health_score < 80 THEN 'medium'
                ELSE 'low'
            END,
            'estimated_fix_time', CASE 
                WHEN (dha.issues->>'offline')::boolean THEN '10-30 minutes'
                WHEN (dha.issues->>'high_cpu')::boolean OR (dha.issues->>'high_memory')::boolean THEN '5-15 minutes'
                WHEN (dha.issues->>'high_temperature')::boolean THEN '15-45 minutes'
                WHEN (dha.issues->>'slow_network')::boolean THEN '10-20 minutes'
                ELSE '5 minutes'
            END
        ) as recommendations,
        
        COALESCE(dha.last_health_timestamp, dha.last_checkin) as last_health_check
        
    FROM device_health_analysis dha
    ORDER BY dha.health_score ASC, dha.device_name;
END;
$$;

-- ============================================================
-- ENHANCED VIEWS
-- ============================================================

-- Real-time connectivity dashboard view
CREATE OR REPLACE VIEW scout.v_connectivity_dashboard AS
SELECT 
    d.device_id,
    d.device_name,
    d.device_type,
    d.store_id,
    s.store_name,
    s.region,
    d.mac_address,
    d.firmware_version,
    d.registration_date,
    d.last_checkin,
    
    -- Connection Status
    CASE 
        WHEN d.last_checkin > NOW() - INTERVAL '2 minutes' THEN 'online'
        WHEN d.last_checkin > NOW() - INTERVAL '10 minutes' THEN 'warning' 
        ELSE 'offline'
    END as connection_status,
    
    EXTRACT(EPOCH FROM (NOW() - d.last_checkin))/60 as minutes_since_checkin,
    
    -- Latest Health Metrics
    h.cpu_usage,
    h.memory_usage,
    h.disk_usage,
    h.temperature_celsius,
    h.uptime_seconds,
    h.network_latency_ms,
    h.wifi_signal_strength,
    h.brand_detection_accuracy,
    h.transactions_processed_today,
    h.queue_size,
    h.status as health_status,
    h.timestamp as last_health_update,
    
    -- Auto-registration info
    (d.device_config->>'auto_registered')::boolean as auto_registered,
    d.device_config->'registration_timestamp' as auto_registration_time,
    
    -- Alert Summary
    active_alerts.alert_count,
    active_alerts.critical_alert_count,
    active_alerts.latest_alert,
    
    -- Sync Performance
    sync_stats.last_successful_sync,
    sync_stats.last_failed_sync,
    sync_stats.sync_success_rate,
    
    -- Health Score (calculated)
    GREATEST(0, LEAST(100,
        100 
        - COALESCE((CASE WHEN h.cpu_usage > 80 THEN (h.cpu_usage - 80) * 2 ELSE 0 END), 0)
        - COALESCE((CASE WHEN h.memory_usage > 85 THEN (h.memory_usage - 85) * 3 ELSE 0 END), 0)
        - COALESCE((CASE WHEN h.temperature_celsius > 60 THEN (h.temperature_celsius - 60) * 2 ELSE 0 END), 0)
        - COALESCE((CASE WHEN h.network_latency_ms > 100 THEN (h.network_latency_ms - 100) / 10 ELSE 0 END), 0)
        - (CASE WHEN d.last_checkin < NOW() - INTERVAL '10 minutes' THEN 50 ELSE 0 END)
    )) as health_score

FROM scout.edge_devices d
LEFT JOIN scout.dim_stores s ON s.store_id = d.store_id
LEFT JOIN LATERAL (
    SELECT *
    FROM scout.edge_health h2
    WHERE h2.device_id = d.device_id
    ORDER BY h2.timestamp DESC
    LIMIT 1
) h ON true
LEFT JOIN LATERAL (
    SELECT 
        COUNT(*) as alert_count,
        COUNT(*) FILTER (WHERE severity = 'critical') as critical_alert_count,
        MAX(created_at) as latest_alert
    FROM scout.alerts a
    WHERE a.device_id = d.device_id AND a.status = 'active'
) active_alerts ON true
LEFT JOIN LATERAL (
    SELECT 
        MAX(sync_completed) FILTER (WHERE success = true) as last_successful_sync,
        MAX(sync_completed) FILTER (WHERE success = false) as last_failed_sync,
        CASE 
            WHEN COUNT(*) > 0 THEN 
                ROUND((COUNT(*) FILTER (WHERE success = true)::numeric / COUNT(*)) * 100, 1)
            ELSE NULL 
        END as sync_success_rate
    FROM scout.sync_logs sl
    WHERE sl.device_id = d.device_id 
      AND sl.sync_started > NOW() - INTERVAL '24 hours'
) sync_stats ON true
WHERE d.is_active = true;

-- Device fleet overview
CREATE OR REPLACE VIEW scout.v_device_fleet_overview AS
SELECT 
    s.store_id,
    s.store_name,
    s.region,
    
    -- Device counts
    COUNT(d.device_id) as total_devices,
    COUNT(d.device_id) FILTER (WHERE d.last_checkin > NOW() - INTERVAL '5 minutes') as online_devices,
    COUNT(d.device_id) FILTER (WHERE d.last_checkin <= NOW() - INTERVAL '5 minutes') as offline_devices,
    COUNT(d.device_id) FILTER (WHERE (d.device_config->>'auto_registered')::boolean = true) as auto_registered_devices,
    
    -- Device types
    json_agg(DISTINCT d.device_type) as device_types,
    
    -- Health aggregates
    ROUND(AVG(h.cpu_usage), 2) as avg_cpu_usage,
    ROUND(AVG(h.memory_usage), 2) as avg_memory_usage,
    ROUND(AVG(h.temperature_celsius), 2) as avg_temperature,
    ROUND(AVG(h.network_latency_ms), 1) as avg_latency,
    ROUND(AVG(h.brand_detection_accuracy), 3) as avg_detection_accuracy,
    SUM(h.transactions_processed_today) as total_transactions_today,
    
    -- Alert summary
    COUNT(a.id) FILTER (WHERE a.status = 'active') as active_alerts,
    COUNT(a.id) FILTER (WHERE a.status = 'active' AND a.severity = 'critical') as critical_alerts,
    
    -- Status distribution
    json_build_object(
        'healthy', COUNT(h.device_id) FILTER (WHERE h.status = 'healthy'),
        'warning', COUNT(h.device_id) FILTER (WHERE h.status = 'warning'),
        'critical', COUNT(h.device_id) FILTER (WHERE h.status = 'critical'),
        'offline', COUNT(d.device_id) FILTER (WHERE d.last_checkin <= NOW() - INTERVAL '5 minutes')
    ) as status_distribution,
    
    -- Last update
    MAX(GREATEST(d.last_checkin, h.timestamp)) as last_fleet_update

FROM scout.dim_stores s
LEFT JOIN scout.edge_devices d ON d.store_id = s.store_id AND d.is_active = true
LEFT JOIN LATERAL (
    SELECT *
    FROM scout.edge_health h2
    WHERE h2.device_id = d.device_id
    ORDER BY h2.timestamp DESC
    LIMIT 1
) h ON true
LEFT JOIN scout.alerts a ON a.device_id = d.device_id
GROUP BY s.store_id, s.store_name, s.region
HAVING COUNT(d.device_id) > 0
ORDER BY s.store_name;

-- ============================================================
-- DEVICE HEALTH FUNCTIONS
-- ============================================================

-- Get device health trends
CREATE OR REPLACE FUNCTION scout.get_device_health_trends(
    p_device_id UUID,
    p_hours INTEGER DEFAULT 24
) RETURNS TABLE (
    timestamp TIMESTAMPTZ,
    cpu_usage NUMERIC,
    memory_usage NUMERIC,
    temperature_celsius NUMERIC,
    network_latency_ms INTEGER,
    brand_detection_accuracy NUMERIC,
    status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        h.timestamp,
        h.cpu_usage,
        h.memory_usage,
        h.temperature_celsius,
        h.network_latency_ms,
        h.brand_detection_accuracy,
        h.status
    FROM scout.edge_health h
    WHERE h.device_id = p_device_id
      AND h.timestamp > NOW() - (p_hours || ' hours')::INTERVAL
    ORDER BY h.timestamp ASC;
END;
$$;

-- Predict device maintenance needs
CREATE OR REPLACE FUNCTION scout.predict_device_maintenance(
    p_device_id UUID DEFAULT NULL,
    p_store_id UUID DEFAULT NULL
) RETURNS TABLE (
    device_id UUID,
    device_name TEXT,
    maintenance_priority TEXT,
    predicted_issues JSONB,
    recommended_actions JSONB,
    confidence_score NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH device_trends AS (
        SELECT 
            d.device_id,
            d.device_name,
            
            -- Calculate trends over last 7 days
            AVG(h.cpu_usage) as avg_cpu,
            MAX(h.cpu_usage) as max_cpu,
            AVG(h.memory_usage) as avg_memory,
            MAX(h.memory_usage) as max_memory,
            AVG(h.temperature_celsius) as avg_temp,
            MAX(h.temperature_celsius) as max_temp,
            COUNT(h.id) FILTER (WHERE h.status IN ('warning', 'critical')) as warning_count,
            COUNT(h.id) as total_readings,
            
            -- Recent performance degradation
            AVG(h.cpu_usage) FILTER (WHERE h.timestamp > NOW() - INTERVAL '24 hours') as recent_cpu,
            AVG(h.cpu_usage) FILTER (WHERE h.timestamp BETWEEN NOW() - INTERVAL '7 days' AND NOW() - INTERVAL '24 hours') as baseline_cpu,
            
            AVG(h.memory_usage) FILTER (WHERE h.timestamp > NOW() - INTERVAL '24 hours') as recent_memory,
            AVG(h.memory_usage) FILTER (WHERE h.timestamp BETWEEN NOW() - INTERVAL '7 days' AND NOW() - INTERVAL '24 hours') as baseline_memory
            
        FROM scout.edge_devices d
        LEFT JOIN scout.edge_health h ON h.device_id = d.device_id 
            AND h.timestamp > NOW() - INTERVAL '7 days'
        WHERE (p_device_id IS NULL OR d.device_id = p_device_id)
          AND (p_store_id IS NULL OR d.store_id = p_store_id)
          AND d.is_active = true
        GROUP BY d.device_id, d.device_name
        HAVING COUNT(h.id) >= 10 -- Need sufficient data points
    )
    SELECT 
        dt.device_id,
        dt.device_name,
        
        -- Maintenance Priority
        CASE 
            WHEN dt.max_cpu > 95 OR dt.max_memory > 95 OR dt.max_temp > 70 THEN 'urgent'
            WHEN dt.avg_cpu > 80 OR dt.avg_memory > 85 OR dt.warning_count > dt.total_readings * 0.3 THEN 'high'
            WHEN dt.avg_cpu > 70 OR dt.avg_memory > 75 OR dt.warning_count > dt.total_readings * 0.1 THEN 'medium'
            ELSE 'low'
        END as maintenance_priority,
        
        -- Predicted Issues
        json_build_object(
            'cpu_degradation', dt.recent_cpu > dt.baseline_cpu * 1.2,
            'memory_leak_risk', dt.recent_memory > dt.baseline_memory * 1.15,
            'overheating_risk', dt.max_temp > 65,
            'performance_decline', dt.warning_count > dt.total_readings * 0.2,
            'hardware_stress', dt.max_cpu > 90 AND dt.max_memory > 90
        ) as predicted_issues,
        
        -- Recommended Actions
        json_build_object(
            'immediate_actions', CASE 
                WHEN dt.max_temp > 70 THEN json_build_array('Check cooling system', 'Verify ventilation')
                WHEN dt.max_cpu > 95 OR dt.max_memory > 95 THEN json_build_array('Schedule restart', 'Check running processes')
                ELSE json_build_array('Monitor closely')
            END,
            'maintenance_window', CASE 
                WHEN dt.avg_cpu > 80 OR dt.avg_memory > 85 THEN json_build_array('Schedule maintenance within 48 hours')
                WHEN dt.warning_count > dt.total_readings * 0.2 THEN json_build_array('Plan maintenance within 1 week')
                ELSE json_build_array('Regular maintenance schedule')
            END,
            'preventive_measures', json_build_array(
                'Regular firmware updates',
                'Scheduled reboots',
                'Performance monitoring',
                'Environmental checks'
            )
        ) as recommended_actions,
        
        -- Confidence Score
        ROUND(
            LEAST(100, GREATEST(0,
                (dt.total_readings / 168.0) * 100 * -- 168 = hours in week, data completeness
                (1 - (dt.warning_count::numeric / GREATEST(dt.total_readings, 1))) * 0.5 + 0.5 -- stability factor
            )), 1
        ) as confidence_score
        
    FROM device_trends dt
    ORDER BY 
        CASE 
            WHEN dt.max_cpu > 95 OR dt.max_memory > 95 OR dt.max_temp > 70 THEN 1
            WHEN dt.avg_cpu > 80 OR dt.avg_memory > 85 THEN 2
            WHEN dt.avg_cpu > 70 OR dt.avg_memory > 75 THEN 3
            ELSE 4
        END,
        dt.device_name;
END;
$$;

-- ============================================================
-- ADDITIONAL ALERT TYPES FOR AUTO-REGISTRATION
-- ============================================================

-- Add new alert type for device registration
INSERT INTO scout.alert_types (alert_type, display_name, description, severity_default) VALUES
('device_registered', 'Device Auto-Registered', 'New device automatically registered and is now being monitored', 'info'),
('device_reconnected', 'Device Reconnected', 'Previously registered device has reconnected', 'info'),
('maintenance_required', 'Predictive Maintenance Required', 'Device analysis suggests maintenance is needed', 'warning'),
('firmware_update_available', 'Firmware Update Available', 'New firmware version available for device', 'info')
ON CONFLICT (alert_type) DO NOTHING;

-- Add notification templates for new alert types
INSERT INTO scout.notification_templates (template_id, alert_type, channel, title_template, body_template) VALUES
('device_registered_push', 'device_registered', 'push', 'New Device: {{device_name}}', 'Device auto-registered and is now being monitored'),
('maintenance_required_push', 'maintenance_required', 'push', 'Maintenance: {{device_name}}', 'Predictive analysis suggests maintenance is needed: {{priority}} priority'),
('firmware_update_push', 'firmware_update_available', 'push', 'Update Available: {{device_name}}', 'Firmware {{new_version}} is available for your device')
ON CONFLICT (template_id) DO NOTHING;

-- ============================================================
-- GRANT PERMISSIONS
-- ============================================================

-- Grant execute permissions on new functions
GRANT EXECUTE ON FUNCTION scout.fn_auto_register_device TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION scout.get_connectivity_dashboard TO authenticated;
GRANT EXECUTE ON FUNCTION scout.check_connectivity_health TO authenticated;
GRANT EXECUTE ON FUNCTION scout.get_device_health_trends TO authenticated;
GRANT EXECUTE ON FUNCTION scout.predict_device_maintenance TO authenticated;

-- Grant access to new views
GRANT SELECT ON scout.v_connectivity_dashboard TO authenticated;
GRANT SELECT ON scout.v_device_fleet_overview TO authenticated;

-- ============================================================
-- COMPLETION NOTIFICATION
-- ============================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔗 SCOUT CONNECTIVITY LAYER ENHANCEMENTS DEPLOYED!';
    RAISE NOTICE '';
    RAISE NOTICE '✨ New Features Added:';
    RAISE NOTICE '   • Auto-registration with unique device fingerprinting';
    RAISE NOTICE '   • get_connectivity_dashboard() - Comprehensive dashboard function';
    RAISE NOTICE '   • check_connectivity_health() - Device health analysis';
    RAISE NOTICE '   • v_connectivity_dashboard - Real-time dashboard view';
    RAISE NOTICE '   • v_device_fleet_overview - Fleet-wide monitoring';
    RAISE NOTICE '   • Predictive maintenance analysis';
    RAISE NOTICE '   • Device health trend tracking';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Ready to Use:';
    RAISE NOTICE '   SELECT * FROM scout.get_connectivity_dashboard();';
    RAISE NOTICE '   SELECT * FROM scout.check_connectivity_health();';
    RAISE NOTICE '   SELECT * FROM scout.v_connectivity_dashboard;';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Auto-registration now handles unique device identification!';
    RAISE NOTICE '';
END $$;