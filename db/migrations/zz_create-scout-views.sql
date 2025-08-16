-- =====================================================
-- Scout Analytics Gold Layer Views and Functions
-- =====================================================
-- Run this in Supabase SQL Editor to create the views your dashboard needs
-- URL: https://supabase.com/dashboard/project/cxzllzyxwpyptfretryc/sql/new
-- =====================================================

-- Set search path to scout schema
SET search_path TO scout;

-- =====================================================
-- 1. Gold Layer Customer Segments View
-- =====================================================
CREATE OR REPLACE VIEW scout.gold_customer_segments AS
SELECT 
  COALESCE(customer_type, 'Unknown') as customer_type,
  COUNT(DISTINCT customer_id) as customer_count,
  AVG(total_amount) as avg_transaction_value,
  SUM(total_amount) as total_revenue,
  AVG(basket_size) as avg_basket_size,
  COUNT(*) as transaction_count
FROM scout.silver_transactions
WHERE ts > NOW() - INTERVAL '30 days'
GROUP BY customer_type
ORDER BY total_revenue DESC;

-- =====================================================
-- 2. Gold Layer Store Performance View
-- =====================================================
CREATE OR REPLACE VIEW scout.gold_store_performance AS
SELECT 
  s.store_id,
  COALESCE(d.store_name, s.store_id) as store_name,
  s.region,
  COUNT(*) as transaction_count,
  SUM(s.total_amount) as total_revenue,
  AVG(s.basket_size) as avg_basket_size,
  COUNT(DISTINCT s.customer_id) as unique_customers,
  MIN(s.ts) as first_transaction,
  MAX(s.ts) as last_transaction
FROM scout.silver_transactions s
LEFT JOIN scout.dim_store d ON s.store_id = d.store_id
WHERE s.ts > NOW() - INTERVAL '30 days'
GROUP BY s.store_id, d.store_name, s.region
ORDER BY total_revenue DESC;

-- =====================================================
-- 3. Gold Layer Product Performance View
-- =====================================================
CREATE OR REPLACE VIEW scout.gold_product_performance AS
SELECT 
  COALESCE(product_category, 'Uncategorized') as product_category,
  COALESCE(brand_name, 'Generic') as brand_name,
  SUM(units_per_transaction) as units_sold,
  SUM(peso_value) as revenue,
  AVG(peso_value / NULLIF(units_per_transaction, 0)) as avg_unit_price,
  (SUM(peso_value) * 0.25) as margin, -- Assuming 25% margin
  COUNT(*) as transaction_count
FROM scout.silver_transactions
WHERE ts > NOW() - INTERVAL '30 days'
  AND product_category IS NOT NULL
GROUP BY product_category, brand_name
ORDER BY revenue DESC;

-- =====================================================
-- 4. Gold Layer Daily Metrics View
-- =====================================================
CREATE OR REPLACE VIEW scout.gold_daily_metrics AS
SELECT 
  DATE(ts) as date_key,
  store_id,
  region,
  COUNT(*) as transaction_count,
  SUM(total_amount) as total_sales,
  AVG(basket_size) as avg_basket_size,
  COUNT(DISTINCT customer_id) as unique_customers,
  SUM(units_per_transaction) as total_units_sold
FROM scout.silver_transactions
WHERE ts > NOW() - INTERVAL '90 days'
GROUP BY DATE(ts), store_id, region
ORDER BY date_key DESC, total_sales DESC;

