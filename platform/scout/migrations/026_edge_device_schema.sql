-- ============================================================
-- Migration 026: Edge Device Schema
-- Adds edge device monitoring and health tracking from Scout v5.2
-- ============================================================

-- Edge device health monitoring table
CREATE TABLE IF NOT EXISTS scout.edge_health (
    device_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_name VARCHAR(255),
    store_id VARCHAR(100),
    device_type VARCHAR(50) CHECK (device_type IN ('raspberry_pi', 'android_tablet', 'nvidia_jetson')),
    
    -- Connectivity
    is_online BOOLEAN DEFAULT FALSE,
    connection_type VARCHAR(50),
    ip_address INET,
    latency_ms NUMERIC(8,2),
    bandwidth_mbps NUMERIC(8,2),
    
    -- System metrics
    cpu_usage NUMERIC(5,2),
    memory_usage NUMERIC(5,2),
    disk_usage NUMERIC(5,2),
    temperature_celsius NUMERIC(5,2),
    
    -- Timestamps
    last_seen TIMESTAMP,
    last_heartbeat TIMESTAMP,
    last_sync TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Edge installation checks table
CREATE TABLE IF NOT EXISTS scout.edge_installation_checks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID REFERENCES scout.edge_health(device_id),
    device_serial VARCHAR(100),
    
    -- Hardware checks
    hardware_cpu_cores INT,
    hardware_ram_gb NUMERIC(5,2),
    hardware_storage_gb NUMERIC(8,2),
    hardware_microphone_detected BOOLEAN,
    hardware_speaker_detected BOOLEAN,
    hardware_check_passed BOOLEAN,
    
    -- Network checks
    network_connectivity BOOLEAN,
    network_api_reachable BOOLEAN,
    network_bandwidth_mbps NUMERIC(8,2),
    network_latency_ms NUMERIC(8,2),
    network_check_passed BOOLEAN,
    
    -- Software checks
    os_compatible BOOLEAN,
    os_version VARCHAR(50),
    python_version VARCHAR(20),
    required_libraries JSONB,
    software_check_passed BOOLEAN,
    
    -- Permission checks
    permission_audio_record BOOLEAN,
    permission_network_access BOOLEAN,
    permissions_check_passed BOOLEAN,
    
    -- Master data checks
    master_data_loaded BOOLEAN,
    master_brands_count INT,
    master_products_count INT,
    master_categories_count INT,
    master_data_check_passed BOOLEAN,
    
    -- Model deployment
    stt_model_loaded BOOLEAN,
    stt_model_version VARCHAR(50),
    brand_model_loaded BOOLEAN,
    brand_model_version VARCHAR(50),
    models_check_passed BOOLEAN,
    
    -- Post-installation tests
    test_audio_capture BOOLEAN,
    test_stt_processing BOOLEAN,
    test_brand_detection BOOLEAN,
    test_data_sync BOOLEAN,
    test_api_communication BOOLEAN,
    functional_tests_passed BOOLEAN,
    
    -- Performance benchmarks
    benchmark_stt_speed_ms NUMERIC(8,2),
    benchmark_brand_detection_ms NUMERIC(8,2),
    benchmark_sync_speed_mbps NUMERIC(8,2),
    performance_check_passed BOOLEAN,
    
    -- Overall status
    installation_status VARCHAR(50),
    installation_score NUMERIC(5,2),
    ready_for_production BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_edge_health_store_id ON scout.edge_health(store_id);
CREATE INDEX idx_edge_health_is_online ON scout.edge_health(is_online);
CREATE INDEX idx_edge_health_last_seen ON scout.edge_health(last_seen);
CREATE INDEX idx_edge_installation_device_id ON scout.edge_installation_checks(device_id);

-- RPC Functions for edge management
CREATE OR REPLACE FUNCTION scout.get_edge_device_status(p_device_id UUID DEFAULT NULL)
RETURNS JSON AS $$
BEGIN
    RETURN json_build_object(
        'devices', (
            SELECT json_agg(row_to_json(d))
            FROM (
                SELECT 
                    device_id,
                    device_name,
                    store_id,
                    device_type,
                    is_online,
                    last_seen,
                    cpu_usage,
                    memory_usage,
                    disk_usage,
                    temperature_celsius
                FROM scout.edge_health
                WHERE device_id = COALESCE(p_device_id, device_id)
                ORDER BY last_seen DESC
            ) d
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION scout.run_installation_check(p_device_serial VARCHAR)
RETURNS JSON AS $$
DECLARE
    v_device_id UUID;
    v_check_id UUID;
BEGIN
    -- Create or get device
    INSERT INTO scout.edge_health (device_name, device_type)
    VALUES (p_device_serial, 'raspberry_pi')
    ON CONFLICT DO NOTHING
    RETURNING device_id INTO v_device_id;
    
    -- Create installation check record
    INSERT INTO scout.edge_installation_checks (device_id, device_serial)
    VALUES (v_device_id, p_device_serial)
    RETURNING id INTO v_check_id;
    
    RETURN json_build_object(
        'check_id', v_check_id,
        'device_id', v_device_id,
        'status', 'initiated'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION scout.force_edge_sync(p_device_id UUID)
RETURNS JSON AS $$
BEGIN
    UPDATE scout.edge_health
    SET last_sync = NOW()
    WHERE device_id = p_device_id;
    
    RETURN json_build_object(
        'device_id', p_device_id,
        'sync_initiated', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;