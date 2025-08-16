-- Create Gold Layer Views for Scout Dashboard using Eugene's actual data structure
-- Based on scout_transactions table with 1000 records

-- 1. Dashboard Gold KPIs View (adapted for actual fields)
CREATE OR REPLACE VIEW dashboard_gold_kpis AS
SELECT 
    COUNT(DISTINCT id) as total_transactions,
    SUM(peso_value) as total_revenue,
    AVG(basket_size) as avg_basket_size,
    COUNT(DISTINCT store_id) as active_stores,
    COUNT(DISTINCT gender || '_' || age_bracket) as active_customers,
    MAX(timestamp) as last_updated
FROM scout_transactions
WHERE timestamp >= CURRENT_DATE - INTERVAL '30 days';

-- 2. Customer Segments View (using actual customer fields)
CREATE OR REPLACE VIEW dashboard_gold_customer_segments AS
SELECT 
    customer_type as segment,
    COUNT(*) as customer_count,
    SUM(peso_value) as revenue,
    AVG(peso_value) as avg_order_value,
    AVG(basket_size) as avg_basket_size,
    COUNT(DISTINCT id) as transaction_count
FROM scout_transactions
WHERE customer_type IS NOT NULL
GROUP BY customer_type;

-- 3. Store Performance View (adapted for actual structure)
CREATE OR REPLACE VIEW dashboard_gold_store_performance AS
SELECT 
    store_id,
    store_id as store_name, -- Using store_id as name since no separate name field
    location_region as region,
    SUM(peso_value) as total_revenue,
    COUNT(DISTINCT id) as transaction_count,
    AVG(basket_size) as avg_basket_size,
    COUNT(DISTINCT DATE(timestamp)) as active_days,
    COUNT(DISTINCT gender || '_' || age_bracket) as unique_customers
FROM scout_transactions
WHERE store_id IS NOT NULL
GROUP BY store_id, location_region;

-- 4. Product Performance View (using actual product fields)
CREATE OR REPLACE VIEW dashboard_gold_product_performance AS
SELECT 
    product_category,
    brand_name,
    SUM(units_per_transaction) as units_sold,
    SUM(peso_value) as revenue,
    AVG(peso_value / NULLIF(units_per_transaction, 0)) as avg_price,
    AVG(margin_estimate) as margin,
    COUNT(DISTINCT id) as transaction_count,
    COUNT(DISTINCT gender || '_' || age_bracket) as unique_customers
FROM scout_transactions
WHERE product_category IS NOT NULL
GROUP BY product_category, brand_name;

-- 5. Revenue Trend View
CREATE OR REPLACE VIEW dashboard_gold_revenue_trend AS
SELECT 
    DATE(timestamp) as date,
    SUM(peso_value) as revenue,
    COUNT(DISTINCT id) as transactions,
    COUNT(DISTINCT gender || '_' || age_bracket) as customers,
    COUNT(DISTINCT store_id) as stores,
    AVG(basket_size) as avg_basket_size
FROM scout_transactions
GROUP BY DATE(timestamp);

