-- platform/scout/migrations/043_complete_silver_layer.sql
-- Completes the Silver layer with missing tables
-- Adds bridge tables for many-to-many relationships

-- Create silver_line_items table
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
    
    -- Metadata
    processed_at TIMESTAMP DEFAULT NOW()
);

-- Create silver_product_metrics table
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
    
    -- Metadata
    processed_at TIMESTAMP DEFAULT NOW(),
    
    PRIMARY KEY (product_id, date_key)
);

-- Create silver_store_metrics table
CREATE TABLE IF NOT EXISTS scout.silver_store_metrics (
    store_id TEXT NOT NULL,
    date_key DATE NOT NULL,
    
    -- Daily metrics
    transaction_count INTEGER DEFAULT 0,
    total_sales NUMERIC(12,2) DEFAULT 0,
    unique_customers INTEGER DEFAULT 0,
    unique_products INTEGER DEFAULT 0,
    avg_basket_size NUMERIC(10,2) DEFAULT 0,
    
    -- Time distribution
    morning_sales NUMERIC(10,2) DEFAULT 0,
    afternoon_sales NUMERIC(10,2) DEFAULT 0,
    evening_sales NUMERIC(10,2) DEFAULT 0,
    night_sales NUMERIC(10,2) DEFAULT 0,
    
    -- Running totals
    sales_mtd NUMERIC(12,2) DEFAULT 0,
    sales_ytd NUMERIC(12,2) DEFAULT 0,
    
    -- Metadata
    processed_at TIMESTAMP DEFAULT NOW(),
    
    PRIMARY KEY (store_id, date_key)
);

