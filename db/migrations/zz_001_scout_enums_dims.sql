-- Scout Data Model: Enums and Dimensions
-- Production-grade schema following exact data dictionary

BEGIN;

-- Create schema
CREATE SCHEMA IF NOT EXISTS scout;

-- 1) Create all enum types per data contract
CREATE TYPE scout.time_of_day_t AS ENUM ('morning', 'afternoon', 'evening', 'night');
CREATE TYPE scout.request_mode_t AS ENUM ('verbal', 'pointing', 'indirect');
CREATE TYPE scout.request_type_t AS ENUM ('branded', 'unbranded', 'point', 'indirect');
CREATE TYPE scout.gender_t AS ENUM ('male', 'female', 'unknown');
CREATE TYPE scout.age_bracket_t AS ENUM ('18-24', '25-34', '35-44', '45-54', '55+', 'unknown');
CREATE TYPE scout.payment_method_t AS ENUM ('cash', 'gcash', 'maya', 'credit', 'other');
CREATE TYPE scout.customer_type_t AS ENUM ('regular', 'occasional', 'new', 'unknown');
CREATE TYPE scout.store_type_t AS ENUM ('urban_high', 'urban_medium', 'residential', 'rural', 'transport', 'other');
CREATE TYPE scout.economic_class_t AS ENUM ('A', 'B', 'C', 'D', 'E', 'unknown');
CREATE TYPE scout.substitution_reason_t AS ENUM ('stockout', 'suggestion', 'unknown');

-- 2) Dimension tables (normalized lookups)
CREATE TABLE IF NOT EXISTS scout.dim_store (
    store_id TEXT PRIMARY KEY,
    store_name TEXT NOT NULL,
    store_type scout.store_type_t NOT NULL,
    barangay TEXT NOT NULL,
    city TEXT NOT NULL,
    province TEXT NOT NULL,
    region TEXT NOT NULL,
    latitude NUMERIC(10,7),
    longitude NUMERIC(10,7),
    economic_class scout.economic_class_t NOT NULL,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS scout.dim_category (
    category TEXT PRIMARY KEY,
    category_group TEXT NOT NULL,
    display_name TEXT NOT NULL,
    sort_order INT DEFAULT 0,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS scout.dim_brand (
    brand_name TEXT PRIMARY KEY,
    brand_owner TEXT,
    is_tbwa_client BOOLEAN DEFAULT false,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS scout.dim_sku (
    sku TEXT PRIMARY KEY,
    product_name TEXT NOT NULL,
    brand_name TEXT NOT NULL REFERENCES scout.dim_brand(brand_name),
    category TEXT NOT NULL REFERENCES scout.dim_category(category),
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
    pack_size TEXT,
    barcode TEXT,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3) Indexes on dimensions
CREATE INDEX idx_dim_store_geo ON scout.dim_store(region, province, city, barangay);
CREATE INDEX idx_dim_store_type ON scout.dim_store(store_type);
CREATE INDEX idx_dim_sku_brand ON scout.dim_sku(brand_name);
CREATE INDEX idx_dim_sku_category ON scout.dim_sku(category);

-- 4) Update triggers
CREATE OR REPLACE FUNCTION scout.update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_dim_store_timestamp
    BEFORE UPDATE ON scout.dim_store
    FOR EACH ROW EXECUTE FUNCTION scout.update_timestamp();

CREATE TRIGGER update_dim_sku_timestamp
    BEFORE UPDATE ON scout.dim_sku
    FOR EACH ROW EXECUTE FUNCTION scout.update_timestamp();

-- 5) Seed some critical categories (from your dictionary)
INSERT INTO scout.dim_category (category, category_group, display_name) VALUES
    ('beverages', 'fmcg', 'Beverages'),
    ('snacks', 'fmcg', 'Snacks'),
    ('personal_care', 'fmcg', 'Personal Care'),
    ('household', 'fmcg', 'Household'),
    ('tobacco', 'controlled', 'Tobacco'),
    ('alcohol', 'controlled', 'Alcohol')
ON CONFLICT (category) DO NOTHING;

COMMIT;