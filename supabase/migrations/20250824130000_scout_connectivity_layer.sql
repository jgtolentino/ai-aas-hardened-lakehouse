-- ============================================================
-- SCOUT CONNECTIVITY LAYER - Edge Device Monitoring & Sync
-- Inspired by QIAsphere, adapted for Scout v5.2 retail analytics
-- ============================================================

SET search_path TO scout, public;

-- ============================================================
-- EDGE DEVICE HEALTH MONITORING
-- ============================================================

-- Edge device registry and health status
CREATE TABLE IF NOT EXISTS scout.edge_devices (
    device_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_name TEXT NOT NULL,
    device_type TEXT DEFAULT 'raspberry_pi_5' CHECK (device_type IN ('raspberry_pi_5', 'kiosk', 'tablet', 'mobile')),
    store_id UUID REFERENCES scout.dim_stores(store_id),
    mac_address TEXT UNIQUE,
    ip_address INET,
    firmware_version TEXT DEFAULT 'v1.0.0',
    registration_date TIMESTAMPTZ DEFAULT NOW(),
    last_checkin TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    device_config JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Real-time device health telemetry
CREATE TABLE IF NOT EXISTS scout.edge_health (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID REFERENCES scout.edge_devices(device_id) ON DELETE CASCADE,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    
    -- System metrics
    cpu_usage NUMERIC(5,2) CHECK (cpu_usage >= 0 AND cpu_usage <= 100),
    memory_usage NUMERIC(5,2) CHECK (memory_usage >= 0 AND memory_usage <= 100),
    disk_usage NUMERIC(5,2) CHECK (disk_usage >= 0 AND disk_usage <= 100),
    temperature_celsius NUMERIC(4,1),
    uptime_seconds BIGINT CHECK (uptime_seconds >= 0),
    
    -- Network & connectivity
    network_latency_ms INTEGER,
    wifi_signal_strength INTEGER CHECK (wifi_signal_strength BETWEEN -100 AND 0),
    is_online BOOLEAN DEFAULT true,
    last_sync_success TIMESTAMPTZ,
    
    -- Application metrics
    brand_detection_accuracy NUMERIC(4,2) CHECK (brand_detection_accuracy BETWEEN 0 AND 1),
    transactions_processed_today INTEGER DEFAULT 0,
    queue_size INTEGER DEFAULT 0,
    
    -- Status indicators
    status TEXT DEFAULT 'healthy' CHECK (status IN ('healthy', 'warning', 'critical', 'offline')),
    status_details JSONB DEFAULT '{}'
);

-- Sync operation logs
CREATE TABLE IF NOT EXISTS scout.sync_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID REFERENCES scout.edge_devices(device_id) ON DELETE CASCADE,
    sync_type TEXT NOT NULL CHECK (sync_type IN ('full_sync', 'incremental', 'heartbeat', 'config_update')),
    
    -- Timing
    sync_started TIMESTAMPTZ DEFAULT NOW(),
    sync_completed TIMESTAMPTZ,
    duration_ms INTEGER,
    
    -- Data transfer
    records_sent INTEGER DEFAULT 0,
    records_processed INTEGER DEFAULT 0,
    bytes_transferred BIGINT DEFAULT 0,
    
    -- Results
    success BOOLEAN DEFAULT false,
    error_code TEXT,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    
    -- Metadata
    sync_metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ALERT MANAGEMENT SYSTEM
-- ============================================================

-- Alert types and configuration
CREATE TABLE IF NOT EXISTS scout.alert_types (
    alert_type TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    description TEXT,
    severity_default TEXT DEFAULT 'warning' CHECK (severity_default IN ('info', 'warning', 'critical')),
    is_active BOOLEAN DEFAULT true,
    notification_channels JSONB DEFAULT '["push", "email"]',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default alert types
INSERT INTO scout.alert_types (alert_type, display_name, description, severity_default) VALUES
('device_offline', 'Device Offline', 'Edge device has not checked in for extended period', 'critical'),
('sync_failure', 'Sync Failure', 'Device failed to sync data with cloud hub', 'warning'),
('low_stock', 'Low Stock Alert', 'Product inventory below threshold', 'warning'),
('price_anomaly', 'Price Anomaly', 'Unusual price variation detected', 'info'),
('competitor_activity', 'Competitor Activity', 'New competitor product or promotion detected', 'info'),
('system_health', 'System Health Issue', 'Device system metrics outside normal range', 'warning'),
('brand_detection_error', 'Brand Detection Accuracy Low', 'Brand detection accuracy below threshold', 'warning'),
('data_quality_issue', 'Data Quality Issue', 'Inconsistent or suspicious transaction data', 'warning')
ON CONFLICT (alert_type) DO NOTHING;

-- Active alerts
CREATE TABLE IF NOT EXISTS scout.alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_type TEXT REFERENCES scout.alert_types(alert_type),
    device_id UUID REFERENCES scout.edge_devices(device_id),
    store_id UUID,  -- May reference stores table when available
    
    -- Alert content
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'critical')),
    
    -- Context data
    alert_data JSONB DEFAULT '{}',  -- Store-specific context (SKU, price, etc.)
    source_table TEXT,  -- Which table triggered this alert
    source_record_id UUID,  -- ID of the record that triggered the alert
    
    -- Lifecycle
    created_at TIMESTAMPTZ DEFAULT NOW(),
    acknowledged_at TIMESTAMPTZ,
    acknowledged_by UUID,  -- User ID who acknowledged
    resolved_at TIMESTAMPTZ,
    resolved_by UUID,  -- User ID who resolved
    resolution_notes TEXT,
    
    -- Status
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'acknowledged', 'resolved', 'suppressed')),
    is_notification_sent BOOLEAN DEFAULT false,
    notification_attempts INTEGER DEFAULT 0,
    
    -- Metadata
    tags TEXT[] DEFAULT '{}',
    priority INTEGER DEFAULT 5 CHECK (priority BETWEEN 1 AND 10)
);

