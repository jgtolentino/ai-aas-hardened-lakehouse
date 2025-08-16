-- Enable PostGIS and create geographic boundary tables for choropleth maps
-- Supports ADM1 (regions), ADM2 (provinces), ADM3 (cities/municipalities)

BEGIN;

-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Canonical region names and aliases (Philippine regions)
CREATE TABLE IF NOT EXISTS scout.dim_geo_region (
  region_key TEXT PRIMARY KEY,           -- canonical key, e.g., 'NCR'
  region_name TEXT NOT NULL,             -- 'National Capital Region'
  region_code TEXT,                      -- Official region code if available
  aliases TEXT[]                         -- ['NCR','National Capital Region','Metro Manila'] etc.
);

-- Insert all Philippine regions with common aliases
INSERT INTO scout.dim_geo_region(region_key, region_name, aliases) VALUES
  ('NCR', 'National Capital Region', ARRAY['NCR', 'National Capital Region', 'Metro Manila', 'METROPOLITAN MANILA']),
  ('CAR', 'Cordillera Administrative Region', ARRAY['CAR', 'Cordillera Administrative Region', 'Cordillera']),
  ('Region I', 'Ilocos Region', ARRAY['Region I', 'Ilocos Region', 'Ilocos', 'REGION I', 'REGION 1']),
  ('Region II', 'Cagayan Valley', ARRAY['Region II', 'Cagayan Valley', 'REGION II', 'REGION 2']),
  ('Region III', 'Central Luzon', ARRAY['Region III', 'Central Luzon', 'REGION III', 'REGION 3']),
  ('Region IV-A', 'CALABARZON', ARRAY['Region IV-A', 'CALABARZON', 'REGION IV-A', 'REGION IVA', 'REGION 4A']),
  ('MIMAROPA', 'MIMAROPA', ARRAY['MIMAROPA', 'Region IV-B', 'REGION IV-B', 'REGION IVB', 'REGION 4B']),
  ('Region V', 'Bicol Region', ARRAY['Region V', 'Bicol Region', 'Bicol', 'REGION V', 'REGION 5']),
  ('Region VI', 'Western Visayas', ARRAY['Region VI', 'Western Visayas', 'REGION VI', 'REGION 6']),
  ('Region VII', 'Central Visayas', ARRAY['Region VII', 'Central Visayas', 'REGION VII', 'REGION 7']),
  ('Region VIII', 'Eastern Visayas', ARRAY['Region VIII', 'Eastern Visayas', 'REGION VIII', 'REGION 8']),
  ('Region IX', 'Zamboanga Peninsula', ARRAY['Region IX', 'Zamboanga Peninsula', 'REGION IX', 'REGION 9']),
  ('Region X', 'Northern Mindanao', ARRAY['Region X', 'Northern Mindanao', 'REGION X', 'REGION 10']),
  ('Region XI', 'Davao Region', ARRAY['Region XI', 'Davao Region', 'Davao', 'REGION XI', 'REGION 11']),
  ('Region XII', 'SOCCSKSARGEN', ARRAY['Region XII', 'SOCCSKSARGEN', 'REGION XII', 'REGION 12']),
  ('Region XIII', 'Caraga', ARRAY['Region XIII', 'Caraga', 'REGION XIII', 'REGION 13', 'CARAGA']),
  ('BARMM', 'Bangsamoro Autonomous Region in Muslim Mindanao', ARRAY['BARMM', 'Bangsamoro', 'ARMM', 'Autonomous Region in Muslim Mindanao'])
ON CONFLICT (region_key) DO NOTHING;

