-- ================================================
-- Scout Alignment Cleanup (2025-08-23)
-- - Standardize on plural dimension tables
-- - Migrate data from singular -> plural (idempotent)
-- - Repoint FKs from facts to plural dims
-- - Provide backwards-compatibility views (singular names)
-- - Normalize API function signatures
-- ================================================
BEGIN;

SET search_path TO scout, public;

-- ---------- Helper: merge tables by intersecting columns ----------
CREATE OR REPLACE FUNCTION scout._merge_dim_tables(
  p_src regclass,         -- singular table (e.g., scout.dim_store)
  p_dst regclass,         -- plural table   (e.g., scout.dim_stores)
  p_pk  text              -- primary key column name (e.g., 'store_key')
) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  cols text;
BEGIN
  -- Build intersecting column list (excluding generated/computed)
  SELECT string_agg(c.column_name, ', ' ORDER BY c.ordinal_position)
    INTO cols
  FROM information_schema.columns c
  WHERE c.table_schema = split_part(p_src::text, '.', 1)
    AND c.table_name   = split_part(p_src::text, '.', 2)
    AND c.column_name IN (
      SELECT c2.column_name
      FROM information_schema.columns c2
      WHERE c2.table_schema = split_part(p_dst::text, '.', 1)
        AND c2.table_name   = split_part(p_dst::text, '.', 2)
    );

  IF cols IS NULL THEN
    RAISE NOTICE 'No common columns between % and %', p_src, p_dst;
    RETURN;
  END IF;

  EXECUTE format($fmt$
    INSERT INTO %s (%s)
    SELECT %s
    FROM %s s
    WHERE NOT EXISTS (
      SELECT 1 FROM %s d WHERE d.%I = s.%I
    );
  $fmt$, p_dst, cols, cols, p_src, p_dst, p_pk, p_pk);

  RAISE NOTICE 'Merged data from % to %', p_src, p_dst;
END;
$$;

-- ---------- 1) Ensure plural dims exist (if a project missed them) ----------
-- (No-op if they already exist)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                 WHERE n.nspname='scout' AND c.relname='dim_stores' AND c.relkind='r') THEN
    RAISE EXCEPTION 'Missing table scout.dim_stores: create it before running this migration.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                 WHERE n.nspname='scout' AND c.relname='dim_products' AND c.relkind='r') THEN
    RAISE EXCEPTION 'Missing table scout.dim_products.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                 WHERE n.nspname='scout' AND c.relname='dim_customers' AND c.relkind='r') THEN
    RAISE EXCEPTION 'Missing table scout.dim_customers.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                 WHERE n.nspname='scout' AND c.relname='dim_campaigns' AND c.relkind='r') THEN
    RAISE EXCEPTION 'Missing table scout.dim_campaigns.';
  END IF;
END$$;

-- ---------- 2) Merge singular -> plural (idempotent) ----------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
             WHERE n.nspname='scout' AND c.relname='dim_store' AND c.relkind='r') THEN
    PERFORM scout._merge_dim_tables('scout.dim_store', 'scout.dim_stores', 'store_key');
  END IF;

  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
             WHERE n.nspname='scout' AND c.relname='dim_product' AND c.relkind='r') THEN
    PERFORM scout._merge_dim_tables('scout.dim_product', 'scout.dim_products', 'product_key');
  END IF;

  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
             WHERE n.nspname='scout' AND c.relname='dim_customer' AND c.relkind='r') THEN
    PERFORM scout._merge_dim_tables('scout.dim_customer', 'scout.dim_customers', 'customer_key');
  END IF;

  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
             WHERE n.nspname='scout' AND c.relname='dim_campaign' AND c.relkind='r') THEN
    PERFORM scout._merge_dim_tables('scout.dim_campaign', 'scout.dim_campaigns', 'campaign_key');
  END IF;
END$$;

-- ---------- 3) Repoint foreign keys in fact tables to plural dims ----------
-- Drop FKs referencing singular tables (if any), then recreate to plural.
DO $$
DECLARE
  rec record;
