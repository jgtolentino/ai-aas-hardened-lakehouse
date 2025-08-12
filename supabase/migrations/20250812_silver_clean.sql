-- =====================================================================
-- UDFs used by Silver cleaning (safe to re-run)
-- =====================================================================
CREATE OR REPLACE FUNCTION scout.fn_clean_text(p text)
RETURNS text
LANGUAGE sql
IMMUTABLE
RETURNS NULL ON NULL INPUT
AS $$
  SELECT NULLIF(regexp_replace(btrim(replace(replace(p, E'\u00A0',' '), E'\t',' ')), '\s+', ' ', 'g'),'');
$$;

CREATE OR REPLACE FUNCTION scout.fn_norm_unit(p_unit text)
RETURNS text
LANGUAGE sql
IMMUTABLE
RETURNS NULL ON NULL INPUT
AS $$
  WITH u AS (
    SELECT lower(coalesce(p_unit,'')) AS s
  )
  SELECT CASE
    WHEN s IN ('pc','pcs','piece','pieces','piraso','pir','unit','units') THEN 'pc'
    WHEN s IN ('kg','kilo','kilos') THEN 'kg'
    WHEN s IN ('g','gram','grams') THEN 'g'
    WHEN s IN ('l','lt','liter','litre','litro') THEN 'L'
    WHEN s IN ('ml','mL') THEN 'mL'
    WHEN s IN ('dozen','dz','dosena') THEN 'dozen'
    WHEN s IN ('bundle','tali') THEN 'bundle'
    WHEN s IN ('sachet','sakto') THEN 'sachet'
    ELSE NULL
  END FROM u;
$$;

CREATE OR REPLACE FUNCTION scout.fn_std_qty(p_qty numeric, p_unit text)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
RETURNS NULL ON NULL INPUT
AS $$
  WITH u AS (SELECT scout.fn_norm_unit(p_unit) AS u)
  SELECT CASE
    WHEN u.u = 'dozen'  THEN p_qty * 12
    WHEN u.u = 'g'      THEN p_qty / 1000.0  -- grams -> kg
    WHEN u.u = 'mL'     THEN p_qty / 1000.0  -- mL -> L
    WHEN u.u = 'bundle' THEN p_qty           -- leave as-is; treat as count
    WHEN u.u IS NULL    THEN p_qty           -- unknown: keep raw (still flagged)
    ELSE p_qty
  END FROM u;
$$;

CREATE OR REPLACE FUNCTION scout.fn_local_ts(p_utc timestamptz, p_tz_offset_min int)
RETURNS timestamp
LANGUAGE sql
IMMUTABLE
RETURNS NULL ON NULL INPUT
AS $$
  SELECT (p_utc AT TIME ZONE 'UTC') + make_interval(mins => p_tz_offset_min);
$$;

CREATE OR REPLACE FUNCTION scout.fn_money_sanitize(p numeric)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
RETURNS NULL ON NULL INPUT
AS $$
  -- negative or absurdly large values -> NULL (flagged later)
  SELECT CASE WHEN p < 0 OR p > 100000 THEN NULL ELSE round(p::numeric, 2) END;
$$;

CREATE OR REPLACE FUNCTION scout.fn_payment_method(p text)
RETURNS text
LANGUAGE sql
IMMUTABLE
RETURNS NULL ON NULL INPUT
AS $$
  SELECT CASE lower(coalesce(p,'')) 
    WHEN 'cash' THEN 'cash'
    WHEN 'gcash' THEN 'gcash'
    WHEN 'card' THEN 'card'
    WHEN 'credit' THEN 'credit'
    WHEN 'debit' THEN 'debit'
    ELSE 'other' END;
$$;

-- =====================================================================
-- SILVER CLEAN: transactions
-- =====================================================================
CREATE OR REPLACE VIEW scout.silver_transactions_clean AS
WITH src AS (
  SELECT
    t.txn_id,
    t.device_id,
    t.store_id,
    t.txn_ts_utc,          -- timestamptz
    t.tz_offset_min,       -- int minutes relative to UTC
    scout.fn_clean_text(t.payment_method) AS payment_method_raw,
    t.ingested_at,
    t.source,
    t._ingest_batch_id,
    t._row_hash
  FROM scout.bronze_transactions t
),
dedup AS (
  SELECT *,
    row_number() OVER (
      PARTITION BY txn_id
      ORDER BY ingested_at DESC, source DESC
    ) AS _rn
  FROM src
)
SELECT
  d.txn_id,
  d.device_id,
  d.store_id,
  d.txn_ts_utc,
  d.tz_offset_min,
  scout.fn_local_ts(d.txn_ts_utc, d.tz_offset_min) AS txn_ts_local,
  (scout.fn_local_ts(d.txn_ts_utc, d.tz_offset_min))::date AS date,
  extract(hour from scout.fn_local_ts(d.txn_ts_utc, d.tz_offset_min))::int AS hour,
  scout.fn_payment_method(d.payment_method_raw) AS payment_method,
  -- DQ flags
  (d.txn_ts_utc IS NULL)::int                          AS dq_missing_ts,
  (d.tz_offset_min IS NULL)::int                       AS dq_missing_tz,
  (d.store_id IS NULL)::int                            AS dq_missing_store,
  0::int                                               AS dq_other,
  -- provenance
  d.ingested_at, d.source, d._ingest_batch_id, d._row_hash
