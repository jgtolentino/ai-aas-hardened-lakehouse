-- platform/scout/sql/metrics/backtest_model_30d.sql
-- Compares a model's forecasts to seasonal-naïve baseline and computes coverage
-- Assumptions:
--   - scout.model_registry(model_key, model_name, model_version, created_at)
--   - scout.platinum_forecasts(model_key, store_id, product_key, forecast_date, y_hat, p10, p50, p90)

SET search_path TO scout, public;

-- 1) Latest model per name (helper view)
CREATE OR REPLACE VIEW scout.v_latest_model_per_name AS
SELECT DISTINCT ON (model_name)
  model_name, model_version, model_key, created_at
FROM scout.model_registry
ORDER BY model_name, created_at DESC;

-- 2) Join actuals with candidate model forecasts (last 60 days; CI will window to :DAYS)
CREATE OR REPLACE VIEW scout.v_model_backtest_join AS
SELECT
  a.store_id, a.product_key, a.day,
  a.y_units,
  pf.model_key,
  pf.y_hat::numeric        AS yhat_model,
  pf.p10::numeric          AS p10,
  pf.p50::numeric          AS p50,
  pf.p90::numeric          AS p90
FROM scout.v_hist_daily_units a
JOIN scout.platinum_forecasts pf
  ON pf.store_id = a.store_id
 AND pf.product_key = a.product_key
 AND pf.forecast_date = a.day
WHERE a.day >= CURRENT_DATE - INTERVAL '60 days';

-- 3) Pointwise error terms for model
CREATE OR REPLACE VIEW scout.v_model_error_terms AS
SELECT
  store_id, product_key, day, model_key, y_units, yhat_model, p10, p50, p90,
  ABS(y_units - yhat_model)                         AS ae_model,
  CASE
    WHEN COALESCE(ABS(y_units),0)+COALESCE(ABS(yhat_model),0) > 0
      THEN 2.0 * ABS(y_units - yhat_model) / (ABS(y_units) + ABS(yhat_model))
    ELSE NULL
  END AS smape_term_model,
  CASE WHEN p10 IS NOT NULL AND p90 IS NOT NULL
         AND y_units BETWEEN LEAST(p10,p90) AND GREATEST(p10,p90)
       THEN 1 ELSE 0 END                           AS covered_p10_p90
FROM scout.v_model_backtest_join;