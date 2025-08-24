-- GeoJSON Boundaries Schema (no PostGIS required)
-- Store Feature/Geometry JSON with bbox prefiltering

CREATE SCHEMA IF NOT EXISTS geo;

-- Boundary storage table
CREATE TABLE IF NOT EXISTS geo.boundaries (
    id SERIAL PRIMARY KEY,
    level VARCHAR(20) NOT NULL CHECK (level IN ('region', 'province', 'city', 'municipality', 'barangay')),
    code VARCHAR(20),
    name VARCHAR(255) NOT NULL,
    name_normalized VARCHAR(255),
    parent_code VARCHAR(20),
    
    -- GeoJSON Feature object
    feature JSONB NOT NULL,
    
    -- Extracted geometry for queries
    geometry JSONB NOT NULL,
    geometry_type VARCHAR(50),
    
    -- Bounding box for prefiltering
    bbox_min_lon DECIMAL(10,7),
    bbox_min_lat DECIMAL(10,7), 
    bbox_max_lon DECIMAL(10,7),
    bbox_max_lat DECIMAL(10,7),
    
    -- Additional properties
    properties JSONB,
    area_sqkm DECIMAL(10,2),
    population INTEGER,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_geo_boundaries_level ON geo.boundaries(level);
CREATE INDEX IF NOT EXISTS idx_geo_boundaries_code ON geo.boundaries(code);
CREATE INDEX IF NOT EXISTS idx_geo_boundaries_name ON geo.boundaries(name_normalized);
CREATE INDEX IF NOT EXISTS idx_geo_boundaries_parent ON geo.boundaries(parent_code);
CREATE INDEX IF NOT EXISTS idx_geo_boundaries_bbox ON geo.boundaries(bbox_min_lon, bbox_min_lat, bbox_max_lon, bbox_max_lat);
CREATE INDEX IF NOT EXISTS idx_geo_boundaries_feature ON geo.boundaries USING GIN(feature);
CREATE INDEX IF NOT EXISTS idx_geo_boundaries_properties ON geo.boundaries USING GIN(properties);

-- Function to find boundary candidates by point
CREATE OR REPLACE FUNCTION geo.find_candidates(
    p_lon DECIMAL,
    p_lat DECIMAL,
    p_level VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    id INTEGER,
    level VARCHAR,
    code VARCHAR,
    name VARCHAR,
    feature JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id,
        b.level,
        b.code,
        b.name,
        b.feature
    FROM geo.boundaries b
    WHERE 
        -- Bbox prefilter
        p_lon >= b.bbox_min_lon AND
        p_lon <= b.bbox_max_lon AND
        p_lat >= b.bbox_min_lat AND
        p_lat <= b.bbox_max_lat
        -- Level filter if provided
        AND (p_level IS NULL OR b.level = p_level)
    ORDER BY 
        -- Prioritize smaller areas (more specific)
        b.area_sqkm ASC NULLS LAST;
END;
$$ LANGUAGE plpgsql;

-- Function to extract bbox from GeoJSON
CREATE OR REPLACE FUNCTION geo.extract_bbox(geojson JSONB)
RETURNS TABLE (
    min_lon DECIMAL,
    min_lat DECIMAL,
    max_lon DECIMAL, 
    max_lat DECIMAL
) AS $$
DECLARE
    coords JSONB;
    coord JSONB;
    lon DECIMAL;
    lat DECIMAL;
    first_pass BOOLEAN := TRUE;
BEGIN
    -- Initialize with extreme values
    min_lon := 180;
    min_lat := 90;
    max_lon := -180;
    max_lat := -90;
    
    -- Handle different geometry types
    IF geojson->>'type' = 'Polygon' THEN
        coords := geojson->'coordinates'->0;
    ELSIF geojson->>'type' = 'MultiPolygon' THEN
        -- Just use first polygon for now
        coords := geojson->'coordinates'->0->0;
    ELSE
        RETURN;
    END IF;
    
    -- Process coordinates
    FOR coord IN SELECT * FROM jsonb_array_elements(coords)
    LOOP
        lon := (coord->>0)::DECIMAL;
        lat := (coord->>1)::DECIMAL;
        
        min_lon := LEAST(min_lon, lon);
        min_lat := LEAST(min_lat, lat);
        max_lon := GREATEST(max_lon, lon);
        max_lat := GREATEST(max_lat, lat);
    END LOOP;
    
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- Helper to normalize Philippine place names
CREATE OR REPLACE FUNCTION geo.normalize_ph_name(name TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN LOWER(TRIM(REGEXP_REPLACE(
        REGEXP_REPLACE(
            REGEXP_REPLACE(name, 
                '(city|municipality) of', '', 'gi'),
            '\s+', ' ', 'g'),
        '^\s+|\s+$', '', 'g'
    )));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Grants
GRANT USAGE ON SCHEMA geo TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA geo TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA geo TO PUBLIC;