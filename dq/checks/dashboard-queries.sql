-- Scout Dashboard SQL Queries
-- These queries power the various dashboard views

-- =====================================================
-- TRENDS PAGE QUERIES
-- =====================================================

-- 1. Hourly Transaction Volume (Time of Day Analysis)
SELECT 
  EXTRACT(HOUR FROM ts_utc AT TIME ZONE 'Asia/Manila') as hour,
  COUNT(*) as transaction_count,
  SUM(transaction_amount) as total_sales,
  AVG(transaction_amount) as avg_basket_value,
  COUNT(DISTINCT store_id) as active_stores
FROM scout_gold_transactions
WHERE ts_utc >= NOW() - INTERVAL '7 days'
GROUP BY hour
ORDER BY hour;

-- 2. Daily Sales Trend
SELECT 
  DATE(ts_utc AT TIME ZONE 'Asia/Manila') as date,
  COUNT(*) as transactions,
  SUM(transaction_amount) as daily_sales,
  AVG(transaction_amount) as avg_transaction,
  COUNT(DISTINCT store_id) as stores_active
FROM scout_gold_transactions
WHERE ts_utc >= NOW() - INTERVAL '30 days'
GROUP BY date
ORDER BY date DESC;

-- 3. Payment Method Distribution
SELECT 
  payment_method,
  COUNT(*) as count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage,
  SUM(transaction_amount) as total_value
FROM scout_gold_transactions
WHERE ts_utc >= NOW() - INTERVAL '7 days'
GROUP BY payment_method
ORDER BY count DESC;

-- =====================================================
-- PRODUCT MIX & COMBOS PAGE QUERIES
-- =====================================================

-- 4. Top Products by Volume
SELECT 
  i.product_name,
  i.brand_name,
  i.category_name,
  SUM(i.qty) as total_quantity,
  COUNT(DISTINCT i.transaction_id) as transaction_count,
  AVG(i.confidence) as avg_confidence
FROM scout_gold_transaction_items i
JOIN scout_gold_transactions t ON i.transaction_id = t.transaction_id
WHERE t.ts_utc >= NOW() - INTERVAL '7 days'
  AND i.confidence >= 0.60  -- Quality gate
GROUP BY i.product_name, i.brand_name, i.category_name
ORDER BY total_quantity DESC
LIMIT 20;

-- 5. Category Performance
SELECT 
  category_name,
  COUNT(DISTINCT transaction_id) as transactions,
  SUM(qty) as units_sold,
  SUM(total_price) as revenue,
  AVG(confidence) as avg_confidence
FROM scout_gold_transaction_items
WHERE transaction_id IN (
  SELECT transaction_id FROM scout_gold_transactions 
  WHERE ts_utc >= NOW() - INTERVAL '7 days'
)
GROUP BY category_name
ORDER BY revenue DESC;

-- 6. Product Combos (Market Basket Analysis)
WITH basket_items AS (
  SELECT 
    i1.transaction_id,
    i1.product_name as product_1,
    i2.product_name as product_2
  FROM scout_gold_transaction_items i1
  JOIN scout_gold_transaction_items i2 
    ON i1.transaction_id = i2.transaction_id 
    AND i1.product_name < i2.product_name
  WHERE i1.confidence >= 0.60 AND i2.confidence >= 0.60
)
SELECT 
  product_1,
  product_2,
  COUNT(*) as combo_count,
  ROUND(COUNT(*) * 100.0 / (
    SELECT COUNT(DISTINCT transaction_id) 
    FROM scout_gold_transactions 
    WHERE ts_utc >= NOW() - INTERVAL '7 days'
  ), 2) as support_percentage
FROM basket_items
GROUP BY product_1, product_2
HAVING COUNT(*) >= 5  -- Minimum support
ORDER BY combo_count DESC
LIMIT 20;

-- 7. Brand Performance Ranking
SELECT 
  brand_name,
  COUNT(DISTINCT transaction_id) as transactions,
  SUM(qty) as units_sold,
  SUM(total_price) as revenue,
  AVG(unit_price) as avg_price,
  AVG(confidence) as avg_confidence
FROM scout_gold_transaction_items
WHERE brand_name IS NOT NULL
  AND transaction_id IN (
    SELECT transaction_id FROM scout_gold_transactions 
    WHERE ts_utc >= NOW() - INTERVAL '30 days'
  )
GROUP BY brand_name
ORDER BY revenue DESC
LIMIT 25;

-- =====================================================
-- BEHAVIOR PAGE QUERIES
-- =====================================================

-- 8. Request Type Analysis
SELECT 
  request_type,
  request_mode,
  COUNT(*) as count,
  AVG(transaction_amount) as avg_basket,
  SUM(CASE WHEN suggestion_offered THEN 1 ELSE 0 END) as suggestions_offered,
  SUM(CASE WHEN suggestion_accepted THEN 1 ELSE 0 END) as suggestions_accepted