-- Boundary storage for ADM1 (regions)
CREATE TABLE IF NOT EXISTS scout.geo_adm1_region (
  region_key TEXT PRIMARY KEY,
  region_name TEXT NOT NULL,
  region_psgc TEXT,                          -- Philippine Standard Geographic Code
  geom GEOMETRY(MULTIPOLYGON, 4326) NOT NULL,
  props JSONB DEFAULT '{}'::JSONB,
  area_sqkm NUMERIC,
  population INTEGER,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_adm1_geom ON scout.geo_adm1_region USING GIST(geom);
CREATE INDEX IF NOT EXISTS idx_adm1_region_key ON scout.geo_adm1_region(region_key);

-- Boundary storage for ADM2 (provinces)
CREATE TABLE IF NOT EXISTS scout.geo_adm2_province (
  province_psgc TEXT PRIMARY KEY,            -- 4-digit PSGC code
  province_name TEXT NOT NULL,
  region_key TEXT NOT NULL,
  geom GEOMETRY(MULTIPOLYGON, 4326) NOT NULL,
  props JSONB DEFAULT '{}'::JSONB,
  area_sqkm NUMERIC,
  population INTEGER,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_adm2_geom ON scout.geo_adm2_province USING GIST(geom);
CREATE INDEX IF NOT EXISTS idx_adm2_region ON scout.geo_adm2_province(region_key);

-- Canonical lookup for cities/municipalities (PSGC keys + aliases)
CREATE TABLE IF NOT EXISTS scout.dim_geo_citymun (
  citymun_psgc TEXT PRIMARY KEY,           -- 6-digit PSGC code, e.g., '137404' (Taguig)
  citymun_name TEXT NOT NULL,              -- canonical name
  province_psgc TEXT NOT NULL,             -- 4-digit province code
  region_key TEXT NOT NULL,                -- region reference
  is_city BOOLEAN DEFAULT FALSE,           -- true for cities, false for municipalities
  income_class TEXT,                       -- '1st', '2nd', etc.
  aliases TEXT[] DEFAULT '{}'::TEXT[]
);

CREATE INDEX IF NOT EXISTS idx_citymun_province ON scout.dim_geo_citymun(province_psgc);
CREATE INDEX IF NOT EXISTS idx_citymun_region ON scout.dim_geo_citymun(region_key);

-- Boundary storage for ADM3 (cities/municipalities)
CREATE TABLE IF NOT EXISTS scout.geo_adm3_citymun (
  citymun_psgc TEXT PRIMARY KEY,
  citymun_name TEXT NOT NULL,
  province_psgc TEXT NOT NULL,
  region_key TEXT NOT NULL,
  geom GEOMETRY(MULTIPOLYGON, 4326) NOT NULL,
  props JSONB DEFAULT '{}'::JSONB,
  area_sqkm NUMERIC,
  population INTEGER,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_adm3_geom ON scout.geo_adm3_citymun USING GIST(geom);
CREATE INDEX IF NOT EXISTS idx_adm3_province ON scout.geo_adm3_citymun(province_psgc);
CREATE INDEX IF NOT EXISTS idx_adm3_region ON scout.geo_adm3_citymun(region_key);

-- Simplified geometry tables for faster rendering
CREATE TABLE IF NOT EXISTS scout.geo_adm1_region_gen (
  region_key TEXT PRIMARY KEY,
  geom GEOMETRY(MULTIPOLYGON, 4326) NOT NULL,
  tolerance NUMERIC NOT NULL DEFAULT 0.005    -- ~500m at equator for regions
);

CREATE TABLE IF NOT EXISTS scout.geo_adm2_province_gen (
  province_psgc TEXT PRIMARY KEY,
  geom GEOMETRY(MULTIPOLYGON, 4326) NOT NULL,
  tolerance NUMERIC NOT NULL DEFAULT 0.003    -- ~300m at equator for provinces
);

CREATE TABLE IF NOT EXISTS scout.geo_adm3_citymun_gen (
  citymun_psgc TEXT PRIMARY KEY,
  geom GEOMETRY(MULTIPOLYGON, 4326) NOT NULL,
  tolerance NUMERIC NOT NULL DEFAULT 0.002    -- ~200m at equator for cities
);

CREATE INDEX IF NOT EXISTS idx_adm1_gen_geom ON scout.geo_adm1_region_gen USING GIST(geom);
CREATE INDEX IF NOT EXISTS idx_adm2_gen_geom ON scout.geo_adm2_province_gen USING GIST(geom);
CREATE INDEX IF NOT EXISTS idx_adm3_gen_geom ON scout.geo_adm3_citymun_gen USING GIST(geom);

COMMIT;