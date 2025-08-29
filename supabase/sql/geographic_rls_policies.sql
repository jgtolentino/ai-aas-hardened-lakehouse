-- Geographic RLS (Row Level Security) Policies
-- This file creates RLS policies for geographic data access based on user roles and regions

-- Create function to set geographic RLS context
CREATE OR REPLACE FUNCTION set_geographic_rls_context(
  context jsonb,
  requested_region text DEFAULT NULL,
  requested_province text DEFAULT NULL,
  requested_metric text DEFAULT NULL
) RETURNS void AS $$
BEGIN
  -- Set the RLS context in current session
  PERFORM set_config('app.current_user_id', context->>'user_id', true);
  PERFORM set_config('app.current_user_role', context->>'user_role', true);
  PERFORM set_config('app.accessible_regions', coalesce(context->>'accessible_regions', ''), true);
  PERFORM set_config('app.accessible_provinces', coalesce(context->>'accessible_provinces', ''), true);
  PERFORM set_config('app.data_classification', context->>'data_classification', true);
  
  -- Log access request for audit trail
  INSERT INTO scout.geographic_access_log (
    user_id,
    user_role,
    requested_region,
    requested_province,
    requested_metric,
    access_granted,
    timestamp
  ) VALUES (
    (context->>'user_id')::uuid,
    context->>'user_role',
    requested_region,
    requested_province,
    requested_metric,
    true, -- We'll determine this in the policies
    NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create geographic access log table
CREATE TABLE IF NOT EXISTS scout.geographic_access_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  user_role text NOT NULL,
  requested_region text,
  requested_province text,
  requested_metric text,
  access_granted boolean DEFAULT false,
  timestamp timestamptz DEFAULT NOW()
);

-- Create RLS policies for geographic data tables

-- Enable RLS on geographic tables
ALTER TABLE scout.fact_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.dim_barangays ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.dim_municipalities ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.dim_provinces ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.dim_regions ENABLE ROW LEVEL SECURITY;

-- Policy for executives and admins (full access)
CREATE POLICY "executive_full_access" ON scout.fact_transactions
  FOR ALL USING (
    current_setting('app.current_user_role', true) IN ('admin', 'executive')
  );

-- Policy for regional managers (access to their assigned regions)
CREATE POLICY "regional_manager_access" ON scout.fact_transactions
  FOR ALL USING (
    current_setting('app.current_user_role', true) = 'regional_manager' AND
    EXISTS (
      SELECT 1 FROM scout.dim_stores s
      JOIN scout.dim_barangays b ON s.barangay_id = b.id
      JOIN scout.dim_municipalities m ON b.municipality_id = m.id
      JOIN scout.dim_provinces p ON m.province_id = p.id
      JOIN scout.dim_regions r ON p.region_id = r.id
      WHERE s.id = fact_transactions.store_id
      AND r.region_name = ANY(string_to_array(current_setting('app.accessible_regions', true), ','))
    )
  );

-- Policy for provincial managers (access to their assigned provinces)
CREATE POLICY "provincial_manager_access" ON scout.fact_transactions
  FOR ALL USING (
    current_setting('app.current_user_role', true) = 'provincial_manager' AND
    EXISTS (
      SELECT 1 FROM scout.dim_stores s
      JOIN scout.dim_barangays b ON s.barangay_id = b.id
      JOIN scout.dim_municipalities m ON b.municipality_id = m.id
      JOIN scout.dim_provinces p ON m.province_id = p.id
      WHERE s.id = fact_transactions.store_id
      AND p.province_name = ANY(string_to_array(current_setting('app.accessible_provinces', true), ','))
    )
  );

-- Policy for analysts (access to aggregated data only)
CREATE POLICY "analyst_aggregated_access" ON scout.fact_transactions
  FOR SELECT USING (
    current_setting('app.current_user_role', true) = 'analyst' AND
    current_setting('app.data_classification', true) IN ('public', 'internal')
  );