-- Create silver_customer_metrics table
CREATE TABLE IF NOT EXISTS scout.silver_customer_metrics (
    customer_id TEXT NOT NULL,
    date_key DATE NOT NULL,
    
    -- Daily metrics
    transaction_count INTEGER DEFAULT 0,
    total_spent NUMERIC(12,2) DEFAULT 0,
    unique_products INTEGER DEFAULT 0,
    unique_stores INTEGER DEFAULT 0,
    
    -- Customer behavior
    avg_transaction_value NUMERIC(10,2) DEFAULT 0,
    favorite_store_id TEXT,
    favorite_category TEXT,
    
    -- RFM components
    days_since_last_purchase INTEGER,
    purchase_frequency INTEGER,
    monetary_value NUMERIC(12,2),
    
    -- Metadata
    processed_at TIMESTAMP DEFAULT NOW(),
    
    PRIMARY KEY (customer_id, date_key)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_silver_items_transaction ON scout.silver_line_items(transaction_id);
CREATE INDEX IF NOT EXISTS idx_silver_items_product ON scout.silver_line_items(product_id);
CREATE INDEX IF NOT EXISTS idx_silver_items_brand ON scout.silver_line_items(brand_name);
CREATE INDEX IF NOT EXISTS idx_silver_metrics_date ON scout.silver_product_metrics(date_key);
CREATE INDEX IF NOT EXISTS idx_silver_store_metrics_date ON scout.silver_store_metrics(date_key);
CREATE INDEX IF NOT EXISTS idx_silver_customer_metrics_date ON scout.silver_customer_metrics(date_key);

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

CREATE TABLE IF NOT EXISTS scout.bridge_customer_segments (
    customer_segment_id SERIAL PRIMARY KEY,
    customer_key INT,
    segment_key INT,
    segment_name VARCHAR(100),
    assigned_date DATE,
    confidence_score NUMERIC(3,2),
    is_current BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for bridge tables
CREATE INDEX IF NOT EXISTS idx_bridge_substitutions ON scout.bridge_product_substitutions(original_product_key, substitute_product_key);
CREATE INDEX IF NOT EXISTS idx_bridge_campaigns ON scout.bridge_store_campaigns(store_key, campaign_key);
CREATE INDEX IF NOT EXISTS idx_bridge_campaigns_dates ON scout.bridge_store_campaigns(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_bridge_segments ON scout.bridge_customer_segments(customer_key, segment_key);

-- Function to process bronze to silver for line items
CREATE OR REPLACE FUNCTION scout.process_bronze_to_silver_items(p_batch_size INT DEFAULT 1000)
RETURNS INT AS $$
DECLARE
    v_processed INT := 0;
BEGIN
    -- Process line items from bronze
    WITH bronze_batch AS (
        SELECT 
            bt.transaction_id,
            jsonb_array_elements(bt.items) as item_data
        FROM scout.bronze_transactions bt
        WHERE NOT EXISTS (
            SELECT 1 FROM scout.silver_line_items sli 
            WHERE sli.transaction_id = bt.transaction_id::TEXT
        )
        LIMIT p_batch_size
    )
    INSERT INTO scout.silver_line_items (
        transaction_id,
        product_id,
        product_name,
        brand_name,
        category,
        quantity,
        unit_price,
        line_amount,
        discount_amount
    )
    SELECT 
        bb.transaction_id::TEXT,
        (bb.item_data->>'sku')::TEXT as product_id,
        (bb.item_data->>'product_name')::TEXT as product_name,
        (bb.item_data->>'brand')::TEXT as brand_name,
        (bb.item_data->>'category')::TEXT as category,
        (bb.item_data->>'quantity')::INT as quantity,
        (bb.item_data->>'unit_price')::NUMERIC as unit_price,
        (bb.item_data->>'line_amount')::NUMERIC as line_amount,
        COALESCE((bb.item_data->>'discount_amount')::NUMERIC, 0) as discount_amount
    FROM bronze_batch bb
    ON CONFLICT DO NOTHING;
    
    GET DIAGNOSTICS v_processed = ROW_COUNT;
    RETURN v_processed;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to refresh silver metrics
CREATE OR REPLACE FUNCTION scout.refresh_silver_metrics(p_date DATE DEFAULT CURRENT_DATE)
RETURNS VOID AS $$
BEGIN
    -- Refresh product metrics
    INSERT INTO scout.silver_product_metrics (
        product_id, date_key, units_sold, revenue, transactions, unique_stores, unique_customers
    )
    SELECT 
        sli.product_id,
        p_date,
        SUM(sli.quantity) as units_sold,
        SUM(sli.line_amount) as revenue,
        COUNT(DISTINCT sli.transaction_id) as transactions,
        COUNT(DISTINCT st.store_id) as unique_stores,
        COUNT(DISTINCT st.customer_id) as unique_customers
    FROM scout.silver_line_items sli
    JOIN scout.silver_transactions st ON sli.transaction_id = st.transaction_id
    WHERE DATE(st.ts) = p_date
    GROUP BY sli.product_id
    ON CONFLICT (product_id, date_key) DO UPDATE
    SET units_sold = EXCLUDED.units_sold,
        revenue = EXCLUDED.revenue,
        transactions = EXCLUDED.transactions,
        unique_stores = EXCLUDED.unique_stores,
        unique_customers = EXCLUDED.unique_customers,
        processed_at = NOW();
    
    -- Refresh store metrics
    INSERT INTO scout.silver_store_metrics (
        store_id, date_key, transaction_count, total_sales, unique_customers, unique_products
    )
    SELECT 
        st.store_id,
        p_date,
        COUNT(DISTINCT st.transaction_id) as transaction_count,
        SUM(st.total_amount) as total_sales,
        COUNT(DISTINCT st.customer_id) as unique_customers,
        COUNT(DISTINCT sli.product_id) as unique_products
    FROM scout.silver_transactions st
    LEFT JOIN scout.silver_line_items sli ON st.transaction_id = sli.transaction_id
    WHERE DATE(st.ts) = p_date
    GROUP BY st.store_id
    ON CONFLICT (store_id, date_key) DO UPDATE
    SET transaction_count = EXCLUDED.transaction_count,
        total_sales = EXCLUDED.total_sales,
        unique_customers = EXCLUDED.unique_customers,
        unique_products = EXCLUDED.unique_products,
        processed_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create view for silver layer health monitoring
CREATE OR REPLACE VIEW scout.v_silver_pipeline_health AS
SELECT 
    'silver_transactions' as table_name,
    COUNT(*) as record_count,
    MAX(processed_at) as last_processed,
    CASE 
        WHEN MAX(processed_at) > NOW() - INTERVAL '1 hour' THEN 'Active'
        WHEN MAX(processed_at) > NOW() - INTERVAL '1 day' THEN 'Delayed'
        ELSE 'Stale'
    END as status
FROM scout.silver_transactions
UNION ALL
SELECT 
    'silver_line_items' as table_name,
    COUNT(*) as record_count,
    MAX(processed_at) as last_processed,
    CASE 
        WHEN MAX(processed_at) > NOW() - INTERVAL '1 hour' THEN 'Active'
        WHEN MAX(processed_at) > NOW() - INTERVAL '1 day' THEN 'Delayed'
        ELSE 'Stale'
    END as status
FROM scout.silver_line_items
UNION ALL
SELECT 
    'silver_product_metrics' as table_name,
    COUNT(*) as record_count,
    MAX(processed_at) as last_processed,
    CASE 
        WHEN MAX(processed_at) > NOW() - INTERVAL '1 hour' THEN 'Active'
        WHEN MAX(processed_at) > NOW() - INTERVAL '1 day' THEN 'Delayed'
        ELSE 'Stale'
    END as status
FROM scout.silver_product_metrics;

-- Grant permissions
GRANT SELECT ON scout.silver_line_items TO authenticated;
GRANT SELECT ON scout.silver_product_metrics TO authenticated;
GRANT SELECT ON scout.silver_store_metrics TO authenticated;
GRANT SELECT ON scout.silver_customer_metrics TO authenticated;
GRANT SELECT ON scout.bridge_product_substitutions TO authenticated;
GRANT SELECT ON scout.bridge_store_campaigns TO authenticated;
GRANT SELECT ON scout.bridge_customer_segments TO authenticated;
GRANT SELECT ON scout.v_silver_pipeline_health TO authenticated;
GRANT EXECUTE ON FUNCTION scout.process_bronze_to_silver_items TO authenticated;
GRANT EXECUTE ON FUNCTION scout.refresh_silver_metrics TO authenticated;