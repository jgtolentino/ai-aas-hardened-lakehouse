-- Scout RLS Policies
-- Implements row-level security for all Scout tables

BEGIN;

-- Enable RLS on all tables
ALTER TABLE scout.bronze_transactions_raw ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.silver_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.silver_combo_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.silver_substitutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.data_quality_issues ENABLE ROW LEVEL SECURITY;

-- Bronze layer policies (service role only)
CREATE POLICY "Bronze - Service role full access" ON scout.bronze_transactions_raw
    FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role');

-- Silver layer policies
-- Service role has full access
CREATE POLICY "Silver transactions - Service role full access" ON scout.silver_transactions
    FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role');

-- Authenticated users can read with optional tenant isolation
CREATE POLICY "Silver transactions - Authenticated read" ON scout.silver_transactions
    FOR SELECT
    USING (
        auth.role() = 'authenticated' AND (
            -- No tenant_id means all data readable
            auth.jwt() ->> 'tenant_id' IS NULL OR
            -- Tenant isolation if tenant_id is set
            (auth.jwt() ->> 'tenant_id')::text = (metadata ->> 'tenant_id')::text
        )
    );

-- Anon users cannot read silver data (negative test)
CREATE POLICY "Silver transactions - Anon blocked" ON scout.silver_transactions
    FOR SELECT
    USING (auth.role() != 'anon');

-- Combo items inherit from parent transaction
CREATE POLICY "Silver combo - Service role full access" ON scout.silver_combo_items
    FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Silver combo - Authenticated read" ON scout.silver_combo_items
    FOR SELECT
    USING (
        auth.role() = 'authenticated' AND
        EXISTS (
            SELECT 1 FROM scout.silver_transactions st
            WHERE st.id = silver_combo_items.id
            AND (
                auth.jwt() ->> 'tenant_id' IS NULL OR
                (auth.jwt() ->> 'tenant_id')::text = (st.metadata ->> 'tenant_id')::text
            )
        )
    );

-- Substitutions inherit from parent transaction
CREATE POLICY "Silver substitutions - Service role full access" ON scout.silver_substitutions
    FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Silver substitutions - Authenticated read" ON scout.silver_substitutions
    FOR SELECT
    USING (
        auth.role() = 'authenticated' AND
        EXISTS (
            SELECT 1 FROM scout.silver_transactions st
            WHERE st.id = silver_substitutions.id
            AND (
                auth.jwt() ->> 'tenant_id' IS NULL OR
                (auth.jwt() ->> 'tenant_id')::text = (st.metadata ->> 'tenant_id')::text
            )
        )
    );

-- Data quality issues - service role and quality managers
CREATE POLICY "Quality issues - Service role full access" ON scout.data_quality_issues
    FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Quality issues - Quality manager read" ON scout.data_quality_issues
    FOR SELECT
    USING (
        auth.role() = 'authenticated' AND
        auth.jwt() ->> 'user_role' IN ('quality_manager', 'admin')
    );

-- Gold/Platinum views don't need RLS (they're views)
-- But we can create security definer functions for controlled access

-- Function to get gold data with optional filtering
CREATE OR REPLACE FUNCTION scout.get_gold_txn_daily(
    p_region TEXT DEFAULT NULL,
    p_date_from DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_date_to DATE DEFAULT CURRENT_DATE,
    p_tenant_id TEXT DEFAULT NULL
)
RETURNS SETOF scout.gold_txn_daily
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = scout, public
AS $$
BEGIN
    -- Check if user is authenticated
    IF auth.role() NOT IN ('authenticated', 'service_role') THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    -- Apply tenant filter if user has tenant_id
    IF auth.jwt() ->> 'tenant_id' IS NOT NULL THEN
        p_tenant_id := auth.jwt() ->> 'tenant_id';
    END IF;
    
    RETURN QUERY
    SELECT * FROM scout.gold_txn_daily
    WHERE day BETWEEN p_date_from AND p_date_to
    AND (p_region IS NULL OR region = p_region)
    AND (p_tenant_id IS NULL OR metadata ->> 'tenant_id' = p_tenant_id);
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION scout.get_gold_txn_daily TO authenticated;

-- PostgREST exposure configuration
-- This needs to be run as superuser or via Supabase dashboard
DO $$
BEGIN
    -- Check if we can modify the authenticator role
    IF EXISTS (
        SELECT 1 FROM pg_roles 
        WHERE rolname = 'authenticator' 
        AND rolsuper = false
    ) THEN
        -- Add scout schema to PostgREST exposure
        ALTER ROLE authenticator SET pgrst.db_schemas = 'public, scout, extensions';
        
        -- Grant usage on scout schema
        GRANT USAGE ON SCHEMA scout TO authenticator;
        GRANT USAGE ON SCHEMA scout TO authenticated;
        GRANT USAGE ON SCHEMA scout TO anon;
        
        -- Grant select on specific tables to authenticated
        GRANT SELECT ON ALL TABLES IN SCHEMA scout TO authenticated;
        
        -- Revoke from anon (negative test)
        REVOKE ALL ON ALL TABLES IN SCHEMA scout FROM anon;
        
        -- Grant execute on functions
        GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA scout TO authenticated;
    ELSE
        RAISE NOTICE 'Cannot modify authenticator role. Run these commands manually:';
        RAISE NOTICE 'ALTER ROLE authenticator SET pgrst.db_schemas = ''public, scout, extensions'';';
        RAISE NOTICE 'GRANT USAGE ON SCHEMA scout TO authenticator, authenticated, anon;';
        RAISE NOTICE 'GRANT SELECT ON ALL TABLES IN SCHEMA scout TO authenticated;';
    END IF;
END
$$;

-- Create audit log for RLS violations
CREATE TABLE IF NOT EXISTS scout.rls_audit_log (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID,
    user_role TEXT,
    table_name TEXT,
    operation TEXT,
    attempted_at TIMESTAMPTZ DEFAULT NOW(),
    jwt_claims JSONB,
    error_message TEXT
);

-- Function to log RLS violations
CREATE OR REPLACE FUNCTION scout.log_rls_violation()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO scout.rls_audit_log (
        user_id,
        user_role,
        table_name,
        operation,
        jwt_claims,
        error_message
    ) VALUES (
        auth.uid(),
        auth.role(),
        TG_TABLE_NAME,
        TG_OP,
        auth.jwt(),
        'Row level security policy violation'
    );
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;