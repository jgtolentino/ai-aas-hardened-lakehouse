-- platform/scout/migrations/041_stt_detection_schema.sql
-- Adds Speech-to-Text brand detection (no audio storage!)
-- Privacy-preserving: Only stores detection results, never audio

-- Create STT brand dictionary for Philippine market
CREATE TABLE IF NOT EXISTS scout.stt_brand_dictionary (
    id SERIAL PRIMARY KEY,
    brand_canonical VARCHAR(255) NOT NULL,
    phonetic_variant VARCHAR(255) NOT NULL,
    variant_type VARCHAR(50) CHECK (variant_type IN ('exact', 'nickname', 'mispronunciation')),
    confidence_score NUMERIC(3,2),
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create STT detection results table (NO AUDIO STORED!)
CREATE TABLE IF NOT EXISTS scout.stt_detections (
    detection_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id VARCHAR(100),
    device_id VARCHAR(100),
    
    -- Detection results only (no audio!)
    brands_detected TEXT[],
    products_mentioned TEXT[],
    confidence_score NUMERIC(3,2),
    detection_method VARCHAR(50),
    
    -- Processing metadata
    processing_time_ms INT,
    model_version VARCHAR(50),
    detected_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_stt_brand_canonical ON scout.stt_brand_dictionary(brand_canonical);
CREATE INDEX IF NOT EXISTS idx_stt_brand_phonetic ON scout.stt_brand_dictionary(phonetic_variant);
CREATE INDEX IF NOT EXISTS idx_stt_detections_transaction ON scout.stt_detections(transaction_id);
CREATE INDEX IF NOT EXISTS idx_stt_detections_device ON scout.stt_detections(device_id);
CREATE INDEX IF NOT EXISTS idx_stt_detections_timestamp ON scout.stt_detections(detected_at);

-- Populate brand dictionary with common Philippine brands
INSERT INTO scout.stt_brand_dictionary (brand_canonical, phonetic_variant, variant_type, confidence_score) VALUES
    -- Instant Noodles
    ('Lucky Me', 'lucky me', 'exact', 0.95),
    ('Lucky Me', 'laki mi', 'mispronunciation', 0.75),
    ('Lucky Me', 'lucky', 'nickname', 0.80),
    ('Payless', 'payless', 'exact', 0.95),
    ('Payless', 'peyless', 'mispronunciation', 0.85),
    ('Nissin', 'nissin', 'exact', 0.95),
    ('Nissin', 'nisin', 'mispronunciation', 0.80),
    
    -- Beverages
    ('San Miguel', 'san miguel', 'exact', 0.95),
    ('San Miguel', 'san mig', 'nickname', 0.85),
    ('San Miguel', 'sanmig', 'nickname', 0.85),
    ('Coca-Cola', 'coca cola', 'exact', 0.95),
    ('Coca-Cola', 'coke', 'nickname', 0.90),
    ('Coca-Cola', 'koka', 'mispronunciation', 0.70),
    ('Pepsi', 'pepsi', 'exact', 0.95),
    ('Pepsi', 'peps', 'nickname', 0.80),
    ('Royal', 'royal', 'exact', 0.95),
    ('Royal', 'royal tru', 'exact', 0.90),
    ('C2', 'c two', 'exact', 0.95),
    ('C2', 'see two', 'mispronunciation', 0.85),
    
    -- Coffee
    ('Nescafe', 'nescafe', 'exact', 0.95),
    ('Nescafe', 'nes cafe', 'mispronunciation', 0.85),
    ('Nescafe', 'neskape', 'mispronunciation', 0.75),
    ('Kopiko', 'kopiko', 'exact', 0.95),
    ('Kopiko', 'kopeko', 'mispronunciation', 0.80),
    ('Great Taste', 'great taste', 'exact', 0.95),
    ('Great Taste', 'greyt teyts', 'mispronunciation', 0.75),
    
    -- Snacks
    ('Jack n Jill', 'jack and jill', 'exact', 0.95),
    ('Jack n Jill', 'jack jill', 'nickname', 0.85),
    ('Oishi', 'oishi', 'exact', 0.95),
    ('Oishi', 'oyshi', 'mispronunciation', 0.80),
    ('Piattos', 'piattos', 'exact', 0.95),
    ('Piattos', 'pyatos', 'mispronunciation', 0.80),
    ('Nova', 'nova', 'exact', 0.95),
    ('Chippy', 'chippy', 'exact', 0.95),
    ('Chippy', 'chipi', 'mispronunciation', 0.80),
    
    -- Personal Care
    ('Safeguard', 'safeguard', 'exact', 0.95),
    ('Safeguard', 'seyfgard', 'mispronunciation', 0.75),
    ('Head & Shoulders', 'head and shoulders', 'exact', 0.95),
    ('Head & Shoulders', 'head shoulders', 'nickname', 0.85),
    ('Palmolive', 'palmolive', 'exact', 0.95),
    ('Palmolive', 'palmoliv', 'mispronunciation', 0.85),
    ('Colgate', 'colgate', 'exact', 0.95),
    ('Colgate', 'kolgeyt', 'mispronunciation', 0.80),
    
    -- Household
    ('Tide', 'tide', 'exact', 0.95),
    ('Tide', 'tayd', 'mispronunciation', 0.80),
    ('Ariel', 'ariel', 'exact', 0.95),
    ('Ariel', 'aryel', 'mispronunciation', 0.85),
    ('Downy', 'downy', 'exact', 0.95),
    ('Downy', 'dawni', 'mispronunciation', 0.80),
    ('Surf', 'surf', 'exact', 0.95),
    ('Breeze', 'breeze', 'exact', 0.95),
    ('Breeze', 'briz', 'mispronunciation', 0.80),
    
    -- Cigarettes (common in sari-sari)
    ('Marlboro', 'marlboro', 'exact', 0.95),
    ('Marlboro', 'marlbor', 'mispronunciation', 0.85),
    ('Marlboro', 'boro', 'nickname', 0.75),
    ('Fortune', 'fortune', 'exact', 0.95),
    ('Fortune', 'portun', 'mispronunciation', 0.80),
    ('Hope', 'hope', 'exact', 0.95),
    
    -- Local Favorites
    ('Milo', 'milo', 'exact', 0.95),
    ('Milo', 'maylo', 'mispronunciation', 0.85),
    ('Bear Brand', 'bear brand', 'exact', 0.95),
    ('Bear Brand', 'ber brand', 'mispronunciation', 0.80),
    ('Alaska', 'alaska', 'exact', 0.95),
    ('Magnolia', 'magnolia', 'exact', 0.95),
    ('Magnolia', 'magnolya', 'mispronunciation', 0.85),
    ('Purefoods', 'purefoods', 'exact', 0.95),
    ('Purefoods', 'pyurpuds', 'mispronunciation', 0.75),
    ('CDO', 'c d o', 'exact', 0.95),
    ('CDO', 'cdo', 'exact', 0.90),
    ('Argentina', 'argentina', 'exact', 0.95),
    ('Argentina', 'arhentina', 'mispronunciation', 0.85)
ON CONFLICT DO NOTHING;

-- Function to process STT detection
CREATE OR REPLACE FUNCTION scout.process_stt_detection(
    p_transaction_id VARCHAR,
    p_device_id VARCHAR,
    p_brands TEXT[],
    p_products TEXT[],
    p_confidence NUMERIC,
    p_processing_time_ms INT,
    p_model_version VARCHAR DEFAULT 'whisper-1.0'
)
RETURNS UUID AS $$
DECLARE
    v_detection_id UUID;
BEGIN
    INSERT INTO scout.stt_detections (
        transaction_id,
        device_id,
        brands_detected,
        products_mentioned,
        confidence_score,
        detection_method,
        processing_time_ms,
        model_version
    ) VALUES (
        p_transaction_id,
        p_device_id,
        p_brands,
        p_products,
        p_confidence,
        'whisper_stt',
        p_processing_time_ms,
        p_model_version
    ) RETURNING detection_id INTO v_detection_id;
    
    RETURN v_detection_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to match brand from phonetic input
CREATE OR REPLACE FUNCTION scout.match_brand_phonetic(p_phonetic_input TEXT)
RETURNS TABLE(
    brand_canonical VARCHAR,
    confidence_score NUMERIC,
    variant_type VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sbd.brand_canonical,
        sbd.confidence_score,
        sbd.variant_type
    FROM scout.stt_brand_dictionary sbd
    WHERE LOWER(sbd.phonetic_variant) = LOWER(p_phonetic_input)
       OR LOWER(sbd.phonetic_variant) LIKE '%' || LOWER(p_phonetic_input) || '%'
    ORDER BY 
        CASE WHEN LOWER(sbd.phonetic_variant) = LOWER(p_phonetic_input) THEN 1 ELSE 2 END,
        sbd.confidence_score DESC
    LIMIT 3;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- View for STT detection analytics
CREATE OR REPLACE VIEW scout.v_stt_brand_performance AS
SELECT 
    DATE(detected_at) as detection_date,
    brand,
    COUNT(*) as detection_count,
    AVG(confidence_score) as avg_confidence,
    COUNT(DISTINCT device_id) as unique_devices,
    COUNT(DISTINCT transaction_id) as unique_transactions
FROM scout.stt_detections,
     UNNEST(brands_detected) as brand
WHERE detected_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(detected_at), brand
ORDER BY detection_date DESC, detection_count DESC;

-- Grant permissions
GRANT SELECT ON scout.stt_brand_dictionary TO authenticated;
GRANT SELECT ON scout.stt_detections TO authenticated;
GRANT SELECT ON scout.v_stt_brand_performance TO authenticated;
GRANT EXECUTE ON FUNCTION scout.process_stt_detection TO authenticated;
GRANT EXECUTE ON FUNCTION scout.match_brand_phonetic TO authenticated;