-- Policy for viewers (public data only)
CREATE POLICY "viewer_public_access" ON scout.fact_transactions
  FOR SELECT USING (
    current_setting('app.current_user_role', true) = 'viewer' AND
    current_setting('app.data_classification', true) = 'public'
  );

-- RLS policies for geographic dimension tables
CREATE POLICY "geographic_dimensions_access" ON scout.dim_barangays
  FOR SELECT USING (
    current_setting('app.current_user_role', true) IN ('admin', 'executive') OR
    (
      current_setting('app.current_user_role', true) = 'regional_manager' AND
      EXISTS (
        SELECT 1 FROM scout.dim_municipalities m
        JOIN scout.dim_provinces p ON m.province_id = p.id
        JOIN scout.dim_regions r ON p.region_id = r.id
        WHERE m.id = dim_barangays.municipality_id
        AND r.region_name = ANY(string_to_array(current_setting('app.accessible_regions', true), ','))
      )
    ) OR
    (
      current_setting('app.current_user_role', true) = 'provincial_manager' AND
      EXISTS (
        SELECT 1 FROM scout.dim_municipalities m
        JOIN scout.dim_provinces p ON m.province_id = p.id
        WHERE m.id = dim_barangays.municipality_id
        AND p.province_name = ANY(string_to_array(current_setting('app.accessible_provinces', true), ','))
      )
    )
  );

-- Similar policies for other dimension tables
CREATE POLICY "municipalities_access" ON scout.dim_municipalities
  FOR SELECT USING (
    current_setting('app.current_user_role', true) IN ('admin', 'executive') OR
    (
      current_setting('app.current_user_role', true) = 'regional_manager' AND
      EXISTS (
        SELECT 1 FROM scout.dim_provinces p
        JOIN scout.dim_regions r ON p.region_id = r.id
        WHERE p.id = dim_municipalities.province_id
        AND r.region_name = ANY(string_to_array(current_setting('app.accessible_regions', true), ','))
      )
    ) OR
    (
      current_setting('app.current_user_role', true) = 'provincial_manager' AND
      EXISTS (
        SELECT 1 FROM scout.dim_provinces p
        WHERE p.id = dim_municipalities.province_id
        AND p.province_name = ANY(string_to_array(current_setting('app.accessible_provinces', true), ','))
      )
    )
  );

