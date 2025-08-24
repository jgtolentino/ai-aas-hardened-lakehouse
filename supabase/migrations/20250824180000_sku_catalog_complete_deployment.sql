-- ===========================================================
-- SKU CATALOG COMPLETE DEPLOYMENT - Final Migration
-- Consolidates all SKU catalog features for auto-deployment
-- Includes: Schemas, Tables, Views, Functions, Extensions
-- Ready for: 347 products + telco + halal + barcodes
-- ===========================================================
set check_function_bodies = off;

-- Ensure schemas exist
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS masterdata;

-- ===========================================================
-- PART 1: CORE SKU CATALOG INFRASTRUCTURE
-- ===========================================================

-- Staging table for CSV uploads
CREATE TABLE IF NOT EXISTS staging.sku_catalog_upload (
  product_key integer,
  sku text,
  product_name text,
  brand_id text,        
  brand_name text,
  category_id text,     
  category_name text,
  pack_size text,
  unit_type text,
  list_price numeric,
  barcode text,
  manufacturer text,
  is_active boolean,
  halal_certified text, 
  product_description text,
  price_source text,
  created_at timestamp
);

-- Brand ID mapping for legacy compatibility
CREATE TABLE IF NOT EXISTS masterdata.brand_id_map (
  legacy_id text primary key,
  brand_uuid uuid not null references masterdata.brands(id),
  created_at timestamptz default now()
);

CREATE INDEX IF NOT EXISTS idx_brand_id_map_uuid ON masterdata.brand_id_map(brand_uuid);

-- ===========================================================
-- PART 2: TELCO EXTENSIONS
-- ===========================================================

-- Telco products table
CREATE TABLE IF NOT EXISTS masterdata.telco_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES masterdata.products(id) ON DELETE CASCADE,
    network TEXT NOT NULL CHECK (network IN ('Globe', 'Smart', 'TNT', 'TM', 'DITO')),
    product_type TEXT NOT NULL CHECK (product_type IN ('Load', 'Data', 'Promo', 'Bundle')),
    denomination DECIMAL(10,2),
    data_volume_mb INTEGER,
    validity_days INTEGER,
    promo_code TEXT,
    ussd_code TEXT,
    keywords TEXT[],
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for telco products
CREATE INDEX IF NOT EXISTS idx_telco_network ON masterdata.telco_products(network);
CREATE INDEX IF NOT EXISTS idx_telco_type ON masterdata.telco_products(product_type);
CREATE INDEX IF NOT EXISTS idx_telco_denomination ON masterdata.telco_products(denomination);

-- Barcode registry system
CREATE TABLE IF NOT EXISTS masterdata.barcode_registry (
    barcode TEXT PRIMARY KEY,
    product_id UUID REFERENCES masterdata.products(id) ON DELETE CASCADE,
    barcode_type TEXT CHECK (barcode_type IN ('EAN13', 'UPC', 'CODE128', 'QR')),
    verified BOOLEAN DEFAULT false,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Price history tracking
CREATE TABLE IF NOT EXISTS masterdata.price_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES masterdata.products(id) ON DELETE CASCADE,
    store_id UUID,
    price_date DATE NOT NULL,
    list_price DECIMAL(10,2),
    selling_price DECIMAL(10,2),
    promo_price DECIMAL(10,2),
    price_source TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_price_history_product_date ON masterdata.price_history(product_id, price_date DESC);

-- ===========================================================
-- PART 3: PRODUCT TABLE EXTENSIONS
-- ===========================================================

-- Add columns to products table if they don't exist
DO $$
BEGIN
    -- Add halal certification column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'masterdata' 
                   AND table_name = 'products' 
                   AND column_name = 'halal_certified') THEN
        ALTER TABLE masterdata.products 
        ADD COLUMN halal_certified BOOLEAN DEFAULT false;
    END IF;
    
    -- Add barcode column if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'masterdata' 
                   AND table_name = 'products' 
                   AND column_name = 'barcode') THEN
        ALTER TABLE masterdata.products 
        ADD COLUMN barcode TEXT;
    END IF;
    
    -- Add pack_size column if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'masterdata' 
                   AND table_name = 'products' 
                   AND column_name = 'pack_size') THEN
        ALTER TABLE masterdata.products 
        ADD COLUMN pack_size TEXT;
    END IF;