BEGIN
  FOR rec IN
    SELECT con.oid AS con_oid, con.conname, rel_t.relname AS src_table,
           nsp_t.nspname AS src_schema, con.conrelid, con.confrelid,
           rel_fk.relname AS ref_table, nsp_fk.nspname AS ref_schema
    FROM pg_constraint con
    JOIN pg_class rel_t   ON rel_t.oid = con.conrelid
    JOIN pg_namespace nsp_t ON nsp_t.oid = rel_t.relnamespace
    JOIN pg_class rel_fk  ON rel_fk.oid = con.confrelid
    JOIN pg_namespace nsp_fk ON nsp_fk.oid = rel_fk.relnamespace
    WHERE con.contype='f'
      AND nsp_fk.nspname='scout'
      AND rel_fk.relname IN ('dim_store','dim_product','dim_customer','dim_campaign')
  LOOP
    EXECUTE format('ALTER TABLE %I.%I DROP CONSTRAINT %I', rec.src_schema, rec.src_table, rec.conname);
  END LOOP;
END$$;

-- Recreate canonical FKs (facts -> plural dims). This assumes standard column names.
-- Adjust if your schema deviates.
ALTER TABLE IF EXISTS scout.fact_transactions
  ADD CONSTRAINT fact_transactions_store_fk    FOREIGN KEY (store_key)    REFERENCES scout.dim_stores(store_key),
  ADD CONSTRAINT fact_transactions_product_fk  FOREIGN KEY (product_key)  REFERENCES scout.dim_products(product_key) DEFERRABLE INITIALLY DEFERRED,
  ADD CONSTRAINT fact_transactions_customer_fk FOREIGN KEY (customer_key) REFERENCES scout.dim_customers(customer_key),
  ADD CONSTRAINT fact_transactions_campaign_fk FOREIGN KEY (campaign_key) REFERENCES scout.dim_campaigns(campaign_key);

ALTER TABLE IF EXISTS scout.fact_transaction_items
  ADD CONSTRAINT fact_items_product_fk   FOREIGN KEY (product_key)  REFERENCES scout.dim_products(product_key),
  ADD CONSTRAINT fact_items_trans_fk     FOREIGN KEY (transaction_id) REFERENCES scout.fact_transactions(transaction_id);

ALTER TABLE IF EXISTS scout.fact_daily_sales
  ADD CONSTRAINT fact_daily_sales_product_fk FOREIGN KEY (product_key) REFERENCES scout.dim_products(product_key),
  ADD CONSTRAINT fact_daily_sales_store_fk   FOREIGN KEY (store_key)   REFERENCES scout.dim_stores(store_key),
  ADD CONSTRAINT fact_daily_sales_date_fk    FOREIGN KEY (date_key)    REFERENCES scout.dim_date(date_key);

-- ---------- 4) Drop singular tables; re-create compatibility views ----------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
             WHERE n.nspname='scout' AND c.relname='dim_store' AND c.relkind='r') THEN
    DROP TABLE scout.dim_store CASCADE;
    CREATE OR REPLACE VIEW scout.dim_store AS SELECT * FROM scout.dim_stores;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
             WHERE n.nspname='scout' AND c.relname='dim_product' AND c.relkind='r') THEN
    DROP TABLE scout.dim_product CASCADE;
    CREATE OR REPLACE VIEW scout.dim_product AS SELECT * FROM scout.dim_products;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
             WHERE n.nspname='scout' AND c.relname='dim_customer' AND c.relkind='r') THEN
    DROP TABLE scout.dim_customer CASCADE;
    CREATE OR REPLACE VIEW scout.dim_customer AS SELECT * FROM scout.dim_customers;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
             WHERE n.nspname='scout' AND c.relname='dim_campaign' AND c.relkind='r') THEN
    DROP TABLE scout.dim_campaign CASCADE;
    CREATE OR REPLACE VIEW scout.dim_campaign AS SELECT * FROM scout.dim_campaigns;
  END IF;
END$$;

-- ---------- 5) Normalize function signatures ----------
-- Canonical: parameterized version; keep zero-arg wrapper for backward-compat.