FROM scout_gold_transactions
WHERE ts_utc >= NOW() - INTERVAL '7 days'
GROUP BY request_type, request_mode
ORDER BY count DESC;

-- 9. Substitution Patterns
SELECT 
  asked.brand_name as requested_brand,
  final.brand_name as substituted_brand,
  COUNT(*) as substitution_count,
  AVG(t.transaction_amount) as avg_transaction_value
FROM scout_gold_transactions t
LEFT JOIN catalog_brands asked ON t.asked_brand_id = asked.id
LEFT JOIN catalog_brands final ON t.final_brand_id = final.id
WHERE t.asked_brand_id IS NOT NULL 
  AND t.final_brand_id IS NOT NULL
  AND t.asked_brand_id != t.final_brand_id
  AND t.ts_utc >= NOW() - INTERVAL '30 days'
GROUP BY asked.brand_name, final.brand_name
ORDER BY substitution_count DESC;

-- 10. Suggestion Effectiveness
SELECT 
  DATE(ts_utc AT TIME ZONE 'Asia/Manila') as date,
  COUNT(*) FILTER (WHERE suggestion_offered = true) as suggestions_offered,
  COUNT(*) FILTER (WHERE suggestion_accepted = true) as suggestions_accepted,
  CASE 
    WHEN COUNT(*) FILTER (WHERE suggestion_offered = true) > 0 
    THEN ROUND(
      COUNT(*) FILTER (WHERE suggestion_accepted = true) * 100.0 / 
      COUNT(*) FILTER (WHERE suggestion_offered = true), 2
    )
    ELSE 0 
  END as acceptance_rate
FROM scout_gold_transactions
WHERE ts_utc >= NOW() - INTERVAL '14 days'
GROUP BY date
ORDER BY date DESC;

-- 11. Transaction Duration Analysis
SELECT 
  CASE 
    WHEN EXTRACT(EPOCH FROM (tx_end_ts - tx_start_ts)) < 10 THEN '< 10s'
    WHEN EXTRACT(EPOCH FROM (tx_end_ts - tx_start_ts)) < 30 THEN '10-30s'
    WHEN EXTRACT(EPOCH FROM (tx_end_ts - tx_start_ts)) < 60 THEN '30-60s'
    WHEN EXTRACT(EPOCH FROM (tx_end_ts - tx_start_ts)) < 120 THEN '1-2min'
    ELSE '> 2min'
  END as duration_bucket,
  COUNT(*) as count,
  AVG(transaction_amount) as avg_amount,
  AVG(array_length(string_to_array(raw::text, '"product_name"'), 1) - 1) as avg_items
FROM scout_gold_transactions
WHERE ts_utc >= NOW() - INTERVAL '7 days'
GROUP BY duration_bucket
ORDER BY 
  CASE duration_bucket
    WHEN '< 10s' THEN 1
    WHEN '10-30s' THEN 2
    WHEN '30-60s' THEN 3
    WHEN '1-2min' THEN 4
    ELSE 5
  END;

-- =====================================================
-- PROFILING PAGE QUERIES
-- =====================================================

-- 12. Demographics Distribution
SELECT 
  gender,
  age_bracket,
  COUNT(*) as count,
  AVG(transaction_amount) as avg_spend,
  SUM(transaction_amount) as total_spend
FROM scout_gold_transactions
WHERE ts_utc >= NOW() - INTERVAL '30 days'
  AND gender IS NOT NULL
  AND age_bracket IS NOT NULL
GROUP BY gender, age_bracket
ORDER BY count DESC;

-- 13. Geographic Performance
SELECT 
  r.region_name,
  c.city_name,
  COUNT(DISTINCT t.store_id) as store_count,
  COUNT(*) as transactions,
  SUM(t.transaction_amount) as total_sales,
  AVG(t.transaction_amount) as avg_basket
FROM scout_gold_transactions t
LEFT JOIN geo_regions r ON t.region_id = r.id
LEFT JOIN geo_cities c ON t.city_id = c.id
WHERE t.ts_utc >= NOW() - INTERVAL '30 days'
GROUP BY r.region_name, c.city_name
ORDER BY total_sales DESC;

-- 14. Store Performance Ranking
SELECT 
  store_id,
  COUNT(*) as transaction_count,
  SUM(transaction_amount) as total_sales,
  AVG(transaction_amount) as avg_basket,
  COUNT(DISTINCT DATE(ts_utc)) as active_days,
  MAX(ts_utc) as last_transaction
FROM scout_gold_transactions
WHERE ts_utc >= NOW() - INTERVAL '30 days'
GROUP BY store_id
ORDER BY total_sales DESC
LIMIT 50;

