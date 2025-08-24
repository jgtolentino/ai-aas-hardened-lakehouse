-- ============================================================
-- Migration 027: STT Detection Schema
-- Adds Speech-to-Text brand detection (no audio storage!)
-- ============================================================

-- STT brand dictionary for phonetic matching
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

-- STT detection results (no audio storage)
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

-- Indexes
CREATE INDEX idx_stt_brand_canonical ON scout.stt_brand_dictionary(brand_canonical);
CREATE INDEX idx_stt_brand_phonetic ON scout.stt_brand_dictionary(phonetic_variant);
CREATE INDEX idx_stt_detections_transaction ON scout.stt_detections(transaction_id);
CREATE INDEX idx_stt_detections_device ON scout.stt_detections(device_id);
CREATE INDEX idx_stt_detections_timestamp ON scout.stt_detections(detected_at);

-- Sample brand dictionary for Philippines
INSERT INTO scout.stt_brand_dictionary (brand_canonical, phonetic_variant, variant_type, confidence_score) VALUES
    ('Lucky Me', 'lucky me', 'exact', 0.95),
    ('Lucky Me', 'laki mi', 'mispronunciation', 0.75),
    ('San Miguel', 'san miguel', 'exact', 0.95),
    ('San Miguel', 'san mig', 'nickname', 0.85),
    ('Coca-Cola', 'coca cola', 'exact', 0.95),
    ('Coca-Cola', 'coke', 'nickname', 0.90),
    ('Coca-Cola', 'koka', 'mispronunciation', 0.70),
    ('Nestle', 'nestle', 'exact', 0.95),
    ('Nestle', 'nesle', 'mispronunciation', 0.80),
    ('Palmolive', 'palmolive', 'exact', 0.95),
    ('Palmolive', 'palmoliv', 'mispronunciation', 0.85),
    ('Safeguard', 'safeguard', 'exact', 0.95),
    ('Safeguard', 'safgard', 'mispronunciation', 0.80),
    ('Colgate', 'colgate', 'exact', 0.95),
    ('Colgate', 'kolgeyt', 'mispronunciation', 0.75),
    ('Head & Shoulders', 'head and shoulders', 'exact', 0.95),
    ('Head & Shoulders', 'head shoulders', 'nickname', 0.85),
    ('Tide', 'tide', 'exact', 0.95),
    ('Tide', 'tayd', 'mispronunciation', 0.80),
    ('Ariel', 'ariel', 'exact', 0.95),
    ('Ariel', 'aryel', 'mispronunciation', 0.85),
    ('Breeze', 'breeze', 'exact', 0.95),
    ('Breeze', 'briz', 'nickname', 0.85)
ON CONFLICT DO NOTHING;