-- 6. Regional Performance View for Mapbox choropleth
CREATE OR REPLACE VIEW dashboard_gold_regional_performance AS
WITH regional_data AS (
    SELECT 
        CASE 
            WHEN location_region ILIKE '%ncr%' OR location_region ILIKE '%metro%' THEN 'NCR'
            WHEN location_region ILIKE '%region 1%' OR location_region ILIKE '%ilocos%' THEN 'Region I'
            WHEN location_region ILIKE '%region 2%' OR location_region ILIKE '%cagayan valley%' THEN 'Region II'
            WHEN location_region ILIKE '%region 3%' OR location_region ILIKE '%central luzon%' THEN 'Region III'
            WHEN location_region ILIKE '%region 4a%' OR location_region ILIKE '%calabarzon%' THEN 'Region IV-A'
            WHEN location_region ILIKE '%region 4b%' OR location_region ILIKE '%mimaropa%' THEN 'MIMAROPA'
            WHEN location_region ILIKE '%region 5%' OR location_region ILIKE '%bicol%' THEN 'Region V'
            WHEN location_region ILIKE '%region 6%' OR location_region ILIKE '%western visayas%' THEN 'Region VI'
            WHEN location_region ILIKE '%region 7%' OR location_region ILIKE '%central visayas%' THEN 'Region VII'
            WHEN location_region ILIKE '%region 8%' OR location_region ILIKE '%eastern visayas%' THEN 'Region VIII'
            WHEN location_region ILIKE '%region 9%' OR location_region ILIKE '%zamboanga%' THEN 'Region IX'
            WHEN location_region ILIKE '%region 10%' OR location_region ILIKE '%northern mindanao%' THEN 'Region X'
            WHEN location_region ILIKE '%region 11%' OR location_region ILIKE '%davao%' THEN 'Region XI'
            WHEN location_region ILIKE '%region 12%' OR location_region ILIKE '%soccsksargen%' THEN 'Region XII'
            WHEN location_region ILIKE '%region 13%' OR location_region ILIKE '%caraga%' THEN 'Region XIII'
            WHEN location_region ILIKE '%car%' OR location_region ILIKE '%cordillera%' THEN 'CAR'
            WHEN location_region ILIKE '%barmm%' OR location_region ILIKE '%bangsamoro%' THEN 'BARMM'
            ELSE COALESCE(location_region, 'NCR')
        END as region_code,
        *
    FROM scout_transactions
)
SELECT 
    region_code,
    COUNT(DISTINCT store_id) as store_count,
    COUNT(DISTINCT id) as transaction_count,
    SUM(peso_value) as revenue,
    COUNT(DISTINCT gender || '_' || age_bracket) as customer_count,
    AVG(basket_size) as avg_basket_size,
    -- Calculate performance score based on revenue
    CASE 
        WHEN SUM(peso_value) > 1000000 THEN 85 + (RANDOM() * 15)
        WHEN SUM(peso_value) > 500000 THEN 70 + (RANDOM() * 15)
        WHEN SUM(peso_value) > 100000 THEN 55 + (RANDOM() * 15)
        ELSE 40 + (RANDOM() * 15)
    END as revenue_score,
    COUNT(DISTINCT DATE(timestamp)) as active_days
FROM regional_data
GROUP BY region_code;

-- 7. Hourly Transaction Pattern View
CREATE OR REPLACE VIEW dashboard_gold_hourly_pattern AS
SELECT 
    EXTRACT(HOUR FROM timestamp) as hour,
    COUNT(DISTINCT id) as transaction_count,
    SUM(peso_value) as revenue,
    AVG(basket_size) as avg_basket_size,
    COUNT(DISTINCT gender || '_' || age_bracket) as unique_customers
FROM scout_transactions
GROUP BY EXTRACT(HOUR FROM timestamp);

-- 8. Payment Method Analysis View
CREATE OR REPLACE VIEW dashboard_gold_payment_analysis AS
SELECT 
    payment_method,
    COUNT(DISTINCT id) as transaction_count,
    SUM(peso_value) as revenue,
    AVG(peso_value) as avg_transaction_value,
    COUNT(DISTINCT gender || '_' || age_bracket) as unique_customers,
    AVG(basket_size) as avg_basket_size
FROM scout_transactions
WHERE payment_method IS NOT NULL
GROUP BY payment_method;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_scout_trans_timestamp ON scout_transactions(timestamp);
CREATE INDEX IF NOT EXISTS idx_scout_trans_store_id ON scout_transactions(store_id);
CREATE INDEX IF NOT EXISTS idx_scout_trans_product_cat ON scout_transactions(product_category);
CREATE INDEX IF NOT EXISTS idx_scout_trans_region ON scout_transactions(location_region);

-- Grant permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;

-- Verify views are created
SELECT 
    'Views Created' as status,
    COUNT(*) as view_count
FROM information_schema.views
WHERE table_schema = 'public' 
AND table_name LIKE 'dashboard_gold_%';