-- 15. Customer Profile by Payment Method
SELECT 
  payment_method,
  gender,
  age_bracket,
  COUNT(*) as count,
  AVG(transaction_amount) as avg_spend
FROM scout_gold_transactions
WHERE ts_utc >= NOW() - INTERVAL '30 days'
  AND gender IS NOT NULL
GROUP BY payment_method, gender, age_bracket
ORDER BY payment_method, count DESC;

-- =====================================================
-- QUALITY & CONFIDENCE METRICS
-- =====================================================

-- 16. Data Quality Dashboard
SELECT 
  DATE(t.ts_utc AT TIME ZONE 'Asia/Manila') as date,
  COUNT(DISTINCT t.transaction_id) as total_transactions,
  AVG(i.confidence) as avg_confidence,
  COUNT(*) FILTER (WHERE i.confidence >= 0.90) as high_confidence_items,
  COUNT(*) FILTER (WHERE i.confidence >= 0.60 AND i.confidence < 0.90) as medium_confidence_items,
  COUNT(*) FILTER (WHERE i.confidence < 0.60) as low_confidence_items,
  COUNT(DISTINCT i.detection_method) as detection_methods_used
FROM scout_gold_transactions t
JOIN scout_gold_transaction_items i ON t.transaction_id = i.transaction_id
WHERE t.ts_utc >= NOW() - INTERVAL '7 days'
GROUP BY date
ORDER BY date DESC;

-- 17. Detection Method Performance
SELECT 
  detection_method,
  COUNT(*) as item_count,
  AVG(confidence) as avg_confidence,
  STDDEV(confidence) as confidence_stddev,
  MIN(confidence) as min_confidence,
  MAX(confidence) as max_confidence
FROM scout_gold_transaction_items
WHERE transaction_id IN (
  SELECT transaction_id FROM scout_gold_transactions 
  WHERE ts_utc >= NOW() - INTERVAL '7 days'
)
GROUP BY detection_method
ORDER BY avg_confidence DESC;

-- =====================================================
-- REAL-TIME MONITORING QUERIES
-- =====================================================

-- 18. Last Hour Activity Summary
SELECT 
  COUNT(*) as transactions_last_hour,
  COUNT(DISTINCT store_id) as active_stores,
  SUM(transaction_amount) as revenue_last_hour,
  AVG(transaction_amount) as avg_basket,
  MAX(ts_utc) as latest_transaction,
  EXTRACT(EPOCH FROM (NOW() - MAX(ts_utc))) as seconds_since_last_tx
FROM scout_gold_transactions
WHERE ts_utc >= NOW() - INTERVAL '1 hour';

-- 19. Live Transaction Feed (Last 10)
SELECT 
  t.transaction_id,
  t.store_id,
  t.ts_utc,
  t.transaction_amount,
  t.payment_method,
  t.request_type,
  array_agg(
    json_build_object(
      'product', i.product_name,
      'brand', i.brand_name,
      'qty', i.qty,
      'confidence', i.confidence
    ) ORDER BY i.total_price DESC
  ) as items
FROM scout_gold_transactions t
JOIN scout_gold_transaction_items i ON t.transaction_id = i.transaction_id
WHERE t.ts_utc >= NOW() - INTERVAL '1 hour'
GROUP BY t.transaction_id, t.store_id, t.ts_utc, t.transaction_amount, t.payment_method, t.request_type
ORDER BY t.ts_utc DESC
LIMIT 10;

-- 20. Anomaly Detection - Unusual Patterns
WITH hourly_baseline AS (
  SELECT 
    EXTRACT(HOUR FROM ts_utc AT TIME ZONE 'Asia/Manila') as hour,
    AVG(transaction_amount) as baseline_amount,
    STDDEV(transaction_amount) as stddev_amount
  FROM scout_gold_transactions
  WHERE ts_utc >= NOW() - INTERVAL '30 days'
  GROUP BY hour
)
SELECT 
  t.transaction_id,
  t.store_id,
  t.ts_utc,
  t.transaction_amount,
  b.baseline_amount,
  ROUND((t.transaction_amount - b.baseline_amount) / NULLIF(b.stddev_amount, 0), 2) as z_score
FROM scout_gold_transactions t
JOIN hourly_baseline b ON EXTRACT(HOUR FROM t.ts_utc AT TIME ZONE 'Asia/Manila') = b.hour
WHERE t.ts_utc >= NOW() - INTERVAL '1 hour'
  AND ABS(t.transaction_amount - b.baseline_amount) > 3 * b.stddev_amount
ORDER BY ABS((t.transaction_amount - b.baseline_amount) / NULLIF(b.stddev_amount, 0)) DESC;