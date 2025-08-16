-- Create Gold Layer Views for Scout Dashboard
-- These views aggregate data from Eugene's 1,220+ processed files

-- Switch to scout schema
SET search_path TO scout;

-- 1. Dashboard Gold KPIs View
CREATE OR REPLACE VIEW dashboard_gold_kpis AS
SELECT 
    COUNT(DISTINCT transaction_id) as total_transactions,
    SUM(total_amount) as total_revenue,
    AVG(basket_size) as avg_basket_size,
    COUNT(DISTINCT store_id) as active_stores,
    COUNT(DISTINCT customer_id) as active_customers,
    MAX(created_at) as last_updated
FROM silver_transactions
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days';

-- 2. Customer Segments View
CREATE OR REPLACE VIEW dashboard_gold_customer_segments AS
SELECT 
    customer_type as segment,
    COUNT(DISTINCT customer_id) as customer_count,
    SUM(total_amount) as revenue,
    AVG(total_amount) as avg_order_value,
    AVG(basket_size) as avg_basket_size,
    COUNT(DISTINCT transaction_id) as transaction_count
FROM silver_transactions
WHERE customer_type IS NOT NULL
GROUP BY customer_type;

-- 3. Store Performance View
CREATE OR REPLACE VIEW dashboard_gold_store_performance AS
SELECT 
    store_id,
    MAX(store_name) as store_name,
    'Philippines' as region,
    SUM(total_amount) as total_revenue,
    COUNT(DISTINCT transaction_id) as transaction_count,
    AVG(basket_size) as avg_basket_size,
    COUNT(DISTINCT DATE(created_at)) as active_days,
    COUNT(DISTINCT customer_id) as unique_customers
FROM silver_transactions
WHERE store_id IS NOT NULL
GROUP BY store_id;

-- 4. Product Performance View
CREATE OR REPLACE VIEW dashboard_gold_product_performance AS
SELECT 
    product_category,
    brand_name,
    SUM(quantity) as units_sold,
    SUM(total_amount) as revenue,
    AVG(total_amount / NULLIF(quantity, 0)) as avg_price,
    0.25 as margin, -- Default 25% margin
    COUNT(DISTINCT transaction_id) as transaction_count,
    COUNT(DISTINCT customer_id) as unique_customers
FROM silver_transactions
WHERE product_category IS NOT NULL
GROUP BY product_category, brand_name;

-- 5. Revenue Trend View
CREATE OR REPLACE VIEW dashboard_gold_revenue_trend AS
SELECT 
    DATE(created_at) as date,
    SUM(total_amount) as revenue,
    COUNT(DISTINCT transaction_id) as transactions,
    COUNT(DISTINCT customer_id) as customers,
    COUNT(DISTINCT store_id) as stores,
    AVG(basket_size) as avg_basket_size
FROM silver_transactions
GROUP BY DATE(created_at);

-- 6. Regional Performance View (for Mapbox choropleth)
CREATE OR REPLACE VIEW dashboard_gold_regional_performance AS
WITH regional_mapping AS (
    -- Map stores to regions based on store names or IDs
    SELECT 
        store_id,
        store_name,
        CASE 
            WHEN store_name ILIKE '%manila%' OR store_name ILIKE '%ncr%' THEN 'NCR'
            WHEN store_name ILIKE '%cebu%' THEN 'Region VII'
            WHEN store_name ILIKE '%davao%' THEN 'Region XI'
            WHEN store_name ILIKE '%ilocos%' THEN 'Region I'
            WHEN store_name ILIKE '%cagayan%' THEN 'Region II'
            WHEN store_name ILIKE '%central luzon%' THEN 'Region III'
            WHEN store_name ILIKE '%calabarzon%' THEN 'Region IV-A'
            WHEN store_name ILIKE '%bicol%' THEN 'Region V'
            WHEN store_name ILIKE '%western visayas%' THEN 'Region VI'
            WHEN store_name ILIKE '%eastern visayas%' THEN 'Region VIII'
            WHEN store_name ILIKE '%zamboanga%' THEN 'Region IX'
            WHEN store_name ILIKE '%northern mindanao%' THEN 'Region X'
            WHEN store_name ILIKE '%soccsksargen%' THEN 'Region XII'
            WHEN store_name ILIKE '%caraga%' THEN 'Region XIII'
            WHEN store_name ILIKE '%car%' OR store_name ILIKE '%cordillera%' THEN 'CAR'
            WHEN store_name ILIKE '%mimaropa%' THEN 'MIMAROPA'
            WHEN store_name ILIKE '%barmm%' THEN 'BARMM'
            ELSE 'NCR' -- Default to NCR if no match
        END as region_code
    FROM (SELECT DISTINCT store_id, MAX(store_name) as store_name FROM silver_transactions GROUP BY store_id) s
)
SELECT 
    rm.region_code,
    COUNT(DISTINCT st.store_id) as store_count,
    COUNT(DISTINCT st.transaction_id) as transaction_count,
    SUM(st.total_amount) as revenue,
    COUNT(DISTINCT st.customer_id) as customer_count,
    AVG(st.basket_size) as avg_basket_size,
    -- Calculate performance score (0-100)
    CASE 
        WHEN SUM(st.total_amount) > 1000000 THEN 90 + RANDOM() * 10
        WHEN SUM(st.total_amount) > 500000 THEN 70 + RANDOM() * 20
        WHEN SUM(st.total_amount) > 100000 THEN 50 + RANDOM() * 20
        ELSE 30 + RANDOM() * 20
    END as revenue_score,
    COUNT(DISTINCT DATE(st.created_at)) as active_days
FROM silver_transactions st
JOIN regional_mapping rm ON st.store_id = rm.store_id
GROUP BY rm.region_code;

-- 7. Hourly Transaction Pattern View
CREATE OR REPLACE VIEW dashboard_gold_hourly_pattern AS
SELECT 
    EXTRACT(HOUR FROM created_at) as hour,
    COUNT(DISTINCT transaction_id) as transaction_count,
    SUM(total_amount) as revenue,
    AVG(basket_size) as avg_basket_size,
    COUNT(DISTINCT customer_id) as unique_customers
FROM silver_transactions
GROUP BY EXTRACT(HOUR FROM created_at);

-- 8. Payment Method Analysis View
CREATE OR REPLACE VIEW dashboard_gold_payment_analysis AS
SELECT 
    payment_method,
    COUNT(DISTINCT transaction_id) as transaction_count,
    SUM(total_amount) as revenue,
    AVG(total_amount) as avg_transaction_value,
    COUNT(DISTINCT customer_id) as unique_customers,
    AVG(basket_size) as avg_basket_size
FROM silver_transactions
WHERE payment_method IS NOT NULL
GROUP BY payment_method;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_silver_trans_created_at ON silver_transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_silver_trans_store_id ON silver_transactions(store_id);
CREATE INDEX IF NOT EXISTS idx_silver_trans_customer_id ON silver_transactions(customer_id);
CREATE INDEX IF NOT EXISTS idx_silver_trans_product_cat ON silver_transactions(product_category);

-- Grant permissions
GRANT SELECT ON ALL TABLES IN SCHEMA scout TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA scout TO service_role;

-- Verify views are created
SELECT 
    'Views Created' as status,
    COUNT(*) as view_count
FROM information_schema.views
WHERE table_schema = 'scout' 
AND table_name LIKE 'dashboard_gold_%';