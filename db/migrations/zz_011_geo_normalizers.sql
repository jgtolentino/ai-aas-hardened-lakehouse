-- Region and geographic name normalization functions
-- Handles variations in naming conventions across data sources

BEGIN;

-- Normalizer for region text -> region_key
-- Handles common variations and aliases
CREATE OR REPLACE FUNCTION scout.norm_region(t TEXT)
RETURNS TEXT 
LANGUAGE plpgsql 
IMMUTABLE 
AS $$
DECLARE 
  u TEXT := UPPER(REGEXP_REPLACE(COALESCE(t,''), '\s+', ' ', 'g'));
  r TEXT;
BEGIN
  -- Quick wins for common variations
  IF u IN ('NCR', 'METRO MANILA', 'NATIONAL CAPITAL REGION', 'METROPOLITAN MANILA') THEN 
    RETURN 'NCR'; 
  END IF;
  
  IF u IN ('CALABARZON', 'REGION IV-A', 'REGION IVA', 'REGION 4A', 'REGION 4-A') THEN 
    RETURN 'Region IV-A'; 
  END IF;
  
  IF u IN ('CENTRAL LUZON', 'REGION III', 'REGION 3') THEN 
    RETURN 'Region III'; 
  END IF;
  
  IF u IN ('CENTRAL VISAYAS', 'REGION VII', 'REGION 7') THEN 
    RETURN 'Region VII'; 
  END IF;
  
  IF u IN ('DAVAO', 'DAVAO REGION', 'REGION XI', 'REGION 11') THEN 
    RETURN 'Region XI'; 
  END IF;
  
  IF u IN ('WESTERN VISAYAS', 'REGION VI', 'REGION 6') THEN 
    RETURN 'Region VI'; 
  END IF;
  
  IF u IN ('BICOL', 'BICOL REGION', 'REGION V', 'REGION 5') THEN 
    RETURN 'Region V'; 
  END IF;
  
  IF u IN ('ILOCOS', 'ILOCOS REGION', 'REGION I', 'REGION 1') THEN 
    RETURN 'Region I'; 
  END IF;
  
  IF u IN ('CAGAYAN VALLEY', 'REGION II', 'REGION 2') THEN 
    RETURN 'Region II'; 
  END IF;
  
  IF u IN ('EASTERN VISAYAS', 'REGION VIII', 'REGION 8') THEN 
    RETURN 'Region VIII'; 
  END IF;
  
  IF u IN ('ZAMBOANGA PENINSULA', 'REGION IX', 'REGION 9') THEN 
    RETURN 'Region IX'; 
  END IF;
  
  IF u IN ('NORTHERN MINDANAO', 'REGION X', 'REGION 10') THEN 
    RETURN 'Region X'; 
  END IF;
  
  IF u IN ('SOCCSKSARGEN', 'REGION XII', 'REGION 12') THEN 
    RETURN 'Region XII'; 
  END IF;
  
  IF u IN ('CARAGA', 'REGION XIII', 'REGION 13') THEN 
    RETURN 'Region XIII'; 
  END IF;
  
  IF u IN ('CAR', 'CORDILLERA', 'CORDILLERA ADMINISTRATIVE REGION') THEN 
    RETURN 'CAR'; 
  END IF;
  
  IF u IN ('MIMAROPA', 'REGION IV-B', 'REGION IVB', 'REGION 4B', 'REGION 4-B') THEN 
    RETURN 'MIMAROPA'; 
  END IF;
  
  IF u LIKE '%BARMM%' OR u LIKE '%BANGSAMORO%' OR u LIKE '%ARMM%' THEN 
    RETURN 'BARMM'; 
  END IF;

  -- Fallback: search alias table
  SELECT region_key INTO r
  FROM scout.dim_geo_region
  WHERE UPPER(region_name) = u 
     OR u = ANY(SELECT UPPER(a) FROM UNNEST(aliases) a)
  LIMIT 1;

  RETURN COALESCE(r, t);
END $$;

-- City/Municipality name normalizer -> PSGC code
CREATE OR REPLACE FUNCTION scout.norm_citymun(city_name TEXT, province_name TEXT DEFAULT NULL)
RETURNS TEXT 
LANGUAGE plpgsql 
IMMUTABLE 
AS $$
DECLARE 
  k TEXT;
  u_city TEXT := UPPER(TRIM(COALESCE(city_name, '')));
  u_prov TEXT := UPPER(TRIM(COALESCE(province_name, '')));
BEGIN
  IF city_name IS NULL THEN RETURN NULL; END IF;
  
  -- Try exact match first
  SELECT citymun_psgc INTO k
  FROM scout.dim_geo_citymun
  WHERE UPPER(citymun_name) = u_city
    AND (province_name IS NULL OR UPPER(province_psgc) IN (
      SELECT province_psgc FROM scout.geo_adm2_province 
      WHERE UPPER(province_name) = u_prov
    ))
  LIMIT 1;
  
  IF k IS NOT NULL THEN RETURN k; END IF;
  
  -- Try alias match
  SELECT citymun_psgc INTO k
  FROM scout.dim_geo_citymun
  WHERE u_city = ANY(SELECT UPPER(a) FROM UNNEST(aliases) a)
    AND (province_name IS NULL OR UPPER(province_psgc) IN (
      SELECT province_psgc FROM scout.geo_adm2_province 
      WHERE UPPER(province_name) = u_prov
    ))
  LIMIT 1;
  
  RETURN k;
END $$;

-- Add PSGC columns to dim_store if not exists
ALTER TABLE scout.dim_store 
  ADD COLUMN IF NOT EXISTS citymun_psgc TEXT,
  ADD COLUMN IF NOT EXISTS province_psgc TEXT,
  ADD COLUMN IF NOT EXISTS region_psgc TEXT;

-- Create indexes on new columns
CREATE INDEX IF NOT EXISTS idx_dim_store_citymun_psgc ON scout.dim_store(citymun_psgc);
CREATE INDEX IF NOT EXISTS idx_dim_store_province_psgc ON scout.dim_store(province_psgc);

-- Function to update store PSGC codes based on names
CREATE OR REPLACE FUNCTION scout.update_store_psgc()
RETURNS VOID 
LANGUAGE plpgsql 
AS $$
BEGIN
  -- Update region normalization
  UPDATE scout.dim_store s
  SET region = scout.norm_region(s.region)
  WHERE s.region IS DISTINCT FROM scout.norm_region(s.region);
  
  -- Attempt to match city/municipality PSGC
  UPDATE scout.dim_store s
  SET citymun_psgc = scout.norm_citymun(s.city, s.province)
  WHERE s.citymun_psgc IS NULL 
    AND s.city IS NOT NULL;
  
  -- Update province PSGC from matched cities
  UPDATE scout.dim_store s
  SET province_psgc = c.province_psgc
  FROM scout.dim_geo_citymun c
  WHERE s.citymun_psgc = c.citymun_psgc
    AND s.province_psgc IS NULL;
END $$;

COMMIT;