FROM dedup d
WHERE d._rn = 1;

-- =====================================================================
-- SILVER CLEAN: transaction items
-- =====================================================================
CREATE OR REPLACE VIEW scout.silver_transaction_items_clean AS
WITH src AS (
  SELECT
    i.txn_id,
    i.item_seq,
    i.product_id,
    i.brand_id,                 -- optional if product maps brand
    i.category_id,              -- optional
    scout.fn_clean_text(i.unit_raw)  AS unit_raw,
    i.qty_raw::numeric,
    scout.fn_money_sanitize(i.unit_price_amt)::numeric AS unit_price_amt,
    scout.fn_money_sanitize(i.discount_amt)::numeric   AS discount_amt,
    scout.fn_money_sanitize(i.gross_sales_amt)::numeric AS gross_sales_amt,
    scout.fn_money_sanitize(i.net_sales_amt)::numeric   AS net_sales_amt,
    scout.fn_clean_text(i.detection_method) AS detection_method,
    i.confidence::numeric,
    i.ingested_at,
    i.source,
    i._row_hash
  FROM scout.bronze_transaction_items i
),
dedup AS (
  SELECT *,
    row_number() OVER (
      PARTITION BY txn_id, item_seq
      ORDER BY ingested_at DESC, source DESC
    ) AS _rn
  FROM src
),
norm AS (
  SELECT
    d.*,
    scout.fn_norm_unit(d.unit_raw)      AS uom_std,
    scout.fn_std_qty(d.qty_raw, d.unit_raw) AS qty_std
  FROM dedup d
)
SELECT
  n.txn_id,
  n.item_seq,
  n.product_id,
  COALESCE(n.brand_id, p.brand_id) AS brand_id,
  COALESCE(n.category_id, p.category_id) AS category_id,
  n.unit_raw,
  n.uom_std,
  n.qty_raw,
  n.qty_std,
  n.unit_price_amt,
  n.discount_amt,
  n.gross_sales_amt,
  n.net_sales_amt,
  n.detection_method,
  n.confidence,
  -- DQ flags
  (n.product_id IS NULL)::int                       AS dq_missing_product,
  (n.qty_raw IS NULL OR n.qty_raw <= 0)::int        AS dq_bad_qty,
  (n.uom_std IS NULL)::int                          AS dq_unknown_uom,
  (n.unit_price_amt IS NULL)::int                   AS dq_bad_price,
  (n.net_sales_amt IS NULL)::int                    AS dq_bad_net,
  (n.confidence IS NOT NULL AND n.confidence < 0)::int AS dq_bad_conf,
  -- provenance
  n.ingested_at, n.source, n._row_hash
FROM norm n
LEFT JOIN scout.products p ON p.id = n.product_id
WHERE n._rn = 1;

-- =====================================================================
-- SILVER CLEAN: join items with transactions & stores (ready for Gold)
-- =====================================================================
CREATE OR REPLACE VIEW scout.silver_items_w_txn_store AS
SELECT
  it.*,
  tx.device_id,
  tx.store_id,
  tx.txn_ts_utc,
  tx.tz_offset_min,
  tx.txn_ts_local,
  tx.date,
  tx.hour,
  tx.payment_method,
  s.region_id, s.city_id, s.barangay_id
FROM scout.silver_transaction_items_clean it
JOIN scout.silver_transactions_clean tx USING (txn_id)
JOIN scout.stores s ON s.id = tx.store_id;

-- Expose the clean Silver views via 'public' (RLS inherited from base)
CREATE OR REPLACE VIEW public.silver_transactions_api AS
  SELECT * FROM scout.silver_transactions_clean;

CREATE OR REPLACE VIEW public.silver_txn_items_api AS
  SELECT * FROM scout.silver_transaction_items_clean;

CREATE OR REPLACE VIEW public.silver_items_w_txn_store_api AS
  SELECT * FROM scout.silver_items_w_txn_store;

REVOKE ALL ON public.silver_transactions_api, public.silver_txn_items_api, public.silver_items_w_txn_store_api FROM PUBLIC, anon;
GRANT  SELECT ON public.silver_transactions_api, public.silver_txn_items_api, public.silver_items_w_txn_store_api TO authenticated;

-- If Bronze are *tables*, add indexes (no-op if they exist as views)
CREATE INDEX IF NOT EXISTS idx_bronze_txn_id           ON scout.bronze_transactions (txn_id);
CREATE INDEX IF NOT EXISTS idx_bronze_txn_store_ts     ON scout.bronze_transactions (store_id, txn_ts_utc);
CREATE INDEX IF NOT EXISTS idx_bronze_items_txn_seq    ON scout.bronze_transaction_items (txn_id, item_seq);
CREATE INDEX IF NOT EXISTS idx_bronze_items_product_ts ON scout.bronze_transaction_items (product_id, txn_id);

-- Compatibility shim if gold points to scout.silver_transaction_items
CREATE OR REPLACE VIEW scout.silver_transaction_items AS
  SELECT * FROM scout.silver_transaction_items_clean;

CREATE OR REPLACE VIEW scout.silver_transactions AS
  SELECT * FROM scout.silver_transactions_clean;