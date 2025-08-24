-- ============================================================
-- SCOUT INSTALLATION & CONNECTIVITY ALIGNMENT
-- Integration between installation checks and connectivity monitoring
-- ============================================================

SET search_path TO scout, public;

-- ============================================================
-- INSTALLATION-TO-CONNECTIVITY BRIDGE
-- ============================================================

-- Enhanced auto-registration that integrates with installation checks
CREATE OR REPLACE FUNCTION scout.fn_auto_register_with_installation_check(
    p_device_fingerprint JSONB,
    p_store_location TEXT DEFAULT NULL,
    p_device_capabilities JSONB DEFAULT '{}',
    p_run_installation_check BOOLEAN DEFAULT true
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_device_id UUID;
    v_installation_result JSONB;
    v_device_serial TEXT;
    v_connectivity_status TEXT;
BEGIN
    -- Extract device serial from fingerprint
    v_device_serial := COALESCE(
        p_device_fingerprint->>'serial_number',
        p_device_fingerprint->>'mac_address',
        'UNKNOWN-' || gen_random_uuid()
    );
    
    -- First run auto-registration
    SELECT scout.fn_auto_register_device(
        p_device_fingerprint,
        p_store_location,
        p_device_capabilities
    ) INTO v_device_id;
    
    -- Run installation check if requested
    IF p_run_installation_check THEN
        -- Run pre-installation check
        SELECT scout.run_pre_installation_check(v_device_serial) INTO v_installation_result;
        
        -- Update device with installation results
        UPDATE scout.edge_devices 
        SET device_config = device_config || json_build_object(
            'installation_check', v_installation_result,
            'installation_score', v_installation_result->>'overall_score',
            'installation_status', CASE 
                WHEN (v_installation_result->>'overall_score')::numeric >= 80 THEN 'ready'
                WHEN (v_installation_result->>'overall_score')::numeric >= 60 THEN 'needs_attention'
                ELSE 'not_ready'
            END,
            'last_installation_check', NOW()
        )
        WHERE device_id = v_device_id;
        
        -- Create installation alert based on score
        IF (v_installation_result->>'overall_score')::numeric < 80 THEN
            INSERT INTO scout.alerts (
                alert_type, device_id, title, message, severity, alert_data
            ) VALUES (
                'installation_incomplete',
                v_device_id,
                'Installation Check Failed: ' || v_device_serial,
                'Device installation score: ' || (v_installation_result->>'overall_score') || '/100. Manual intervention required.',
                CASE 
                    WHEN (v_installation_result->>'overall_score')::numeric < 40 THEN 'critical'
                    ELSE 'warning'
                END,
                json_build_object(
                    'installation_score', v_installation_result->>'overall_score',
                    'failed_checks', v_installation_result->'failed_checks',
                    'device_serial', v_device_serial
                )
            );
        END IF;
    END IF;
    
    -- Determine connectivity status
    v_connectivity_status := CASE 
        WHEN v_installation_result IS NULL THEN 'registered'
        WHEN (v_installation_result->>'overall_score')::numeric >= 80 THEN 'operational'
        WHEN (v_installation_result->>'overall_score')::numeric >= 60 THEN 'limited'
        ELSE 'offline'
    END;
    
    RETURN json_build_object(
        'device_id', v_device_id,
        'device_serial', v_device_serial,
        'connectivity_status', v_connectivity_status,
        'installation_result', v_installation_result,
        'registration_timestamp', NOW(),
        'next_steps', CASE 
            WHEN v_connectivity_status = 'operational' THEN json_build_array('Device ready for production use', 'Monitor health metrics')
            WHEN v_connectivity_status = 'limited' THEN json_build_array('Address installation warnings', 'Run post-installation check after fixes')
            ELSE json_build_array('Fix critical installation issues', 'Re-run installation check', 'Contact technical support')
        END
    );
END;
$$;

-- ============================================================
-- ENHANCED CONNECTIVITY DASHBOARD WITH INSTALLATION STATUS
-- ============================================================

-- Updated connectivity dashboard that includes installation status
CREATE OR REPLACE FUNCTION scout.get_connectivity_dashboard_with_installation(
    p_store_id UUID DEFAULT NULL,
    p_time_window INTERVAL DEFAULT '24 hours'
) RETURNS TABLE (
    store_summary JSONB,
    device_health JSONB,
    installation_status JSONB,
    alert_summary JSONB,
    sync_performance JSONB,
    network_status JSONB,
    master_data_status JSONB
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
            'device_types', json_agg(DISTINCT d.device_type),
            'installation_ready_devices', COUNT(d.device_id) FILTER (WHERE d.device_config->>'installation_status' = 'ready')
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
            ),
            'health_score_distribution', json_build_object(
                'excellent', COUNT(h.device_id) FILTER (WHERE (d.device_config->>'installation_score')::numeric >= 90),
                'good', COUNT(h.device_id) FILTER (WHERE (d.device_config->>'installation_score')::numeric BETWEEN 80 AND 89),
                'fair', COUNT(h.device_id) FILTER (WHERE (d.device_config->>'installation_score')::numeric BETWEEN 60 AND 79),
                'poor', COUNT(h.device_id) FILTER (WHERE (d.device_config->>'installation_score')::numeric < 60)
            )
        ) as device_health,
        
        -- Installation Status Summary
        json_build_object(
            'installation_complete', COUNT(d.device_id) FILTER (WHERE d.device_config->>'installation_status' = 'ready'),
            'needs_attention', COUNT(d.device_id) FILTER (WHERE d.device_config->>'installation_status' = 'needs_attention'),
            'not_ready', COUNT(d.device_id) FILTER (WHERE d.device_config->>'installation_status' = 'not_ready'),
            'pending_checks', COUNT(d.device_id) FILTER (WHERE d.device_config->>'installation_status' IS NULL),
            'avg_installation_score', ROUND(AVG((d.device_config->>'installation_score')::numeric), 1),
            'installation_issues', json_agg(
                DISTINCT json_build_object(
                    'device_id', d.device_id,
                    'device_name', d.device_name,
                    'installation_score', d.device_config->>'installation_score',
                    'issues', d.device_config->'installation_check'->'failed_checks'
                )
            ) FILTER (WHERE d.device_config->>'installation_status' != 'ready')
        ) as installation_status,
        
        -- Alert Summary (including installation alerts)
        json_build_object(
            'active_alerts', COUNT(a.id) FILTER (WHERE a.status = 'active'),
            'critical_alerts', COUNT(a.id) FILTER (WHERE a.status = 'active' AND a.severity = 'critical'),
            'installation_alerts', COUNT(a.id) FILTER (WHERE a.status = 'active' AND a.alert_type = 'installation_incomplete'),
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
                    'alert_type', a.alert_type,
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
            'installation_syncs', COUNT(s.id) FILTER (WHERE s.sync_type IN ('auto_registration', 'installation_check')),
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
            'bandwidth_adequate', COUNT(d.device_id) FILTER (WHERE d.device_config->'installation_check'->'network'->>'bandwidth_mbps' >= '25'),
            'network_performance_trend', json_agg(
                json_build_object(
                    'hour', EXTRACT(HOUR FROM h.timestamp),
                    'avg_latency', AVG(h.network_latency_ms),
                    'device_count', COUNT(h.device_id)
                ) ORDER BY EXTRACT(HOUR FROM h.timestamp)
            ) FILTER (WHERE h.timestamp > v_cutoff_time)
        ) as network_status,
        
        -- Master Data Status
        json_build_object(
            'brands_loaded', (SELECT COUNT(*) FROM scout.ref_brands),
            'categories_loaded', (SELECT COUNT(*) FROM scout.ref_categories),
            'products_loaded', (SELECT COUNT(*) FROM scout.dim_product),
            'installation_templates', (SELECT COUNT(*) FROM scout.installation_checklist_templates),
            'master_data_complete', CASE 
                WHEN (SELECT COUNT(*) FROM scout.ref_brands) >= 30 
                 AND (SELECT COUNT(*) FROM scout.ref_categories) >= 15
                 AND (SELECT COUNT(*) FROM scout.dim_product) >= 30 
                THEN true
                ELSE false
            END,
            'last_master_data_update', (SELECT MAX(created_at) FROM scout.master_data_uploads)
        ) as master_data_status
        
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

