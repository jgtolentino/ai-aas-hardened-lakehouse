-- ============================================================
-- Migration 028: Standardize Dimension Names
-- Standardizes master_* tables to dim_* convention
-- ============================================================

-- Only rename if tables exist with old names
DO $$
BEGIN
    -- Products
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'master_products') 
       AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'dim_products') THEN
        ALTER TABLE scout.master_products RENAME TO dim_products;
        RAISE NOTICE 'Renamed master_products to dim_products';
    END IF;
    
    -- Brands
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'master_brands')
       AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'dim_brands') THEN
        ALTER TABLE scout.master_brands RENAME TO dim_brands;
        RAISE NOTICE 'Renamed master_brands to dim_brands';
    END IF;
    
    -- Categories
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'master_categories')
       AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'dim_categories') THEN
        ALTER TABLE scout.master_categories RENAME TO dim_categories;
        RAISE NOTICE 'Renamed master_categories to dim_categories';
    END IF;
    
    -- Update foreign key constraints if needed
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'scout' AND column_name = 'brand_id') THEN
        -- Update any FK references
        NULL; -- Placeholder - add specific FK updates based on your schema
    END IF;
END $$;

-- Create missing fact tables from Scout v5.2
CREATE TABLE IF NOT EXISTS scout.fact_transaction_items (
    transaction_id VARCHAR(100) NOT NULL,
    line_item_id INT NOT NULL,
    sku VARCHAR(100) NOT NULL,
    quantity INT NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    line_amount NUMERIC(10,2) NOT NULL,
    discount_amount NUMERIC(10,2) DEFAULT 0,
    
    -- Product reference
    product_key INT,
    
    -- Brand detection from STT
    detected_brand VARCHAR(255),
    brand_confidence NUMERIC(3,2),
    detection_method VARCHAR(50),
    
    created_at TIMESTAMP DEFAULT NOW(),
    
    PRIMARY KEY (transaction_id, line_item_id)
);

CREATE TABLE IF NOT EXISTS scout.fact_daily_sales (
    date_key DATE NOT NULL,
    store_key INT NOT NULL,
    product_key INT NOT NULL,
    
    -- Metrics
    transaction_count INT,
    quantity_sold INT,
    gross_sales NUMERIC(12,2),
    net_sales NUMERIC(12,2),
    unique_customers INT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    
    PRIMARY KEY (date_key, store_key, product_key)
);

-- Indexes
CREATE INDEX idx_fact_items_transaction ON scout.fact_transaction_items(transaction_id);
CREATE INDEX idx_fact_items_sku ON scout.fact_transaction_items(sku);
CREATE INDEX idx_fact_items_brand ON scout.fact_transaction_items(detected_brand);
CREATE INDEX idx_fact_daily_date ON scout.fact_daily_sales(date_key);
CREATE INDEX idx_fact_daily_store ON scout.fact_daily_sales(store_key);