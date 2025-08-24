-- ============================================================
-- SKU CATALOG TELCO EXTENSIONS
-- Adds telco products (Globe, Smart, TNT, TM) with load/data packages
-- ============================================================

SET search_path TO masterdata, public;

-- ============================================================
-- TELCO PRODUCTS TABLE
-- ============================================================

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

-- Index for fast lookups
CREATE INDEX idx_telco_network ON masterdata.telco_products(network);
CREATE INDEX idx_telco_type ON masterdata.telco_products(product_type);
CREATE INDEX idx_telco_denomination ON masterdata.telco_products(denomination);

-- ============================================================
-- EXTEND PRODUCTS TABLE FOR HALAL & BARCODES
-- ============================================================

-- Add columns if they don't exist
DO $$
BEGIN
    -- Add halal certification
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'masterdata' 
                   AND table_name = 'products' 
                   AND column_name = 'halal_certified') THEN
        ALTER TABLE masterdata.products 
        ADD COLUMN halal_certified BOOLEAN DEFAULT false;
    END IF;
    
    -- Add barcode if missing (some migrations use 'upc', some use 'barcode')
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'masterdata' 
                   AND table_name = 'products' 
                   AND column_name = 'barcode') THEN
        ALTER TABLE masterdata.products 
        ADD COLUMN barcode TEXT;
    END IF;
    
    -- Add pack size if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'masterdata' 
                   AND table_name = 'products' 
                   AND column_name = 'pack_size') THEN
        ALTER TABLE masterdata.products 
        ADD COLUMN pack_size TEXT;
    END IF;
END $$;

-- ============================================================
-- BARCODE REGISTRY
-- ============================================================

