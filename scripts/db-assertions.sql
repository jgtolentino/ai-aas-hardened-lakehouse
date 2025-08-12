-- Post-ingest DB assertions (fail loud if something's off)

-- Recent Bronze arrivals (last 15 min)
SELECT COUNT(*) AS bronze_txns
FROM scout.bronze_transactions
WHERE ingested_at >= now() - interval '15 minutes';

-- Clean Silver rows for those arrivals
SELECT COUNT(*) AS silver_items
FROM scout.silver_transaction_items_clean i
JOIN scout.silver_transactions_clean t USING (txn_id)
WHERE t.ingested_at >= now() - interval '15 minutes';

-- Gold daily aggregates moved
SELECT date, SUM(net_sales_amt) AS net_sales
FROM public.gold_sales_day_api
WHERE date >= current_date - 7
GROUP BY 1 ORDER BY 1 DESC LIMIT 7;

-- DQ health should be "good/warn", not "bad", for today
SELECT dq_health_bucket, COUNT(*) 
FROM scout.silver_dq_daily_summary
WHERE date = current_date
GROUP BY 1;

-- Check data flow integrity
WITH bronze_counts AS (
  SELECT 
    COUNT(*) as bronze_txns,
    COUNT(DISTINCT store_id) as bronze_stores
  FROM scout.bronze_transactions
  WHERE ingested_at >= current_date
),
silver_counts AS (
  SELECT 
    COUNT(*) as silver_txns,
    COUNT(DISTINCT store_id) as silver_stores,
    AVG(CASE WHEN dq_missing_ts = 0 THEN 1.0 ELSE 0.0 END) as ts_quality
  FROM scout.silver_transactions_clean
  WHERE date >= current_date
),
gold_counts AS (
  SELECT 
    COUNT(*) as gold_items,
    SUM(net_sales_amt) as total_sales
  FROM public.gold_txn_items_api
  WHERE date >= current_date
)
SELECT 
  b.bronze_txns,
  s.silver_txns,
  g.gold_items,
  ROUND(s.ts_quality * 100, 1) as timestamp_quality_pct,
  ROUND(g.total_sales, 2) as total_sales_today
FROM bronze_counts b, silver_counts s, gold_counts g;