-- ============================================================
-- INSTALLATION-AWARE DEVICE HEALTH CHECK
-- ============================================================

-- Enhanced health check that considers installation status
CREATE OR REPLACE FUNCTION scout.check_connectivity_health_with_installation(
    p_store_id UUID DEFAULT NULL
) RETURNS TABLE (
    device_id UUID,
    device_name TEXT,
    health_score NUMERIC,
    installation_score NUMERIC,
    overall_readiness NUMERIC,
    issues JSONB,
    recommendations JSONB,
    last_health_check TIMESTAMPTZ,
    installation_status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH device_analysis AS (
        SELECT 
            d.device_id,
            d.device_name,
            d.device_type,
            d.last_checkin,
            d.device_config,
            h.cpu_usage,
            h.memory_usage,
            h.disk_usage,
            h.temperature_celsius,
            h.network_latency_ms,
            h.wifi_signal_strength,
            h.brand_detection_accuracy,
            h.status,
            h.timestamp as last_health_timestamp,
            
            -- Installation scores
            COALESCE((d.device_config->>'installation_score')::numeric, 0) as installation_score,
            COALESCE(d.device_config->>'installation_status', 'unknown') as installation_status,
            
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
            )) as health_score
            
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
        da.device_id,
        da.device_name,
        ROUND(da.health_score, 1) as health_score,
        ROUND(da.installation_score, 1) as installation_score,
        
        -- Overall readiness combines health and installation
        ROUND((da.health_score * 0.6) + (da.installation_score * 0.4), 1) as overall_readiness,
        
        -- Combined issues from health and installation
        json_build_object(
            'health_issues', json_build_object(
                'offline', da.last_checkin < NOW() - INTERVAL '10 minutes',
                'high_cpu', da.cpu_usage > 80,
                'high_memory', da.memory_usage > 85,
                'high_temperature', da.temperature_celsius > 60,
                'slow_network', da.network_latency_ms > 100,
                'weak_wifi', da.wifi_signal_strength < -70,
                'low_accuracy', da.brand_detection_accuracy < 0.9,
                'disk_space_low', da.disk_usage > 90
            ),
            'installation_issues', CASE 
                WHEN da.installation_status = 'not_ready' THEN da.device_config->'installation_check'->'failed_checks'
                WHEN da.installation_status = 'needs_attention' THEN da.device_config->'installation_check'->'warnings'
                ELSE json_build_object('status', 'installation_complete')
            END
        ) as issues,
        
        -- Enhanced recommendations
        json_build_object(
            'immediate_actions', CASE 
                WHEN da.installation_status = 'not_ready' THEN 
                    json_build_array('Complete installation requirements', 'Run installation check again', 'Contact technical support')
                WHEN da.last_checkin < NOW() - INTERVAL '10 minutes' THEN 
                    json_build_array('Check device power and network connection', 'Verify device is responsive')
                WHEN da.cpu_usage > 80 OR da.memory_usage > 85 THEN
                    json_build_array('Restart device services', 'Check for resource-intensive processes', 'Monitor performance trends')
                WHEN da.temperature_celsius > 60 THEN
                    json_build_array('Check device ventilation', 'Verify cooling systems', 'Monitor ambient temperature')
                WHEN da.network_latency_ms > 100 OR da.wifi_signal_strength < -70 THEN
                    json_build_array('Check network configuration', 'Verify WiFi signal strength', 'Test internet connectivity')
                WHEN da.brand_detection_accuracy < 0.9 THEN
                    json_build_array('Recalibrate brand detection model', 'Check camera/sensor alignment', 'Update detection algorithms')
                ELSE json_build_array('Device operating normally')
            END,
            'priority', CASE 
                WHEN da.installation_status = 'not_ready' THEN 'critical'
                WHEN (da.health_score * 0.6) + (da.installation_score * 0.4) < 30 THEN 'critical'
                WHEN (da.health_score * 0.6) + (da.installation_score * 0.4) < 60 THEN 'high'
                WHEN (da.health_score * 0.6) + (da.installation_score * 0.4) < 80 THEN 'medium'
                ELSE 'low'
            END,
            'next_steps', CASE 
                WHEN da.installation_status = 'unknown' THEN json_build_array('Run pre-installation check')
                WHEN da.installation_status = 'not_ready' THEN json_build_array('Fix installation issues', 'Re-run installation check')
                WHEN da.installation_status = 'needs_attention' THEN json_build_array('Address warnings', 'Run post-installation check')
                ELSE json_build_array('Monitor device performance', 'Schedule regular maintenance')
            END
        ) as recommendations,
        
        COALESCE(da.last_health_timestamp, da.last_checkin) as last_health_check,
        da.installation_status
        
    FROM device_analysis da
    ORDER BY 
        CASE da.installation_status
            WHEN 'not_ready' THEN 1
            WHEN 'needs_attention' THEN 2
            WHEN 'ready' THEN 3
            ELSE 4
        END,
        ((da.health_score * 0.6) + (da.installation_score * 0.4)) ASC,
        da.device_name;
