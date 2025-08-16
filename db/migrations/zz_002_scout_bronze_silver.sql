-- Scout Data Model: Bronze and Silver layers
-- Bronze = raw ingestion, Silver = typed/validated

BEGIN;

-- BRONZE LAYER (raw events as received)
CREATE TABLE IF NOT EXISTS scout.bronze_transactions_raw (
    ingest_id BIGSERIAL PRIMARY KEY,
    payload JSONB NOT NULL,
    source_id TEXT NOT NULL,
    ingested_at TIMESTAMPTZ DEFAULT NOW(),
    processed BOOLEAN DEFAULT false
);

CREATE INDEX idx_bronze_ingested ON scout.bronze_transactions_raw(ingested_at) WHERE NOT processed;
CREATE INDEX idx_bronze_source ON scout.bronze_transactions_raw(source_id, ingested_at);

-- SILVER LAYER (validated, typed, ready for analytics)
CREATE TABLE IF NOT EXISTS scout.silver_transactions (
    -- Core identifiers
    id TEXT PRIMARY KEY,
    store_id TEXT NOT NULL REFERENCES scout.dim_store(store_id),
    ts TIMESTAMPTZ NOT NULL,
    time_of_day scout.time_of_day_t NOT NULL,
    
    -- Geographic hierarchy (denormalized for performance)
    barangay TEXT NOT NULL,
    city TEXT NOT NULL,
    province TEXT NOT NULL,
    region TEXT NOT NULL,
    
    -- Product information
    product_category TEXT NOT NULL REFERENCES scout.dim_category(category),
    brand_name TEXT NOT NULL REFERENCES scout.dim_brand(brand_name),
    sku TEXT NOT NULL REFERENCES scout.dim_sku(sku),
    units_per_transaction INT NOT NULL CHECK (units_per_transaction > 0),
    peso_value NUMERIC(12,2) NOT NULL CHECK (peso_value >= 0),
    basket_size INT NOT NULL CHECK (basket_size > 0),
    
    -- Counter interaction
    request_mode scout.request_mode_t NOT NULL,
    request_type scout.request_type_t NOT NULL,
    suggestion_accepted BOOLEAN NOT NULL,
    
    -- Demographics
    gender scout.gender_t NOT NULL,
    age_bracket scout.age_bracket_t NOT NULL,
    
    -- Transaction dynamics
    duration_seconds INT NOT NULL CHECK (duration_seconds >= 0),
    campaign_influenced BOOLEAN NOT NULL,
    handshake_score NUMERIC(3,2) NOT NULL CHECK (handshake_score BETWEEN 0 AND 1),
    is_tbwa_client BOOLEAN NOT NULL,
    
    -- Commerce context
    payment_method scout.payment_method_t NOT NULL,
    customer_type scout.customer_type_t NOT NULL,
    store_type scout.store_type_t NOT NULL,
    economic_class scout.economic_class_t NOT NULL,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Combo basket items (normalized)
CREATE TABLE IF NOT EXISTS scout.silver_combo_items (
    id TEXT NOT NULL REFERENCES scout.silver_transactions(id) ON DELETE CASCADE,
    position INT NOT NULL CHECK (position >= 1),
    sku TEXT NOT NULL REFERENCES scout.dim_sku(sku),
    quantity INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
    PRIMARY KEY (id, position)
);

-- Substitution events
CREATE TABLE IF NOT EXISTS scout.silver_substitutions (
    id TEXT PRIMARY KEY REFERENCES scout.silver_transactions(id) ON DELETE CASCADE,
    occurred BOOLEAN NOT NULL,
    from_sku TEXT REFERENCES scout.dim_sku(sku),
    to_sku TEXT REFERENCES scout.dim_sku(sku),
    reason scout.substitution_reason_t,
    CHECK (
        (occurred = false) OR 
        (occurred = true AND from_sku IS NOT NULL AND to_sku IS NOT NULL AND reason IS NOT NULL)
    )
);

-- Performance indexes on silver
CREATE INDEX idx_silver_ts ON scout.silver_transactions(ts);
CREATE INDEX idx_silver_store_ts ON scout.silver_transactions(store_id, ts);
CREATE INDEX idx_silver_region_ts ON scout.silver_transactions(region, ts);
CREATE INDEX idx_silver_barangay_ts ON scout.silver_transactions(barangay, ts);
CREATE INDEX idx_silver_category_ts ON scout.silver_transactions(product_category, ts);
CREATE INDEX idx_silver_brand_ts ON scout.silver_transactions(brand_name, ts);
CREATE INDEX idx_silver_tbwa ON scout.silver_transactions(is_tbwa_client, ts);
CREATE INDEX idx_silver_time_of_day ON scout.silver_transactions(time_of_day, ts);

-- Indexes for basket analysis
CREATE INDEX idx_combo_sku ON scout.silver_combo_items(sku);
CREATE INDEX idx_substitution_flow ON scout.silver_substitutions(from_sku, to_sku) WHERE occurred = true;

-- Update trigger for silver
CREATE TRIGGER update_silver_transactions_timestamp
    BEFORE UPDATE ON scout.silver_transactions
    FOR EACH ROW EXECUTE FUNCTION scout.update_timestamp();

-- Data quality tracking
CREATE TABLE IF NOT EXISTS scout.data_quality_issues (
    issue_id BIGSERIAL PRIMARY KEY,
    ingest_id BIGINT REFERENCES scout.bronze_transactions_raw(ingest_id),
    transaction_id TEXT,
    issue_type TEXT NOT NULL,
    field_name TEXT,
    field_value TEXT,
    expected_value TEXT,
    severity TEXT CHECK (severity IN ('error', 'warning', 'info')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_quality_issues_severity ON scout.data_quality_issues(severity, created_at);

COMMIT;