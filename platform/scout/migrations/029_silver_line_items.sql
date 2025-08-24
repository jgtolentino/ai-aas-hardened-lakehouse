-- ============================================================
-- Migration 029: Complete Silver Layer
-- Completes the Silver layer with missing tables
-- ============================================================

-- Silver line items table
CREATE TABLE IF NOT EXISTS scout.silver_line_items (
    line_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    product_name TEXT,
    brand_name TEXT,
    category TEXT,
    
    -- Transaction details
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    line_amount NUMERIC(10,2) NOT NULL,
    discount_amount NUMERIC(10,2) DEFAULT 0,
    
    -- Enrichments
    cost_of_goods NUMERIC(10,2),
    margin_amount NUMERIC(10,2),
    margin_percentage NUMERIC(5,2),
    
    -- STT detection linkage
    detected_brand TEXT,
    brand_match_confidence NUMERIC(3,2),
    
    processed_at TIMESTAMP DEFAULT NOW()
);

-- Silver product metrics table
CREATE TABLE IF NOT EXISTS scout.silver_product_metrics (
    product_id TEXT NOT NULL,
    date_key DATE NOT NULL,
    
    -- Daily metrics
    units_sold INTEGER DEFAULT 0,
    revenue NUMERIC(12,2) DEFAULT 0,
    transactions INTEGER DEFAULT 0,
    unique_stores INTEGER DEFAULT 0,
    unique_customers INTEGER DEFAULT 0,
    
    -- Running totals
    units_sold_mtd INTEGER DEFAULT 0,
    revenue_mtd NUMERIC(12,2) DEFAULT 0,
    units_sold_ytd INTEGER DEFAULT 0,
    revenue_ytd NUMERIC(12,2) DEFAULT 0,
    
    processed_at TIMESTAMP DEFAULT NOW(),
    
    PRIMARY KEY (product_id, date_key)
);

-- Indexes for performance
CREATE INDEX idx_silver_items_transaction ON scout.silver_line_items(transaction_id);
CREATE INDEX idx_silver_items_product ON scout.silver_line_items(product_id);
CREATE INDEX idx_silver_items_brand ON scout.silver_line_items(brand_name);
CREATE INDEX idx_silver_metrics_date ON scout.silver_product_metrics(date_key);

-- Bridge tables for many-to-many relationships
CREATE TABLE IF NOT EXISTS scout.bridge_product_substitutions (
    substitution_id SERIAL PRIMARY KEY,
    original_product_key INT,
    substitute_product_key INT,
    substitution_rate NUMERIC(3,2),
    reason VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(original_product_key, substitute_product_key)
);

CREATE TABLE IF NOT EXISTS scout.bridge_store_campaigns (
    store_campaign_id SERIAL PRIMARY KEY,
    store_key INT,
    campaign_key INT,
    start_date DATE,
    end_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_bridge_substitutions ON scout.bridge_product_substitutions(original_product_key, substitute_product_key);
CREATE INDEX idx_bridge_campaigns ON scout.bridge_store_campaigns(store_key, campaign_key);
CREATE INDEX idx_bridge_campaigns_dates ON scout.bridge_store_campaigns(start_date, end_date);