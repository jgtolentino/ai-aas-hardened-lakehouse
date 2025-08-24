-- platform/scout/migrations/042_standardize_dim_names.sql
-- Standardizes master_* tables to dim_* convention
-- Adds missing fact tables from Scout v5.2

-- Only rename if tables exist with old names
DO $$
BEGIN
    -- Rename master_products to dim_products if needed
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'master_products') 
       AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'dim_products') THEN
        ALTER TABLE scout.master_products RENAME TO dim_products;
        RAISE NOTICE 'Renamed master_products to dim_products';
    END IF;
    
    -- Rename master_brands to dim_brands if needed
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'master_brands')
       AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'dim_brands') THEN
        ALTER TABLE scout.master_brands RENAME TO dim_brands;
        RAISE NOTICE 'Renamed master_brands to dim_brands';
    END IF;
    
    -- Rename master_categories to dim_categories if needed
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'master_categories')
       AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'dim_categories') THEN
        ALTER TABLE scout.master_categories RENAME TO dim_categories;
        RAISE NOTICE 'Renamed master_categories to dim_categories';
    END IF;
    
    -- Rename master_stores to dim_stores if needed
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'master_stores')
       AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'dim_stores') THEN
        ALTER TABLE scout.master_stores RENAME TO dim_stores;
        RAISE NOTICE 'Renamed master_stores to dim_stores';
    END IF;
    
    -- Rename master_customers to dim_customers if needed
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'master_customers')
       AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'dim_customers') THEN
        ALTER TABLE scout.master_customers RENAME TO dim_customers;
        RAISE NOTICE 'Renamed master_customers to dim_customers';
    END IF;
END $$;

-- Create missing fact_transaction_items table from Scout v5.2
CREATE TABLE IF NOT EXISTS scout.fact_transaction_items (
    transaction_id VARCHAR(100) NOT NULL,
    line_item_id INT NOT NULL,
    sku VARCHAR(100) NOT NULL,
    quantity INT NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    line_amount NUMERIC(10,2) NOT NULL,
    discount_amount NUMERIC(10,2) DEFAULT 0,
    
    -- Product reference (FK to dim_products)
    product_key INT,
    
    -- Brand detection from STT
    detected_brand VARCHAR(255),
    brand_confidence NUMERIC(3,2),
    detection_method VARCHAR(50),
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    
    PRIMARY KEY (transaction_id, line_item_id)
);

-- Create missing fact_daily_sales aggregate table
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
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    PRIMARY KEY (date_key, store_key, product_key)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_fact_items_transaction ON scout.fact_transaction_items(transaction_id);
CREATE INDEX IF NOT EXISTS idx_fact_items_sku ON scout.fact_transaction_items(sku);
CREATE INDEX IF NOT EXISTS idx_fact_items_brand ON scout.fact_transaction_items(detected_brand);
CREATE INDEX IF NOT EXISTS idx_fact_daily_date ON scout.fact_daily_sales(date_key);
CREATE INDEX IF NOT EXISTS idx_fact_daily_store ON scout.fact_daily_sales(store_key);

-- Create or update fact_transactions table structure
CREATE TABLE IF NOT EXISTS scout.fact_transactions (
    transaction_id VARCHAR(100) PRIMARY KEY,
    store_id VARCHAR(100) NOT NULL,
    customer_id VARCHAR(100),
    campaign_id VARCHAR(100),
    transaction_date DATE NOT NULL,
    transaction_time TIME NOT NULL,
    total_amount NUMERIC(12,2) NOT NULL,
    discount_amount NUMERIC(10,2) DEFAULT 0,
    tax_amount NUMERIC(10,2),
    payment_method VARCHAR(50),
    status VARCHAR(50) NOT NULL DEFAULT 'completed',
    source_file TEXT NOT NULL,
    
    -- Dimension foreign keys
    date_key INT,
    time_key INT,
    store_key INT,
    customer_key INT,
    
    -- Metadata
    items JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for fact_transactions
CREATE INDEX IF NOT EXISTS idx_fact_trans_date ON scout.fact_transactions(transaction_date);
CREATE INDEX IF NOT EXISTS idx_fact_trans_store ON scout.fact_transactions(store_id);
CREATE INDEX IF NOT EXISTS idx_fact_trans_source ON scout.fact_transactions(source_file);
CREATE INDEX IF NOT EXISTS idx_fact_trans_composite ON scout.fact_transactions(store_id, transaction_date);

-- Function to populate fact_daily_sales from transactions
CREATE OR REPLACE FUNCTION scout.refresh_fact_daily_sales(p_date DATE DEFAULT CURRENT_DATE)
RETURNS VOID AS $$
BEGIN
    -- Delete existing data for the date
    DELETE FROM scout.fact_daily_sales WHERE date_key = p_date;
    
    -- Insert aggregated data
    INSERT INTO scout.fact_daily_sales (
        date_key,
        store_key,
        product_key,
        transaction_count,
        quantity_sold,
        gross_sales,
        net_sales,
        unique_customers
    )
    SELECT 
        p_date as date_key,
        COALESCE(s.store_key, 0) as store_key,
        COALESCE(p.product_key, 0) as product_key,
        COUNT(DISTINCT ft.transaction_id) as transaction_count,
        SUM(fti.quantity) as quantity_sold,
        SUM(fti.line_amount) as gross_sales,
        SUM(fti.line_amount - COALESCE(fti.discount_amount, 0)) as net_sales,
        COUNT(DISTINCT ft.customer_id) as unique_customers
    FROM scout.fact_transactions ft
    JOIN scout.fact_transaction_items fti ON ft.transaction_id = fti.transaction_id
    LEFT JOIN (
        SELECT DISTINCT store_id, ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY store_id) as store_key
        FROM scout.fact_transactions
    ) s ON ft.store_id = s.store_id
    LEFT JOIN (
        SELECT DISTINCT sku, ROW_NUMBER() OVER (PARTITION BY sku ORDER BY sku) as product_key
        FROM scout.fact_transaction_items
    ) p ON fti.sku = p.sku
    WHERE ft.transaction_date = p_date
    GROUP BY s.store_key, p.product_key;
    
    -- Update metadata
    UPDATE scout.fact_daily_sales 
    SET updated_at = NOW() 
    WHERE date_key = p_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create views for backward compatibility with old names
CREATE OR REPLACE VIEW scout.master_products AS SELECT * FROM scout.dim_products;
CREATE OR REPLACE VIEW scout.master_brands AS SELECT * FROM scout.dim_brands;
CREATE OR REPLACE VIEW scout.master_categories AS SELECT * FROM scout.dim_categories;
CREATE OR REPLACE VIEW scout.master_stores AS SELECT * FROM scout.dim_stores;
CREATE OR REPLACE VIEW scout.master_customers AS SELECT * FROM scout.dim_customers;

-- Grant permissions
GRANT SELECT ON scout.fact_transaction_items TO authenticated;
GRANT SELECT ON scout.fact_daily_sales TO authenticated;
GRANT SELECT ON scout.fact_transactions TO authenticated;
GRANT EXECUTE ON FUNCTION scout.refresh_fact_daily_sales TO authenticated;

-- Grant permissions on views for backward compatibility
GRANT SELECT ON scout.master_products TO authenticated;
GRANT SELECT ON scout.master_brands TO authenticated;
GRANT SELECT ON scout.master_categories TO authenticated;
GRANT SELECT ON scout.master_stores TO authenticated;
GRANT SELECT ON scout.master_customers TO authenticated;