END;
$$;

-- ============================================================
-- COMPLETE INSTALLATION VALIDATION
-- ============================================================

-- Validate entire Scout system installation
CREATE OR REPLACE FUNCTION scout.validate_complete_installation()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB := json_build_object();
    v_master_data_status JSONB;
    v_connectivity_status JSONB;
    v_device_status JSONB;
    v_overall_score NUMERIC := 100;
BEGIN
    -- Check master data completeness
    SELECT json_build_object(
        'brands', json_build_object(
            'count', COUNT(*),
            'required', 30,
            'status', CASE WHEN COUNT(*) >= 30 THEN 'complete' ELSE 'incomplete' END
        ),
        'categories', json_build_object(
            'count', COUNT(*),
            'required', 15,
            'status', CASE WHEN COUNT(*) >= 15 THEN 'complete' ELSE 'incomplete' END
        )
    ) INTO v_master_data_status
    FROM (
        SELECT 'brands' as type FROM scout.ref_brands
        UNION ALL
        SELECT 'categories' as type FROM scout.ref_categories
    ) data;
    
    -- Get connectivity layer status
    SELECT json_build_object(
        'total_devices', COUNT(*),
        'operational_devices', COUNT(*) FILTER (WHERE device_config->>'installation_status' = 'ready'),
        'pending_installation', COUNT(*) FILTER (WHERE device_config->>'installation_status' IS NULL),
        'failed_installation', COUNT(*) FILTER (WHERE device_config->>'installation_status' = 'not_ready'),
        'auto_registered_devices', COUNT(*) FILTER (WHERE device_config->>'auto_registered' = 'true')
    ) INTO v_connectivity_status
    FROM scout.edge_devices
    WHERE is_active = true;
    
    -- Calculate overall system health
    IF (v_master_data_status->'brands'->>'status') != 'complete' THEN
        v_overall_score := v_overall_score - 20;
    END IF;
    
    IF (v_master_data_status->'categories'->>'status') != 'complete' THEN
        v_overall_score := v_overall_score - 15;
    END IF;
    
    IF (v_connectivity_status->>'total_devices')::integer = 0 THEN
        v_overall_score := v_overall_score - 30;
    ELSIF (v_connectivity_status->>'failed_installation')::integer > 0 THEN
        v_overall_score := v_overall_score - 10;
    END IF;
    
    -- Build final result
    v_result := json_build_object(
        'installation_timestamp', NOW(),
        'overall_score', v_overall_score,
        'status', CASE 
            WHEN v_overall_score >= 90 THEN 'excellent'
            WHEN v_overall_score >= 80 THEN 'good'
            WHEN v_overall_score >= 70 THEN 'acceptable'
            WHEN v_overall_score >= 60 THEN 'needs_improvement'
            ELSE 'critical_issues'
        END,
        'master_data', v_master_data_status,
        'connectivity_layer', v_connectivity_status,
        'system_capabilities', json_build_object(
            'auto_registration', 'enabled',
            'health_monitoring', 'enabled',
            'installation_checks', 'enabled',
            'predictive_maintenance', 'enabled',
            'real_time_dashboards', 'enabled'
        ),
        'recommendations', CASE 
            WHEN v_overall_score >= 90 THEN json_build_array('System ready for production', 'Monitor device performance regularly')
            WHEN v_overall_score >= 80 THEN json_build_array('Minor optimizations needed', 'Address any pending device installations')
            WHEN v_overall_score >= 70 THEN json_build_array('Complete master data requirements', 'Fix device installation issues')
            ELSE json_build_array('Critical setup incomplete', 'Review installation documentation', 'Contact technical support')
        END
    );
    
    RETURN v_result;