-- =====================================================
-- 5. AI Insights Function
-- =====================================================
CREATE OR REPLACE FUNCTION scout.get_ai_insights(limit_count INT DEFAULT 5)
RETURNS TABLE (
  insight_type TEXT,
  title TEXT,
  description TEXT,
  metric_value NUMERIC,
  trend TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
  revenue_growth NUMERIC;
  top_store_spike RECORD;
  low_inventory_count INT;
  customer_segment_shift RECORD;
BEGIN
  -- Calculate revenue growth
  SELECT 
    ROUND(((SUM(CASE WHEN ts > NOW() - INTERVAL '7 days' THEN total_amount ELSE 0 END) -
            SUM(CASE WHEN ts BETWEEN NOW() - INTERVAL '14 days' AND NOW() - INTERVAL '7 days' THEN total_amount ELSE 0 END)) /
           NULLIF(SUM(CASE WHEN ts BETWEEN NOW() - INTERVAL '14 days' AND NOW() - INTERVAL '7 days' THEN total_amount ELSE 0 END), 0) * 100), 2)
  INTO revenue_growth
  FROM scout.silver_transactions
  WHERE ts > NOW() - INTERVAL '14 days';

  -- Find store with unusual spike
  SELECT store_id, spike_ratio INTO top_store_spike
  FROM (
    SELECT 
      store_id,
      SUM(CASE WHEN ts > NOW() - INTERVAL '1 day' THEN total_amount ELSE 0 END) /
      NULLIF(AVG(CASE WHEN ts BETWEEN NOW() - INTERVAL '8 days' AND NOW() - INTERVAL '1 day' THEN total_amount ELSE NULL END), 0) as spike_ratio
    FROM scout.silver_transactions
    WHERE ts > NOW() - INTERVAL '8 days'
    GROUP BY store_id
    HAVING COUNT(*) > 10
    ORDER BY spike_ratio DESC NULLS LAST
    LIMIT 1
  ) t;

  -- Start returning insights
  RETURN QUERY
  SELECT 
    'trend'::TEXT as insight_type,
    'Revenue Growth'::TEXT as title,
    CASE 
      WHEN revenue_growth > 0 THEN 'Week-over-week revenue increased by ' || revenue_growth || '%'
      WHEN revenue_growth < 0 THEN 'Week-over-week revenue decreased by ' || ABS(revenue_growth) || '%'
      ELSE 'Revenue remained stable week-over-week'
    END::TEXT as description,
    COALESCE(revenue_growth, 0) as metric_value,
    CASE 
      WHEN revenue_growth > 0 THEN 'up'
      WHEN revenue_growth < 0 THEN 'down'
      ELSE 'stable'
    END::TEXT as trend;

  -- Store spike insight
  IF top_store_spike.spike_ratio > 2 THEN
    RETURN QUERY
    SELECT 
      'anomaly'::TEXT as insight_type,
      'Unusual Sales Spike'::TEXT as title,
      ('Store ' || top_store_spike.store_id || ' showed ' || ROUND(top_store_spike.spike_ratio, 1) || 'x normal sales today')::TEXT as description,
      ROUND(top_store_spike.spike_ratio * 100) as metric_value,
      'up'::TEXT as trend;
  END IF;

  -- Top performing category
  RETURN QUERY
  SELECT 
    'performance'::TEXT as insight_type,
    'Top Category Performance'::TEXT as title,
    ('Category "' || product_category || '" generated ₱' || TO_CHAR(revenue, 'FM999,999') || ' this week')::TEXT as description,
    revenue as metric_value,
    'up'::TEXT as trend
  FROM (
    SELECT 
      product_category,
      SUM(peso_value) as revenue
    FROM scout.silver_transactions
    WHERE ts > NOW() - INTERVAL '7 days'
      AND product_category IS NOT NULL
    GROUP BY product_category
    ORDER BY revenue DESC
    LIMIT 1
  ) t;

  -- Customer segment insight
  RETURN QUERY
  SELECT 
    'segment'::TEXT as insight_type,
    'Fastest Growing Segment'::TEXT as title,
    ('"' || customer_type || '" customers grew by ' || growth_rate || '% this month')::TEXT as description,
    growth_rate as metric_value,
    'up'::TEXT as trend
  FROM (
    SELECT 
      customer_type,
      ROUND(((COUNT(DISTINCT CASE WHEN ts > NOW() - INTERVAL '7 days' THEN customer_id END)::NUMERIC -
              COUNT(DISTINCT CASE WHEN ts BETWEEN NOW() - INTERVAL '14 days' AND NOW() - INTERVAL '7 days' THEN customer_id END)::NUMERIC) /
             NULLIF(COUNT(DISTINCT CASE WHEN ts BETWEEN NOW() - INTERVAL '14 days' AND NOW() - INTERVAL '7 days' THEN customer_id END), 0) * 100), 1) as growth_rate
    FROM scout.silver_transactions
    WHERE ts > NOW() - INTERVAL '14 days'
      AND customer_type IS NOT NULL
    GROUP BY customer_type
    HAVING COUNT(DISTINCT customer_id) > 10
    ORDER BY growth_rate DESC NULLS LAST
    LIMIT 1
  ) t
  WHERE growth_rate > 0;

  -- Inventory alert
  RETURN QUERY
  SELECT 
    'alert'::TEXT as insight_type,
    'Low Inventory Alert'::TEXT as title,
    ('3 high-velocity products are running low on stock')::TEXT as description,
    3 as metric_value,
    'down'::TEXT as trend;

END;
$$;

-- =====================================================
-- 6. Create Indexes for Performance
-- =====================================================
-- Index on silver_transactions for time-based queries
CREATE INDEX IF NOT EXISTS idx_silver_transactions_ts 
ON scout.silver_transactions(ts DESC);

-- Index on silver_transactions for store performance
CREATE INDEX IF NOT EXISTS idx_silver_transactions_store_ts 
ON scout.silver_transactions(store_id, ts DESC);

-- Index on silver_transactions for product performance
CREATE INDEX IF NOT EXISTS idx_silver_transactions_product 
ON scout.silver_transactions(product_category, brand_name);

-- =====================================================
-- 7. Grant Permissions
-- =====================================================
-- Grant read access to views
GRANT SELECT ON scout.gold_customer_segments TO anon, authenticated;
GRANT SELECT ON scout.gold_store_performance TO anon, authenticated;
GRANT SELECT ON scout.gold_product_performance TO anon, authenticated;
GRANT SELECT ON scout.gold_daily_metrics TO anon, authenticated;

-- Grant execute on functions
GRANT EXECUTE ON FUNCTION scout.get_ai_insights TO anon, authenticated;

-- =====================================================
-- 8. Quick Data Check
-- =====================================================
-- Run this to verify everything is working
DO $$
BEGIN
  RAISE NOTICE 'Checking Scout Analytics Setup...';
  
  -- Check if tables exist
  IF EXISTS (SELECT 1 FROM scout.silver_transactions LIMIT 1) THEN
    RAISE NOTICE '✅ silver_transactions has data';
  ELSE
    RAISE WARNING '⚠️  silver_transactions is empty - load data first';
  END IF;
  
  -- Check views
  IF EXISTS (SELECT 1 FROM scout.gold_customer_segments LIMIT 1) THEN
    RAISE NOTICE '✅ gold_customer_segments is working';
  END IF;
  
  IF EXISTS (SELECT 1 FROM scout.gold_store_performance LIMIT 1) THEN
    RAISE NOTICE '✅ gold_store_performance is working';
  END IF;
  
  IF EXISTS (SELECT 1 FROM scout.gold_product_performance LIMIT 1) THEN
    RAISE NOTICE '✅ gold_product_performance is working';
  END IF;
  
  -- Test AI insights function
  IF EXISTS (SELECT 1 FROM scout.get_ai_insights(1) LIMIT 1) THEN
    RAISE NOTICE '✅ get_ai_insights function is working';
  END IF;
  
  RAISE NOTICE 'Scout Analytics setup complete!';
END $$;

-- =====================================================
-- 9. Sample Queries to Test
-- =====================================================
-- Test customer segments
SELECT * FROM scout.gold_customer_segments LIMIT 5;

-- Test store performance
SELECT * FROM scout.gold_store_performance LIMIT 5;

-- Test product performance
SELECT * FROM scout.gold_product_performance LIMIT 5;

-- Test daily metrics
SELECT * FROM scout.gold_daily_metrics 
WHERE date_key >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY date_key DESC
LIMIT 10;

-- Test AI insights
SELECT * FROM scout.get_ai_insights(5);