-- Alert notification log
CREATE TABLE IF NOT EXISTS scout.alert_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_id UUID REFERENCES scout.alerts(id) ON DELETE CASCADE,
    notification_channel TEXT NOT NULL CHECK (notification_channel IN ('push', 'email', 'sms', 'webhook')),
    recipient TEXT NOT NULL,
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    delivered BOOLEAN DEFAULT false,
    delivery_confirmed_at TIMESTAMPTZ,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0
);

-- ============================================================
-- PUSH NOTIFICATION SYSTEM
-- ============================================================

-- User notification preferences
CREATE TABLE IF NOT EXISTS scout.user_notification_preferences (
    user_id UUID PRIMARY KEY,
    push_enabled BOOLEAN DEFAULT true,
    email_enabled BOOLEAN DEFAULT true,
    sms_enabled BOOLEAN DEFAULT false,
    
    -- Alert type preferences
    alert_preferences JSONB DEFAULT '{}',  -- {alert_type: {enabled: true, channels: [...], quiet_hours: [...]}}
    
    -- Delivery settings
    quiet_hours_start TIME DEFAULT '22:00',
    quiet_hours_end TIME DEFAULT '07:00',
    timezone TEXT DEFAULT 'Asia/Manila',
    
    -- Device tokens for push notifications
    push_tokens TEXT[] DEFAULT '{}',  -- FCM/APNS device tokens
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Push notification templates
CREATE TABLE IF NOT EXISTS scout.notification_templates (
    template_id TEXT PRIMARY KEY,
    alert_type TEXT REFERENCES scout.alert_types(alert_type),
    channel TEXT NOT NULL CHECK (channel IN ('push', 'email', 'sms')),
    
    -- Template content
    title_template TEXT NOT NULL,  -- "Device {{device_name}} is offline"
    body_template TEXT NOT NULL,   -- "Device has been offline for {{duration}}"
    
    -- Metadata
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(alert_type, channel)
);

-- Insert default notification templates
INSERT INTO scout.notification_templates (template_id, alert_type, channel, title_template, body_template) VALUES
('device_offline_push', 'device_offline', 'push', 'Device Offline: {{device_name}}', 'Store device has been offline for {{duration}}. Check connection.'),
('sync_failure_push', 'sync_failure', 'push', 'Sync Failed: {{device_name}}', 'Failed to sync {{records_failed}} records. Retrying automatically.'),
('low_stock_push', 'low_stock', 'push', 'Low Stock Alert', '{{product_name}} is running low ({{current_qty}} remaining)'),
('price_anomaly_push', 'price_anomaly', 'push', 'Price Alert', '{{product_name}} price changed significantly: {{old_price}} → {{new_price}}')
ON CONFLICT (template_id) DO NOTHING;

-- ============================================================
-- DEVICE MANAGEMENT FUNCTIONS
-- ============================================================

-- Register new edge device
CREATE OR REPLACE FUNCTION scout.fn_register_edge_device(
    p_device_name TEXT,
    p_device_type TEXT DEFAULT 'raspberry_pi_5',
    p_store_id UUID DEFAULT NULL,
    p_mac_address TEXT DEFAULT NULL,
    p_config JSONB DEFAULT '{}'
) RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_device_id UUID;
BEGIN
    INSERT INTO scout.edge_devices (
        device_name, device_type, store_id, mac_address, device_config
    ) VALUES (
        p_device_name, p_device_type, p_store_id, p_mac_address, p_config
    ) RETURNING device_id INTO v_device_id;
    
    -- Log registration event
    INSERT INTO scout.sync_logs (device_id, sync_type, success, records_processed)
    VALUES (v_device_id, 'registration', true, 1);
    
    RETURN v_device_id;
END;
$$;

-- Update device health status
CREATE OR REPLACE FUNCTION scout.fn_update_device_health(
    p_device_id UUID,
    p_health_data JSONB
) RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_status TEXT := 'healthy';
    v_cpu NUMERIC;
    v_memory NUMERIC;
    v_is_online BOOLEAN := true;
BEGIN
    -- Extract metrics from JSON
    v_cpu := (p_health_data->>'cpu_usage')::NUMERIC;
    v_memory := (p_health_data->>'memory_usage')::NUMERIC;
    
    -- Determine status
    IF v_cpu > 90 OR v_memory > 90 THEN
        v_status := 'critical';
    ELSIF v_cpu > 70 OR v_memory > 70 THEN
        v_status := 'warning';
    END IF;
    
    -- Insert health record
    INSERT INTO scout.edge_health (
        device_id,
        cpu_usage,
        memory_usage,
        disk_usage,
        temperature_celsius,
        uptime_seconds,
        network_latency_ms,
        wifi_signal_strength,
        is_online,
        brand_detection_accuracy,
        transactions_processed_today,
        queue_size,
        status,
        status_details
    ) VALUES (
        p_device_id,
        v_cpu,
        (p_health_data->>'memory_usage')::NUMERIC,
        (p_health_data->>'disk_usage')::NUMERIC,
        (p_health_data->>'temperature')::NUMERIC,
        (p_health_data->>'uptime_seconds')::BIGINT,
        (p_health_data->>'latency_ms')::INTEGER,
        (p_health_data->>'wifi_signal')::INTEGER,
        v_is_online,
        (p_health_data->>'detection_accuracy')::NUMERIC,
        (p_health_data->>'transactions_today')::INTEGER,
        (p_health_data->>'queue_size')::INTEGER,
        v_status,
        p_health_data
    );
    
    -- Update device last checkin
    UPDATE scout.edge_devices 
    SET last_checkin = NOW(), updated_at = NOW()
    WHERE device_id = p_device_id;
    
    -- Trigger alerts if needed
    PERFORM scout.fn_check_device_alerts(p_device_id, v_status);
    
    RETURN true;
END;
$$;

-- Check and create alerts based on device status
CREATE OR REPLACE FUNCTION scout.fn_check_device_alerts(
    p_device_id UUID,
    p_status TEXT
) RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_device RECORD;
    v_alert_count INTEGER := 0;
    v_last_health RECORD;
BEGIN
    -- Get device info
    SELECT * INTO v_device FROM scout.edge_devices WHERE device_id = p_device_id;
    
    -- Get latest health metrics
    SELECT * INTO v_last_health 
    FROM scout.edge_health 
    WHERE device_id = p_device_id 
    ORDER BY timestamp DESC 
    LIMIT 1;
    
    -- Check for critical system health
    IF p_status = 'critical' AND NOT EXISTS (
        SELECT 1 FROM scout.alerts 
        WHERE device_id = p_device_id 
        AND alert_type = 'system_health' 
        AND status = 'active'
    ) THEN
        INSERT INTO scout.alerts (
            alert_type, device_id, store_id, title, message, severity, alert_data
        ) VALUES (
            'system_health',
            p_device_id,
            v_device.store_id,
            'System Health Critical: ' || v_device.device_name,
            'Device is experiencing high resource usage',
            'critical',
            json_build_object(
                'cpu_usage', v_last_health.cpu_usage,
                'memory_usage', v_last_health.memory_usage,
                'device_name', v_device.device_name
            )
        );
        v_alert_count := v_alert_count + 1;
    END IF;
    
    -- Check for offline devices
    IF v_device.last_checkin < NOW() - INTERVAL '10 minutes' AND NOT EXISTS (
        SELECT 1 FROM scout.alerts 
        WHERE device_id = p_device_id 
        AND alert_type = 'device_offline' 
        AND status = 'active'
    ) THEN
        INSERT INTO scout.alerts (
            alert_type, device_id, store_id, title, message, severity, alert_data
        ) VALUES (
            'device_offline',
            p_device_id,
            v_device.store_id,
            'Device Offline: ' || v_device.device_name,
            'Device has not checked in for ' || EXTRACT(EPOCH FROM (NOW() - v_device.last_checkin))/60 || ' minutes',
            'critical',
            json_build_object(
                'last_checkin', v_device.last_checkin,
                'duration_minutes', EXTRACT(EPOCH FROM (NOW() - v_device.last_checkin))/60,
                'device_name', v_device.device_name
            )
        );
        v_alert_count := v_alert_count + 1;
    END IF;
    
    RETURN v_alert_count;
END;
$$;

-- ============================================================
-- CONNECTIVITY LAYER VIEWS
-- ============================================================

-- Device dashboard overview
CREATE OR REPLACE VIEW scout.v_device_dashboard AS
SELECT 
    d.device_id,
    d.device_name,
    d.device_type,
    d.store_id,
    d.last_checkin,
    d.is_active,
    
    -- Latest health metrics
    h.cpu_usage,
    h.memory_usage,
    h.disk_usage,
    h.temperature_celsius,
    h.is_online,
    h.status as health_status,
    h.brand_detection_accuracy,
    h.transactions_processed_today,
    
    -- Alert counts
    COALESCE(alert_counts.active_alerts, 0) as active_alerts,
    COALESCE(alert_counts.critical_alerts, 0) as critical_alerts,
    
    -- Sync status
    CASE 
        WHEN d.last_checkin > NOW() - INTERVAL '5 minutes' THEN 'online'
        WHEN d.last_checkin > NOW() - INTERVAL '15 minutes' THEN 'warning'
        ELSE 'offline'
    END as connection_status,
    
    -- Performance metrics
    EXTRACT(EPOCH FROM (NOW() - d.last_checkin))/60 as minutes_since_checkin
    
FROM scout.edge_devices d
LEFT JOIN LATERAL (
    SELECT *
    FROM scout.edge_health h2
    WHERE h2.device_id = d.device_id
    ORDER BY h2.timestamp DESC
    LIMIT 1
) h ON true
LEFT JOIN LATERAL (
    SELECT 
        COUNT(*) as active_alerts,
        COUNT(*) FILTER (WHERE severity = 'critical') as critical_alerts
    FROM scout.alerts a
    WHERE a.device_id = d.device_id AND a.status = 'active'
) alert_counts ON true;

-- Store connectivity overview
CREATE OR REPLACE VIEW scout.v_store_connectivity AS
SELECT 
    s.store_id,
    s.store_name,
    s.region,
    
    -- Device counts
    COUNT(d.device_id) as total_devices,
    COUNT(d.device_id) FILTER (WHERE d.is_active) as active_devices,
    COUNT(d.device_id) FILTER (WHERE d.last_checkin > NOW() - INTERVAL '5 minutes') as online_devices,
    
    -- Health summary
    AVG(h.cpu_usage) as avg_cpu_usage,
    AVG(h.memory_usage) as avg_memory_usage,
    AVG(h.brand_detection_accuracy) as avg_detection_accuracy,
    SUM(h.transactions_processed_today) as total_transactions_today,
    
    -- Alert summary
    COUNT(a.id) FILTER (WHERE a.status = 'active') as active_alerts,
    COUNT(a.id) FILTER (WHERE a.status = 'active' AND a.severity = 'critical') as critical_alerts
    
FROM scout.dim_stores s
LEFT JOIN scout.edge_devices d ON d.store_id = s.store_id
LEFT JOIN LATERAL (
    SELECT *
    FROM scout.edge_health h2
    WHERE h2.device_id = d.device_id
    ORDER BY h2.timestamp DESC
    LIMIT 1
) h ON true
LEFT JOIN scout.alerts a ON a.device_id = d.device_id
GROUP BY s.store_id, s.store_name, s.region;

-- ============================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================

-- Edge devices
CREATE INDEX IF NOT EXISTS idx_edge_devices_store_id ON scout.edge_devices(store_id);
CREATE INDEX IF NOT EXISTS idx_edge_devices_last_checkin ON scout.edge_devices(last_checkin);
CREATE INDEX IF NOT EXISTS idx_edge_devices_active ON scout.edge_devices(is_active);

-- Health monitoring
CREATE INDEX IF NOT EXISTS idx_edge_health_device_timestamp ON scout.edge_health(device_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_edge_health_status ON scout.edge_health(status);
CREATE INDEX IF NOT EXISTS idx_edge_health_timestamp ON scout.edge_health(timestamp);

-- Sync logs
CREATE INDEX IF NOT EXISTS idx_sync_logs_device_id ON scout.sync_logs(device_id);
CREATE INDEX IF NOT EXISTS idx_sync_logs_sync_started ON scout.sync_logs(sync_started);
CREATE INDEX IF NOT EXISTS idx_sync_logs_success ON scout.sync_logs(success);

-- Alerts
CREATE INDEX IF NOT EXISTS idx_alerts_device_id ON scout.alerts(device_id);
CREATE INDEX IF NOT EXISTS idx_alerts_status ON scout.alerts(status);
CREATE INDEX IF NOT EXISTS idx_alerts_created_at ON scout.alerts(created_at);
CREATE INDEX IF NOT EXISTS idx_alerts_severity ON scout.alerts(severity);
CREATE INDEX IF NOT EXISTS idx_alerts_type_status ON scout.alerts(alert_type, status);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE scout.edge_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.edge_health ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.sync_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.alert_notifications ENABLE ROW LEVEL SECURITY;

-- Store owners can only see their devices
CREATE POLICY "store_owners_own_devices" ON scout.edge_devices
    FOR ALL USING (
        store_id IN (
            SELECT store_id FROM scout.user_store_access 
            WHERE user_id = auth.uid()
        )
    );

-- Device health follows device access
CREATE POLICY "device_health_access" ON scout.edge_health
    FOR ALL USING (
        device_id IN (
            SELECT device_id FROM scout.edge_devices
            WHERE store_id IN (
                SELECT store_id FROM scout.user_store_access 
                WHERE user_id = auth.uid()
            )
        )
    );

-- Similar policies for other tables
CREATE POLICY "sync_logs_access" ON scout.sync_logs
    FOR ALL USING (
        device_id IN (
            SELECT device_id FROM scout.edge_devices
            WHERE store_id IN (
                SELECT store_id FROM scout.user_store_access 
                WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "alerts_access" ON scout.alerts
    FOR ALL USING (
        device_id IN (
            SELECT device_id FROM scout.edge_devices
            WHERE store_id IN (
                SELECT store_id FROM scout.user_store_access 
                WHERE user_id = auth.uid()
            )
        )
    );

-- ============================================================
-- GRANT PERMISSIONS
-- ============================================================

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE ON scout.edge_devices TO authenticated;
GRANT SELECT, INSERT ON scout.edge_health TO authenticated;
GRANT SELECT, INSERT ON scout.sync_logs TO authenticated;
GRANT SELECT, UPDATE ON scout.alerts TO authenticated;
GRANT SELECT ON scout.alert_types TO authenticated;
GRANT SELECT, INSERT, UPDATE ON scout.user_notification_preferences TO authenticated;
GRANT SELECT ON scout.notification_templates TO authenticated;

-- Grant permissions to service role (for edge devices)
GRANT ALL ON scout.edge_devices TO service_role;
GRANT ALL ON scout.edge_health TO service_role;
GRANT ALL ON scout.sync_logs TO service_role;
GRANT ALL ON scout.alerts TO service_role;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION scout.fn_register_edge_device TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION scout.fn_update_device_health TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION scout.fn_check_device_alerts TO service_role;

-- Grant access to views
GRANT SELECT ON scout.v_device_dashboard TO authenticated;
GRANT SELECT ON scout.v_store_connectivity TO authenticated;

-- ============================================================
-- COMPLETION NOTIFICATION
-- ============================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔗 SCOUT CONNECTIVITY LAYER DEPLOYED SUCCESSFULLY!';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Components Created:';
    RAISE NOTICE '   • Edge device registry & health monitoring';
    RAISE NOTICE '   • Real-time sync logging & failure tracking';
    RAISE NOTICE '   • Intelligent alert system with 8 alert types';
    RAISE NOTICE '   • Push notification templates & preferences';
    RAISE NOTICE '   • Device management functions';
    RAISE NOTICE '   • Store connectivity dashboards';
    RAISE NOTICE '   • Row-level security policies';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Next Steps:';
    RAISE NOTICE '   1. Deploy Pulser agent: scout-connectivity-agent';
    RAISE NOTICE '   2. Build Scout Ops App with push notifications';
    RAISE NOTICE '   3. Configure edge devices for telemetry';
    RAISE NOTICE '   4. Set up monitoring dashboards';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Ready for 24/7 sari-sari store monitoring!';
    RAISE NOTICE '';
END $$;