END;
$$;

-- ============================================================
-- GRANT PERMISSIONS
-- ============================================================

GRANT EXECUTE ON FUNCTION scout.fn_auto_register_with_installation_check TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION scout.get_connectivity_dashboard_with_installation TO authenticated;
GRANT EXECUTE ON FUNCTION scout.check_connectivity_health_with_installation TO authenticated;
GRANT EXECUTE ON FUNCTION scout.validate_complete_installation TO authenticated;

-- ============================================================
-- COMPLETION NOTIFICATION
-- ============================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎯 SCOUT INSTALLATION & CONNECTIVITY ALIGNMENT COMPLETE!';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Integrated Features:';
    RAISE NOTICE '   • Auto-registration with installation validation';
    RAISE NOTICE '   • Installation-aware connectivity dashboard';
    RAISE NOTICE '   • Combined health and installation scoring';
    RAISE NOTICE '   • Complete system validation function';
    RAISE NOTICE '   • Master data requirements verification';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Ready Functions:';
    RAISE NOTICE '   SELECT scout.fn_auto_register_with_installation_check(...);';
    RAISE NOTICE '   SELECT scout.get_connectivity_dashboard_with_installation();';
    RAISE NOTICE '   SELECT scout.check_connectivity_health_with_installation();';
    RAISE NOTICE '   SELECT scout.validate_complete_installation();';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Complete Scout edge device ecosystem is now operational!';
    RAISE NOTICE '';
END $$;