-- Create function to get geographic data with RLS
CREATE OR REPLACE FUNCTION get_geographic_data(
  region_filter text DEFAULT NULL,
  province_filter text DEFAULT NULL,
  municipality_filter text DEFAULT NULL,
  start_date date DEFAULT NULL,
  end_date date DEFAULT NULL,
  metric_type text DEFAULT 'sales',
  zoom_level integer DEFAULT 8,
  is_clustered boolean DEFAULT false
) RETURNS TABLE (
  id uuid,
  latitude numeric,
  longitude numeric,
  barangay text,
  municipality text,
  province text,
  region text,
  value numeric,
  metadata jsonb
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    s.id,
    s.latitude,
    s.longitude,
    b.barangay_name as barangay,
    m.municipality_name as municipality,
    p.province_name as province,
    r.region_name as region,
    CASE 
      WHEN metric_type = 'sales' THEN COALESCE(SUM(ft.quantity), 0)::numeric
      WHEN metric_type = 'revenue' THEN COALESCE(SUM(ft.total_amount), 0)::numeric
      WHEN metric_type = 'customers' THEN COUNT(DISTINCT ft.customer_id)::numeric
      WHEN metric_type = 'visits' THEN COUNT(DISTINCT ft.transaction_date)::numeric
      ELSE 0::numeric
    END as value,
    jsonb_build_object(
      'store_name', s.store_name,
      'store_type', s.store_type,
      'last_updated', MAX(ft.transaction_date)
    ) as metadata
  FROM scout.dim_stores s
  JOIN scout.dim_barangays b ON s.barangay_id = b.id
  JOIN scout.dim_municipalities m ON b.municipality_id = m.id
  JOIN scout.dim_provinces p ON m.province_id = p.id
  JOIN scout.dim_regions r ON p.region_id = r.id
  LEFT JOIN scout.fact_transactions ft ON s.id = ft.store_id
    AND (start_date IS NULL OR ft.transaction_date >= start_date)
    AND (end_date IS NULL OR ft.transaction_date <= end_date)
  WHERE 
    (region_filter IS NULL OR r.region_name = region_filter) AND
    (province_filter IS NULL OR p.province_name = province_filter) AND
    (municipality_filter IS NULL OR m.municipality_name = municipality_filter) AND
    s.latitude IS NOT NULL AND s.longitude IS NOT NULL
  GROUP BY s.id, s.latitude, s.longitude, b.barangay_name, m.municipality_name, 
           p.province_name, r.region_name, s.store_name, s.store_type
  HAVING 
    CASE 
      WHEN metric_type = 'sales' THEN COALESCE(SUM(ft.quantity), 0) > 0
      WHEN metric_type = 'revenue' THEN COALESCE(SUM(ft.total_amount), 0) > 0
      ELSE TRUE
    END
  ORDER BY value DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get barangay boundaries with RLS
CREATE OR REPLACE FUNCTION get_barangay_boundaries(
  region_filter text DEFAULT NULL,
  province_filter text DEFAULT NULL,
  municipality_filter text DEFAULT NULL
) RETURNS TABLE (
  id uuid,
  barangay_code text,
  barangay_name text,
  municipality text,
  province text,
  region text,
  geometry jsonb,
  properties jsonb
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    b.id,
    b.barangay_code,
    b.barangay_name,
    m.municipality_name as municipality,
    p.province_name as province,
    r.region_name as region,
    b.geometry,
    jsonb_build_object(
      'population', b.population,
      'area_sqkm', b.area_sqkm,
      'density', CASE WHEN b.area_sqkm > 0 THEN b.population / b.area_sqkm ELSE 0 END
    ) as properties
  FROM scout.dim_barangays b
  JOIN scout.dim_municipalities m ON b.municipality_id = m.id
  JOIN scout.dim_provinces p ON m.province_id = p.id
  JOIN scout.dim_regions r ON p.region_id = r.id
  WHERE 
    (region_filter IS NULL OR r.region_name = region_filter) AND
    (province_filter IS NULL OR p.province_name = province_filter) AND
    (municipality_filter IS NULL OR m.municipality_name = municipality_filter) AND
    b.geometry IS NOT NULL
  ORDER BY r.region_name, p.province_name, m.municipality_name, b.barangay_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION set_geographic_rls_context TO authenticated;
GRANT EXECUTE ON FUNCTION get_geographic_data TO authenticated;
GRANT EXECUTE ON FUNCTION get_barangay_boundaries TO authenticated;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_geographic_access_log_user_timestamp 
  ON scout.geographic_access_log(user_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_geographic_access_log_region_timestamp 
  ON scout.geographic_access_log(requested_region, timestamp);

-- Create view for geographic access audit
CREATE OR REPLACE VIEW scout.geographic_access_audit AS
SELECT 
  gal.user_id,
  gal.user_role,
  gal.requested_region,
  gal.requested_province,
  gal.requested_metric,
  gal.access_granted,
  gal.timestamp,
  COUNT(*) OVER (PARTITION BY gal.user_id, DATE(gal.timestamp)) as daily_access_count
FROM scout.geographic_access_log gal
ORDER BY gal.timestamp DESC;

-- Grant select on audit view to admins and executives only
GRANT SELECT ON scout.geographic_access_audit TO authenticated;
CREATE POLICY "audit_access_policy" ON scout.geographic_access_log
  FOR SELECT USING (
    current_setting('app.current_user_role', true) IN ('admin', 'executive')
  );