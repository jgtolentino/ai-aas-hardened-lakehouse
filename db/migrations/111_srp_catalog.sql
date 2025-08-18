-- SRP (Suggested Retail Price) Catalog System
-- Reference prices from manufacturers/distributors

CREATE SCHEMA IF NOT EXISTS reference;

-- SRP prices table
CREATE TABLE IF NOT EXISTS reference.srp_prices (
    id SERIAL PRIMARY KEY,
    source VARCHAR(50) NOT NULL, -- e.g., 'NESTLE-PH', 'UNILEVER-PH'
    brand VARCHAR(100) NOT NULL,
    product VARCHAR(255) NOT NULL,
    variant VARCHAR(100),
    gtin VARCHAR(20), -- Global Trade Item Number (barcode)
    sku VARCHAR(50),
    pack_size VARCHAR(50),
    pack_unit VARCHAR(20),
    srp DECIMAL(10,2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'PHP',
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE,
    is_current BOOLEAN DEFAULT TRUE,
    
    -- Metadata
    source_url TEXT,
    scraped_at TIMESTAMP,
    confidence DECIMAL(3,2), -- How confident we are in this SRP
    notes TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Prevent duplicates
    UNIQUE(source, gtin, effective_date)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_srp_gtin ON reference.srp_prices(gtin) WHERE is_current = TRUE;
CREATE INDEX IF NOT EXISTS idx_srp_brand_product ON reference.srp_prices(brand, product) WHERE is_current = TRUE;
CREATE INDEX IF NOT EXISTS idx_srp_sku ON reference.srp_prices(sku) WHERE is_current = TRUE;
CREATE INDEX IF NOT EXISTS idx_srp_source ON reference.srp_prices(source);
CREATE INDEX IF NOT EXISTS idx_srp_effective ON reference.srp_prices(effective_date DESC);

-- Latest SRP view
CREATE OR REPLACE VIEW scout.v_srp_latest AS
WITH ranked_srp AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY COALESCE(gtin, brand || ':' || product)
            ORDER BY effective_date DESC, scraped_at DESC NULLS LAST
        ) as rn
    FROM reference.srp_prices
    WHERE is_current = TRUE
        AND (expiry_date IS NULL OR expiry_date >= CURRENT_DATE)
)
SELECT 
    id,
    source,
    brand,
    product,
    variant,
    gtin,
    sku,
    pack_size,
    pack_unit,
    srp,
    currency,
    effective_date,
    confidence,
    source_url
FROM ranked_srp
WHERE rn = 1;

-- Add SRP tracking to price_snapshot
ALTER TABLE scout.price_snapshot 
    ADD COLUMN IF NOT EXISTS is_srp BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS srp_source VARCHAR(50),
    ADD COLUMN IF NOT EXISTS srp_confidence DECIMAL(3,2);

-- Job types enum extension for worker
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'job_kind') THEN
        CREATE TYPE job_kind AS ENUM ('scrape', 'process', 'srp', 'ml_eval');
    ELSE
        -- Add 'srp' if not exists
        ALTER TYPE job_kind ADD VALUE IF NOT EXISTS 'srp';
        ALTER TYPE job_kind ADD VALUE IF NOT EXISTS 'ml_eval';
    END IF;
END $$;

-- Jobs table for worker (if not exists)
CREATE TABLE IF NOT EXISTS scout.jobs (
    id SERIAL PRIMARY KEY,
    kind job_kind NOT NULL,
    payload JSONB NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    error TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_jobs_pending ON scout.jobs(kind, status) WHERE status = 'pending';

-- Grants
GRANT USAGE ON SCHEMA reference TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA reference TO PUBLIC;
GRANT SELECT ON scout.v_srp_latest TO PUBLIC;