-- a) get_dashboard_kpis
CREATE OR REPLACE FUNCTION scout.get_dashboard_kpis(
  p_start_date date,
  p_end_date   date
) RETURNS TABLE (
  kpi_name text,
  kpi_value numeric,
  kpi_delta numeric,
  as_of_date date
) LANGUAGE sql STABLE AS $$
  SELECT k.kpi_name, k.kpi_value, k.kpi_delta, k.as_of_date
  FROM scout.gold_overview_kpis k
  WHERE k.as_of_date BETWEEN p_start_date AND p_end_date
$$;

CREATE OR REPLACE FUNCTION scout.get_dashboard_kpis()  -- wrapper: last 30 days
RETURNS TABLE (
  kpi_name text,
  kpi_value numeric,
  kpi_delta numeric,
  as_of_date date
) LANGUAGE sql STABLE AS $$
  SELECT * FROM scout.get_dashboard_kpis(CURRENT_DATE - 30, CURRENT_DATE);
$$;

-- b) get_brand_market_share — document two variants; ensure both exist.
-- Variant 1: explicit dates + filters
CREATE OR REPLACE FUNCTION scout.get_brand_market_share(
  p_start_date date,
  p_end_date   date,
  p_brand      text DEFAULT NULL,
  p_category   text DEFAULT NULL
) RETURNS TABLE (
  brand text,
  category text,
  market_share numeric,
  period_start date,
  period_end date
) LANGUAGE sql STABLE AS $$
  SELECT
    g.brand, g.category, g.market_share, p_start_date, p_end_date
  FROM scout.gold_brand_share g
  WHERE (p_brand    IS NULL OR g.brand = p_brand)
    AND (p_category IS NULL OR g.category = p_category)
    AND g.as_of_date BETWEEN p_start_date AND p_end_date
$$;

-- Variant 2: compact signature (brand, category) -> defaults to current month
CREATE OR REPLACE FUNCTION scout.get_brand_market_share(
  p_brand    text,
  p_category text
) RETURNS TABLE (
  brand text,
  category text,
  market_share numeric,
  period_start date,
  period_end date
) LANGUAGE sql STABLE AS $$
  SELECT *
  FROM scout.get_brand_market_share(
    date_trunc('month', CURRENT_DATE)::date,
    (date_trunc('month', CURRENT_DATE) + interval '1 month - 1 day')::date,
    p_brand, p_category
  );
$$;

-- ---------- 6) Add timed deprecation notice ----------
CREATE TABLE IF NOT EXISTS scout.deprecation_notices (
  id serial PRIMARY KEY,
  object_type varchar(50) NOT NULL,
  object_name varchar(255) NOT NULL,
  deprecation_date date NOT NULL,
  removal_date date NOT NULL,
  migration_note text,
  created_at timestamp DEFAULT now()
);

INSERT INTO scout.deprecation_notices (object_type, object_name, deprecation_date, removal_date, migration_note)
VALUES 
  ('VIEW', 'scout.dim_store', CURRENT_DATE, CURRENT_DATE + interval '90 days', 'Use scout.dim_stores instead'),
  ('VIEW', 'scout.dim_product', CURRENT_DATE, CURRENT_DATE + interval '90 days', 'Use scout.dim_products instead'),
  ('VIEW', 'scout.dim_customer', CURRENT_DATE, CURRENT_DATE + interval '90 days', 'Use scout.dim_customers instead'),
  ('VIEW', 'scout.dim_campaign', CURRENT_DATE, CURRENT_DATE + interval '90 days', 'Use scout.dim_campaigns instead');

-- Create function to check deprecations
CREATE OR REPLACE FUNCTION scout.check_deprecations()
RETURNS TABLE (
  days_until_removal integer,
  object_type varchar,
  object_name varchar,
  migration_note text
) LANGUAGE sql STABLE AS $$
  SELECT 
    (removal_date - CURRENT_DATE)::integer as days_until_removal,
    object_type,
    object_name,
    migration_note
  FROM scout.deprecation_notices
  WHERE removal_date > CURRENT_DATE
  ORDER BY removal_date;
$$;

-- ---------- 7) Housekeeping ----------
DROP FUNCTION IF EXISTS scout._merge_dim_tables(regclass, regclass, text); -- keep schema clean

COMMIT;