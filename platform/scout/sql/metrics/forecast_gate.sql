-- platform/scout/sql/metrics/forecast_gate.sql
-- psql script (uses \set / \if / \gset) to compute gates & exit with a failing code if needed.
-- You can override these with -v flags in CI (see GitHub Actions below).

\set ON_ERROR_STOP on

-- Defaults (overridable with -v MODEL_NAME=... etc.)
\set MODEL_NAME     'demand_forecast'
\set MODEL_VERSION  ''             -- empty = latest for that model name
\set DAYS           30
\set SN_PERIOD      7
\set WAPE_TOL       1.02           -- model WAPE must be <= baseline WAPE * tol
\set SMAPE_TOL      1.02           -- model sMAPE must be <= baseline sMAPE * tol
\set MIN_COVERAGE   0.75           -- acceptable coverage lower bound (P10..P90)
\set MAX_COVERAGE   0.90           -- acceptable coverage upper bound

WITH params AS (
  SELECT
    :'MODEL_NAME'::text   AS model_name,
    NULLIF(:'MODEL_VERSION','')::text AS model_version,
    :'DAYS'::int          AS days,
    :'SN_PERIOD'::int     AS sn,
    :'WAPE_TOL'::numeric  AS wape_tol,
    :'SMAPE_TOL'::numeric AS smape_tol,
    :'MIN_COVERAGE'::numeric AS min_cov,
    :'MAX_COVERAGE'::numeric AS max_cov
),
candidate AS (
  SELECT COALESCE(
           (SELECT model_key FROM scout.model_registry
             WHERE model_name = (SELECT model_name FROM params)
               AND ( (SELECT model_version FROM params) IS NULL
                     OR model_version = (SELECT model_version FROM params) )
             ORDER BY created_at DESC LIMIT 1),
           (SELECT model_key FROM scout.v_latest_model_per_name
             WHERE model_name = (SELECT model_name FROM params))
         ) AS model_key
),
-- WINDOW the period for evaluation
hist AS (
  SELECT * FROM scout.v_hist_daily_units
  WHERE day >= CURRENT_DATE - (SELECT (days::text||' days')::interval FROM params)
),
base_err AS (
  -- recompute baseline with chosen seasonal period
  SELECT
    h.store_id, h.product_key, h.day, h.y_units,
    LAG(h.y_units, (SELECT sn FROM params)) OVER (PARTITION BY h.store_id, h.product_key ORDER BY h.day) AS yhat_sn,
    ABS(h.y_units - LAG(h.y_units, (SELECT sn FROM params)) OVER (PARTITION BY h.store_id, h.product_key ORDER BY h.day)) AS ae,
    CASE
      WHEN COALESCE(ABS(h.y_units),0)+COALESCE(ABS(LAG(h.y_units, (SELECT sn FROM params)) OVER (PARTITION BY h.store_id, h.product_key ORDER BY h.day)),0) > 0
        THEN 2.0 * ABS(h.y_units - LAG(h.y_units, (SELECT sn FROM params)) OVER (PARTITION BY h.store_id, h.product_key ORDER BY h.day))
             / (ABS(h.y_units) + ABS(LAG(h.y_units, (SELECT sn FROM params)) OVER (PARTITION BY h.store_id, h.product_key ORDER BY h.day)))
      ELSE NULL
    END AS smape_term
  FROM hist h
),
model_err AS (
  SELECT m.*
  FROM scout.v_model_error_terms m
  JOIN candidate c USING (model_key)
  WHERE m.day >= CURRENT_DATE - (SELECT (days::text||' days')::interval FROM params)
),
agg AS (
  SELECT
    -- Baseline metrics
    SUM(b.ae)::numeric / NULLIF(SUM(b.y_units),0)                      AS wape_baseline,
    AVG(b.smape_term)                                                  AS smape_baseline,
    -- Model metrics
    SUM(m.ae_model)::numeric / NULLIF(SUM(m.y_units),0)                AS wape_model,
    AVG(m.smape_term_model)                                            AS smape_model,
    -- Coverage
    AVG(m.covered_p10_p90)::numeric                                    AS coverage
  FROM base_err b
  JOIN model_err m
    ON m.store_id = b.store_id AND m.product_key = b.product_key AND m.day = b.day
),
gate AS (
  SELECT
    a.*,
    (a.wape_model  <= a.wape_baseline  * (SELECT wape_tol FROM params))  AS wape_ok,
    (a.smape_model <= a.smape_baseline * (SELECT smape_tol FROM params)) AS smape_ok,
    (a.coverage BETWEEN (SELECT min_cov FROM params) AND (SELECT max_cov FROM params)) AS cov_ok
  FROM agg a
)
SELECT
  COALESCE(wape_baseline, 0)            AS wape_baseline,
  COALESCE(wape_model, 1e9)             AS wape_model,
  COALESCE(smape_baseline, 0)           AS smape_baseline,
  COALESCE(smape_model, 1e9)            AS smape_model,
  COALESCE(coverage, 0)                 AS coverage,
  COALESCE(wape_ok,false)               AS wape_ok,
  COALESCE(smape_ok,false)              AS smape_ok,
  COALESCE(cov_ok,false)                AS cov_ok,
  CASE WHEN COALESCE(wape_ok,false) AND COALESCE(smape_ok,false) AND COALESCE(cov_ok,false)
       THEN 1 ELSE 0 END                AS gate_pass
FROM gate
\gset

-- OPTIONAL: persist evaluation summary
INSERT INTO scout.model_evaluations(model_key, window_start, window_end, segment, metrics)
SELECT
  (SELECT model_key FROM candidate),
  CURRENT_DATE - (SELECT days FROM params),
  CURRENT_DATE,
  'GLOBAL',
  jsonb_build_object(
    'wape_baseline', :wape_baseline::numeric,
    'wape_model',    :wape_model::numeric,
    'smape_baseline',:smape_baseline::numeric,
    'smape_model',   :smape_model::numeric,
    'coverage',      :coverage::numeric,
    'pass',          (:gate_pass = 1)
  );

\echo === Forecast Gate Summary =========================================
\echo Model:         :MODEL_NAME  Version: :MODEL_VERSION
\echo Window (days): :DAYS        Seasonal lag (m): :SN_PERIOD
\echo -------------------------------------------------------------------
\echo WAPE  baseline = :wape_baseline   | model = :wape_model    | pass? :wape_ok
\echo sMAPE baseline = :smape_baseline  | model = :smape_model   | pass? :smape_ok
\echo P10–P90 coverage = :coverage      | target [:MIN_COVERAGE,:MAX_COVERAGE] | pass? :cov_ok
\echo -------------------------------------------------------------------
\echo Gate pass? :gate_pass
\echo ===================================================================

-- Exit non-zero if gate fails
\if :gate_pass
  \q 0
\else
  \q 42
\endif