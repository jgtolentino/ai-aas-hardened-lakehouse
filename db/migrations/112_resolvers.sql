-- Brand and SRP Resolver Functions
-- Combines brand detection with SRP lookup

-- Main resolver function
CREATE OR REPLACE FUNCTION scout.resolve_brand_and_srp(
    p_brand_hint TEXT,
    p_product_hint TEXT,
    p_gtin TEXT DEFAULT NULL
)
RETURNS TABLE (
    brand_id INTEGER,
    brand_name VARCHAR,
    product_id INTEGER,
    product_name VARCHAR,
    srp DECIMAL,
    currency CHAR(3),
    srp_source VARCHAR,
    confidence DECIMAL
) AS $$
DECLARE
    v_brand_match RECORD;
    v_product_match RECORD;
    v_srp_match RECORD;
BEGIN
    -- Try to match brand first
    SELECT bc.id, bc.brand_name INTO v_brand_match
    FROM scout.brand_catalog bc
    WHERE LOWER(bc.brand_name) = LOWER(p_brand_hint)
       OR LOWER(p_brand_hint) = ANY(LOWER(bc.aliases::TEXT)::TEXT[])
    LIMIT 1;
    
    -- If no exact match, try fuzzy
    IF v_brand_match IS NULL THEN
        SELECT bc.id, bc.brand_name INTO v_brand_match
        FROM scout.brand_catalog bc
        WHERE LOWER(bc.brand_name) LIKE '%' || LOWER(p_brand_hint) || '%'
           OR LOWER(p_brand_hint) LIKE '%' || LOWER(bc.brand_name) || '%'
        ORDER BY LENGTH(bc.brand_name)
        LIMIT 1;
    END IF;
    
    -- Try to find product
    IF p_gtin IS NOT NULL THEN
        -- GTIN lookup
        SELECT pc.id, pc.product_name INTO v_product_match
        FROM scout.product_catalog pc
        WHERE pc.gtin = p_gtin
        LIMIT 1;
    END IF;
    
    -- If no GTIN match, try by name
    IF v_product_match IS NULL AND p_product_hint IS NOT NULL THEN
        SELECT pc.id, pc.product_name INTO v_product_match
        FROM scout.product_catalog pc
        WHERE LOWER(pc.product_name) LIKE '%' || LOWER(p_product_hint) || '%'
           OR LOWER(p_product_hint) LIKE '%' || LOWER(pc.product_name) || '%'
        ORDER BY 
            CASE WHEN v_brand_match.id IS NOT NULL AND pc.brand_id = v_brand_match.id THEN 0 ELSE 1 END,
            LENGTH(pc.product_name)
        LIMIT 1;
    END IF;
    
    -- Look up SRP
    IF p_gtin IS NOT NULL THEN
        SELECT srp.srp, srp.currency, srp.source, srp.confidence INTO v_srp_match
        FROM scout.v_srp_latest srp
        WHERE srp.gtin = p_gtin
        LIMIT 1;
    END IF;
    
    -- If no GTIN SRP, try brand+product
    IF v_srp_match IS NULL AND v_brand_match IS NOT NULL THEN
        SELECT srp.srp, srp.currency, srp.source, srp.confidence INTO v_srp_match
        FROM scout.v_srp_latest srp
        WHERE LOWER(srp.brand) = LOWER(v_brand_match.brand_name)
          AND (
              LOWER(srp.product) LIKE '%' || LOWER(p_product_hint) || '%'
              OR LOWER(p_product_hint) LIKE '%' || LOWER(srp.product) || '%'
          )
        ORDER BY srp.confidence DESC NULLS LAST
        LIMIT 1;
    END IF;
    
    -- Return combined result
    RETURN QUERY SELECT
        v_brand_match.id,
        v_brand_match.brand_name,
        v_product_match.id,
        v_product_match.product_name,
        v_srp_match.srp,
        v_srp_match.currency,
        v_srp_match.source,
        COALESCE(v_srp_match.confidence, 0.5);
END;
$$ LANGUAGE plpgsql;

-- Simplified SRP-only lookup
CREATE OR REPLACE FUNCTION scout.lookup_srp(
    p_gtin TEXT DEFAULT NULL,
    p_product_id INTEGER DEFAULT NULL,
    p_brand_id INTEGER DEFAULT NULL
)
RETURNS TABLE (
    srp DECIMAL,
    currency CHAR(3),
    source VARCHAR,
    effective_date DATE,
    confidence DECIMAL
) AS $$
BEGIN
    -- Direct GTIN lookup
    IF p_gtin IS NOT NULL THEN
        RETURN QUERY
        SELECT s.srp, s.currency, s.source, s.effective_date, s.confidence
        FROM scout.v_srp_latest s
        WHERE s.gtin = p_gtin
        LIMIT 1;
        
        IF FOUND THEN RETURN; END IF;
    END IF;
    
    -- Product ID lookup via catalog
    IF p_product_id IS NOT NULL THEN
        RETURN QUERY
        SELECT s.srp, s.currency, s.source, s.effective_date, s.confidence
        FROM scout.product_catalog pc
        JOIN scout.v_srp_latest s ON s.gtin = pc.gtin
        WHERE pc.id = p_product_id
        LIMIT 1;
        
        IF FOUND THEN RETURN; END IF;
    END IF;
    
    -- Brand-based fallback
    IF p_brand_id IS NOT NULL THEN
        RETURN QUERY
        SELECT 
            AVG(s.srp)::DECIMAL(10,2),
            MIN(s.currency)::CHAR(3),
            'BRAND_AVG'::VARCHAR,
            MAX(s.effective_date),
            0.3::DECIMAL
        FROM scout.brand_catalog bc
        JOIN scout.v_srp_latest s ON LOWER(s.brand) = LOWER(bc.brand_name)
        WHERE bc.id = p_brand_id
        GROUP BY s.currency
        LIMIT 1;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Grants
GRANT EXECUTE ON FUNCTION scout.resolve_brand_and_srp TO PUBLIC;
GRANT EXECUTE ON FUNCTION scout.lookup_srp TO PUBLIC;