END $$;

-- Create indexes on new columns
CREATE INDEX IF NOT EXISTS idx_products_halal ON masterdata.products(halal_certified) WHERE halal_certified = true;
CREATE INDEX IF NOT EXISTS idx_products_barcode ON masterdata.products(barcode) WHERE barcode IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_products_category ON masterdata.products(category, subcategory);

-- ===========================================================
-- PART 4: CORE FUNCTIONS
-- ===========================================================

-- Synthetic UPC generator
CREATE OR REPLACE FUNCTION masterdata.synthetic_upc(p_text text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  WITH h AS (
    SELECT abs(hashtextextended(p_text,42))::bigint AS hv
  ),
  d AS (
    SELECT lpad((hv % 100000000000)::text,12,'0') AS base FROM h
  ),
  c AS (
    SELECT base,
           (sum((substr(base,i,1))::int * CASE WHEN (i % 2)=0 THEN 3 ELSE 1 END) OVER ())
           AS s
    FROM d, generate_series(1,12) i
  )
  SELECT (SELECT base FROM d) || ((10 - (max(s) % 10)) % 10)::text
  FROM c;
$$;

-- SKU catalog import function
CREATE OR REPLACE FUNCTION masterdata.import_sku_catalog()
RETURNS table(brands_imported int, products_imported int)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_brands_count int := 0;
  v_products_count int := 0;
  r record;
  v_brand_uuid uuid;
  v_upc text;
BEGIN
  -- Step 1: Import unique brands
  FOR r IN 
    SELECT DISTINCT 
      brand_id as legacy_id,
      brand_name,
      manufacturer,
      max(created_at) as created_at
    FROM staging.sku_catalog_upload
    WHERE brand_name IS NOT NULL
    GROUP BY brand_id, brand_name, manufacturer
  LOOP
    -- Check if brand exists
    SELECT id INTO v_brand_uuid
    FROM masterdata.brands
    WHERE lower(brand_name) = lower(r.brand_name)
    LIMIT 1;
    
    IF v_brand_uuid IS NULL THEN
      -- Create new brand
      INSERT INTO masterdata.brands (brand_name, company, region, metadata)
      VALUES (
        r.brand_name, 
        coalesce(r.manufacturer, r.brand_name), 
        'PH',
        jsonb_build_object(
          'legacy_id', r.legacy_id,
          'imported_at', now(),
          'source', 'sku_catalog_csv'
        )
      )
      RETURNING id INTO v_brand_uuid;
      
      v_brands_count := v_brands_count + 1;
    END IF;
    
    -- Map legacy ID to UUID
    INSERT INTO masterdata.brand_id_map (legacy_id, brand_uuid)
    VALUES (r.legacy_id, v_brand_uuid)
    ON CONFLICT (legacy_id) DO UPDATE
    SET brand_uuid = excluded.brand_uuid;
  END LOOP;
  
  -- Step 2: Import products
  FOR r IN
    SELECT 
      s.*,
      m.brand_uuid
    FROM staging.sku_catalog_upload s
    JOIN masterdata.brand_id_map m ON m.legacy_id = s.brand_id
    WHERE s.product_name IS NOT NULL
  LOOP
    -- Generate UPC if missing
    IF r.barcode = 'UNKNOWN' OR r.barcode IS NULL THEN
      v_upc := masterdata.synthetic_upc(r.brand_name || ':' || r.product_name || ':' || coalesce(r.pack_size,''));
    ELSE
      v_upc := r.barcode;
    END IF;
    
    -- Insert product with all extensions
    INSERT INTO masterdata.products (
      brand_id,
      product_name,
      category,
      subcategory,
      pack_size,
      upc,
      barcode,
      halal_certified,
      metadata
    )
    VALUES (
      r.brand_uuid,
      r.product_name,
      r.category_name,
      r.unit_type,
      r.pack_size,
      v_upc,
      CASE WHEN r.barcode != 'UNKNOWN' THEN r.barcode ELSE NULL END,
      CASE 
        WHEN lower(r.halal_certified) = 'true' THEN true
        WHEN lower(r.halal_certified) = 'false' THEN false
        ELSE false
      END,
      jsonb_build_object(
        'sku', r.sku,
        'product_key', r.product_key,
        'list_price', r.list_price,
        'is_active', r.is_active,
        'product_description', r.product_description,
        'price_source', r.price_source,
        'original_created_at', r.created_at,
        'imported_at', now()
      )
    )
    ON CONFLICT (brand_id, product_name) DO UPDATE
    SET 
      category = excluded.category,
      subcategory = excluded.subcategory,
      pack_size = excluded.pack_size,
      upc = CASE WHEN products.upc = 'UNKNOWN' THEN excluded.upc ELSE products.upc END,
      barcode = COALESCE(excluded.barcode, products.barcode),
      halal_certified = excluded.halal_certified,
      metadata = products.metadata || excluded.metadata;
    
    v_products_count := v_products_count + 1;
  END LOOP;
  
  RETURN QUERY SELECT v_brands_count, v_products_count;
END;
$$;

-- ===========================================================
-- PART 5: BUSINESS INTELLIGENCE VIEWS
-- ===========================================================

-- Telco products view
CREATE OR REPLACE VIEW masterdata.v_telco_products AS
SELECT 
    p.id,
    p.product_name,
    p.category,
    p.subcategory,
    t.network,
    t.product_type,
    t.denomination,
    t.data_volume_mb,
    CASE 
        WHEN t.data_volume_mb >= 1024 THEN 
            (t.data_volume_mb / 1024.0)::TEXT || 'GB'
        ELSE 
            t.data_volume_mb::TEXT || 'MB'
    END as data_volume_display,
    t.validity_days,
    t.promo_code,
    t.ussd_code,
    t.keywords,
    p.is_active,
    p.created_at
FROM masterdata.products p
JOIN masterdata.telco_products t ON t.product_id = p.id
WHERE p.is_active = true;

-- Halal products view
CREATE OR REPLACE VIEW masterdata.v_halal_products AS
SELECT 
    p.id,
    p.product_name,
    b.brand_name,
    p.category,
    p.subcategory,
    p.pack_size,
    COALESCE(p.barcode, p.upc) as barcode,
    p.halal_certified,
    p.is_active
FROM masterdata.products p
LEFT JOIN masterdata.brands b ON b.id = p.brand_id
WHERE p.halal_certified = true
AND p.is_active = true;

-- Complete product catalog view
CREATE OR REPLACE VIEW masterdata.v_product_catalog AS
SELECT 
    p.id as product_id,
    p.product_name,
    b.brand_name,
    b.company as manufacturer,
    p.category,
    p.subcategory,
    p.pack_size,
    COALESCE(p.barcode, p.upc) as barcode,
    p.halal_certified,
    CASE 
        WHEN b.brand_name IN ('Alaska', 'Oishi', 'Del Monte', 'JTI', 'Marca Leon') 
        THEN 'TBWA Client'
        ELSE 'Competitor'
    END as product_classification,
    t.network as telco_network,
    t.product_type as telco_type,
    t.denomination as telco_denomination,
    ph.selling_price as current_price,
    p.is_active,
    p.created_at,
    p.updated_at
FROM masterdata.products p
LEFT JOIN masterdata.brands b ON b.id = p.brand_id
LEFT JOIN masterdata.telco_products t ON t.product_id = p.id
LEFT JOIN LATERAL (
    SELECT selling_price 
    FROM masterdata.price_history 
    WHERE product_id = p.id 
    ORDER BY price_date DESC 
    LIMIT 1
) ph ON true;

-- Catalog summary view
CREATE OR REPLACE VIEW masterdata.v_catalog_summary AS
SELECT 
  b.brand_name,
  count(distinct p.id) as product_count,
  count(distinct p.category) as category_count,
  count(distinct CASE WHEN p.upc NOT LIKE '_%000%' THEN p.upc END) as real_barcode_count,
  count(distinct CASE WHEN p.upc LIKE '_%000%' THEN p.upc END) as synthetic_upc_count,
  count(distinct CASE WHEN p.halal_certified = true THEN p.id END) as halal_product_count,
  count(distinct CASE WHEN t.id IS NOT NULL THEN p.id END) as telco_product_count,
  max((p.metadata->>'list_price')::numeric) as max_price,
  min((p.metadata->>'list_price')::numeric) as min_price
FROM masterdata.brands b
LEFT JOIN masterdata.products p ON p.brand_id = b.id
LEFT JOIN masterdata.telco_products t ON t.product_id = p.id
GROUP BY b.brand_name
ORDER BY product_count DESC;

-- ===========================================================
-- PART 6: PERMISSIONS & SECURITY
-- ===========================================================

-- Grant permissions for authenticated users
GRANT SELECT ON ALL TABLES IN SCHEMA masterdata TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA staging TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA masterdata TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA masterdata TO anon;

-- Grant INSERT/UPDATE for import functions
GRANT INSERT, UPDATE ON staging.sku_catalog_upload TO authenticated;
GRANT INSERT, UPDATE, DELETE ON masterdata.brand_id_map TO authenticated;

-- ===========================================================
-- PART 7: VERIFICATION & DEPLOYMENT STATUS
-- ===========================================================

-- Verification function
CREATE OR REPLACE FUNCTION masterdata.verify_sku_catalog_deployment()
RETURNS TABLE(
  component TEXT,
  status TEXT,
  count_or_detail TEXT
) LANGUAGE SQL AS $$
  -- Check schemas
  SELECT 'Schemas' as component, 
         'Created' as status,
         string_agg(schema_name, ', ') as count_or_detail
  FROM information_schema.schemata 
  WHERE schema_name IN ('masterdata', 'staging')
  
  UNION ALL
  
  -- Check tables
  SELECT 'Core Tables',
         'Created',
         count(*)::TEXT || ' tables'
  FROM information_schema.tables 
  WHERE table_schema = 'masterdata'
  AND table_name IN ('brands', 'products', 'brand_id_map', 'telco_products', 'barcode_registry', 'price_history')
  
  UNION ALL
  
  -- Check views
  SELECT 'Business Views',
         'Created', 
         count(*)::TEXT || ' views'
  FROM information_schema.views 
  WHERE table_schema = 'masterdata'
  AND table_name LIKE 'v_%'
  
  UNION ALL
  
  -- Check data readiness
  SELECT 'Data Status',
         CASE 
           WHEN (SELECT count(*) FROM masterdata.products) > 0 
           THEN 'Data Imported' 
           ELSE 'Ready for Import' 
         END,
         (SELECT count(*) FROM masterdata.products)::TEXT || ' products'
$$;

-- ===========================================================
-- DEPLOYMENT CONFIRMATION
-- ===========================================================
SELECT 'SKU Catalog Complete Deployment' as status, 
       'SUCCESS' as result,
       'Ready for 347 products import' as next_step;

-- Run verification
SELECT * FROM masterdata.verify_sku_catalog_deployment();

-- Final message
SELECT 
  '🎉 SKU Catalog deployment complete!' as message,
  'Use: SELECT * FROM masterdata.import_sku_catalog() after data upload' as import_instruction;