CREATE TABLE IF NOT EXISTS masterdata.barcode_registry (
    barcode TEXT PRIMARY KEY,
    product_id UUID REFERENCES masterdata.products(id) ON DELETE CASCADE,
    barcode_type TEXT CHECK (barcode_type IN ('EAN13', 'UPC', 'CODE128', 'QR')),
    verified BOOLEAN DEFAULT false,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- PRICE HISTORY TRACKING
-- ============================================================

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

CREATE INDEX idx_price_history_product_date ON masterdata.price_history(product_id, price_date DESC);

-- ============================================================
-- TELCO CATALOG VIEWS
-- ============================================================

-- View for telco products with details
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

-- View for halal products
CREATE OR REPLACE VIEW masterdata.v_halal_products AS
SELECT 
    p.id,
    p.product_name,
    b.brand_name,
    p.category,
    p.subcategory,
    p.pack_size,
    p.barcode,
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

-- ============================================================
-- TELCO PRODUCT SEEDING DATA
-- ============================================================

-- Function to seed telco products
CREATE OR REPLACE FUNCTION masterdata.seed_telco_products()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_brand_id UUID;
    v_product_id UUID;
    telco_data RECORD;
BEGIN
    -- Create telco brands if they don't exist
    FOR telco_data IN 
        SELECT * FROM (VALUES
            ('Globe', 'Globe Telecom', 'PH'),
            ('Smart', 'Smart Communications', 'PH'),
            ('TNT', 'Talk N Text', 'PH'),
            ('TM', 'Touch Mobile', 'PH'),
            ('DITO', 'DITO Telecommunity', 'PH')
        ) AS t(brand_name, company, region)
    LOOP
        INSERT INTO masterdata.brands (brand_name, company, region)
        VALUES (telco_data.brand_name, telco_data.company, telco_data.region)
        ON CONFLICT (brand_name) DO NOTHING;
    END LOOP;
    
    -- Insert telco load products
    FOR telco_data IN 
        SELECT * FROM (VALUES
            -- Globe Load
            ('Globe', 'Globe Load 10', 'Telco', 'Load', 10, 'GLOAD10'),
            ('Globe', 'Globe Load 15', 'Telco', 'Load', 15, 'GLOAD15'),
            ('Globe', 'Globe Load 20', 'Telco', 'Load', 20, 'GLOAD20'),
            ('Globe', 'Globe Load 30', 'Telco', 'Load', 30, 'GLOAD30'),
            ('Globe', 'Globe Load 50', 'Telco', 'Load', 50, 'GLOAD50'),
            ('Globe', 'Globe Load 100', 'Telco', 'Load', 100, 'GLOAD100'),
            ('Globe', 'Globe Load 300', 'Telco', 'Load', 300, 'GLOAD300'),
            ('Globe', 'Globe Load 500', 'Telco', 'Load', 500, 'GLOAD500'),
            ('Globe', 'Globe Load 1000', 'Telco', 'Load', 1000, 'GLOAD1000'),
            
            -- Smart Load
            ('Smart', 'Smart Load 10', 'Telco', 'Load', 10, 'SLOAD10'),
            ('Smart', 'Smart Load 15', 'Telco', 'Load', 15, 'SLOAD15'),
            ('Smart', 'Smart Load 20', 'Telco', 'Load', 20, 'SLOAD20'),
            ('Smart', 'Smart Load 30', 'Telco', 'Load', 30, 'SLOAD30'),
            ('Smart', 'Smart Load 50', 'Telco', 'Load', 50, 'SLOAD50'),
            ('Smart', 'Smart Load 100', 'Telco', 'Load', 100, 'SLOAD100'),
            ('Smart', 'Smart Load 300', 'Telco', 'Load', 300, 'SLOAD300'),
            ('Smart', 'Smart Load 500', 'Telco', 'Load', 500, 'SLOAD500'),
            
            -- TNT Load
            ('TNT', 'TNT Load 10', 'Telco', 'Load', 10, 'TLOAD10'),
            ('TNT', 'TNT Load 15', 'Telco', 'Load', 15, 'TLOAD15'),
            ('TNT', 'TNT Load 20', 'Telco', 'Load', 20, 'TLOAD20'),
            ('TNT', 'TNT Load 30', 'Telco', 'Load', 30, 'TLOAD30')
        ) AS t(brand_name, product_name, category, product_type, denomination, barcode)
    LOOP
        -- Get brand ID
        SELECT id INTO v_brand_id FROM masterdata.brands WHERE brand_name = telco_data.brand_name;
        
        -- Insert product
        INSERT INTO masterdata.products (brand_id, product_name, category, subcategory, barcode)
        VALUES (v_brand_id, telco_data.product_name, telco_data.category, telco_data.product_type, telco_data.barcode)
        ON CONFLICT (brand_id, product_name) DO UPDATE
        SET category = EXCLUDED.category, subcategory = EXCLUDED.subcategory
        RETURNING id INTO v_product_id;
        
        -- Insert telco details
        INSERT INTO masterdata.telco_products (product_id, network, product_type, denomination)
        VALUES (v_product_id, telco_data.brand_name, telco_data.product_type, telco_data.denomination)
        ON CONFLICT (product_id) DO UPDATE
        SET denomination = EXCLUDED.denomination;
    END LOOP;
    
    -- Insert data packages
    FOR telco_data IN 
        SELECT * FROM (VALUES
            -- Globe Data
            ('Globe', 'GoSURF50', 'Telco', 'Data', 50, 1024, 3, 'GS50'),
            ('Globe', 'GoSURF299', 'Telco', 'Data', 299, 5120, 30, 'GS299'),
            ('Globe', 'GoUNLI350', 'Telco', 'Data', 350, NULL, 30, 'GOUNLI350'),
            
            -- Smart Data
            ('Smart', 'GigaSurf50', 'Telco', 'Data', 50, 1024, 3, 'GIGA50'),
            ('Smart', 'GigaSurf99', 'Telco', 'Data', 99, 2048, 7, 'GIGA99'),
            ('Smart', 'GigaSurf299', 'Telco', 'Data', 299, 5120, 30, 'GIGA299')
        ) AS t(brand_name, product_name, category, product_type, denomination, data_mb, validity, barcode)
    LOOP
        -- Get brand ID
        SELECT id INTO v_brand_id FROM masterdata.brands WHERE brand_name = telco_data.brand_name;
        
        -- Insert product
        INSERT INTO masterdata.products (brand_id, product_name, category, subcategory, barcode)
        VALUES (v_brand_id, telco_data.product_name, telco_data.category, telco_data.product_type, telco_data.barcode)
        ON CONFLICT (brand_id, product_name) DO UPDATE
        SET category = EXCLUDED.category
        RETURNING id INTO v_product_id;
        
        -- Insert telco details
        INSERT INTO masterdata.telco_products (
            product_id, network, product_type, denomination, 
            data_volume_mb, validity_days
        )
        VALUES (
            v_product_id, telco_data.brand_name, telco_data.product_type, 
            telco_data.denomination, telco_data.data_mb, telco_data.validity
        )
        ON CONFLICT (product_id) DO UPDATE
        SET data_volume_mb = EXCLUDED.data_volume_mb,
            validity_days = EXCLUDED.validity_days;
    END LOOP;
END;
$$;

-- ============================================================
-- ANALYTICS FUNCTIONS
-- ============================================================

-- Function to get telco sales summary
CREATE OR REPLACE FUNCTION masterdata.get_telco_sales_summary(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    network TEXT,
    product_type TEXT,
    total_sales DECIMAL,
    transaction_count BIGINT,
    avg_denomination DECIMAL
)
LANGUAGE sql
STABLE
AS $$
    SELECT 
        tp.network,
        tp.product_type,
        SUM(fti.total_amount) as total_sales,
        COUNT(DISTINCT fti.transaction_id) as transaction_count,
        AVG(tp.denomination) as avg_denomination
    FROM scout.fact_transaction_items fti
    JOIN masterdata.telco_products tp ON tp.product_id = fti.product_id
    JOIN scout.fact_transactions ft ON ft.transaction_id = fti.transaction_id
    WHERE ft.transaction_date BETWEEN p_start_date AND p_end_date
    GROUP BY tp.network, tp.product_type
    ORDER BY total_sales DESC;
$$;

-- Grant permissions
GRANT SELECT ON ALL TABLES IN SCHEMA masterdata TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA masterdata TO authenticated;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_products_halal ON masterdata.products(halal_certified) WHERE halal_certified = true;
CREATE INDEX IF NOT EXISTS idx_products_barcode ON masterdata.products(barcode) WHERE barcode IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_products_category ON masterdata.products(category, subcategory);

-- Seed initial telco products (commented out - run manually if needed)
-- SELECT masterdata.seed_telco_products();