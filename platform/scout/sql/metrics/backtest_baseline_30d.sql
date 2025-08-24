-- platform/scout/sql/metrics/backtest_baseline_30d.sql
-- Baseline & historical daily actuals for seasonality-naïve backtests
-- Assumptions:
--   - fact_transactions (date_key, store_key, transaction_id)
--   - fact_transaction_items (transaction_id, product_key, quantity, line_amount)
--   - dim_date (date_key, full_date)
--   - dim_products (product_key, is_current)
--   - dim_stores (store_key, store_id, is_current)
-- Adjust joins if your naming differs.

SET search_path TO scout, public;

-- 1) Daily actual units per store×product (last 180 days to support rolling windows)
CREATE OR REPLACE VIEW scout.v_hist_daily_units AS
SELECT
  s.store_id,
  p.product_key,
  d.full_date AS day,
  SUM(i.quantity)::int AS y_units,
  SUM(i.line_amount)::numeric(14,2) AS y_revenue
FROM scout.fact_transactions f
JOIN scout.dim_date d       ON d.date_key  = f.date_key
JOIN scout.dim_stores s     ON s.store_key = f.store_key AND s.is_current
JOIN scout.fact_transaction_items i ON i.transaction_id = f.transaction_id
JOIN scout.dim_products p   ON p.product_key = i.product_key AND p.is_current
WHERE d.full_date >= CURRENT_DATE - INTERVAL '180 days'
GROUP BY 1,2,3;

-- 2) Seasonal-naïve baseline with m=7 lag (you can change m in the CI gate)
CREATE OR REPLACE VIEW scout.v_baseline_seasonal_naive AS
SELECT
  store_id, product_key, day,
  y_units,
  LAG(y_units, 7) OVER (PARTITION BY store_id, product_key ORDER BY day) AS yhat_sn_7
FROM scout.v_hist_daily_units;

-- 3) Pointwise error terms (sMAPE term & absolute error) to allow aggregation
CREATE OR REPLACE VIEW scout.v_baseline_error_terms AS
SELECT
  store_id, product_key, day, y_units, yhat_sn_7,
  -- Weighted AE (for WAPE later)
  ABS(y_units - yhat_sn_7)                        AS ae,
  -- sMAPE term (skip when both 0)
  CASE
    WHEN COALESCE(ABS(y_units),0)+COALESCE(ABS(yhat_sn_7),0) > 0
      THEN 2.0 * ABS(y_units - yhat_sn_7) / (ABS(y_units) + ABS(yhat_sn_7))
    ELSE NULL
  END AS smape_term
FROM scout.v_baseline_seasonal_naive;