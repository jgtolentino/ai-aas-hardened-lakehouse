-- ============================================================
-- SECURITY: Create Read-Only MCP Role
-- Creates a restricted database role for MCP connections
-- Run this in Supabase SQL Editor as an admin
-- ============================================================

-- 1) Create a dedicated readonly role
CREATE ROLE mcp_reader LOGIN PASSWORD 'SET_STRONG_PASSWORD_HERE_REPLACE_THIS';

-- 2) Block writes by default
REVOKE CREATE ON SCHEMA public FROM mcp_reader;
REVOKE ALL ON DATABASE postgres FROM mcp_reader;

-- 3) Grant connect + usage + select only
GRANT CONNECT ON DATABASE postgres TO mcp_reader;
GRANT USAGE ON SCHEMA public, scout, bronze, silver, gold TO mcp_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA public, scout, bronze, silver, gold TO mcp_reader;

-- 4) Grant select on future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO mcp_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA scout  GRANT SELECT ON TABLES TO mcp_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA bronze GRANT SELECT ON TABLES TO mcp_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA silver GRANT SELECT ON TABLES TO mcp_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA gold   GRANT SELECT ON TABLES TO mcp_reader;

-- 5) Allow safe read-only functions only
GRANT EXECUTE ON FUNCTION scout.check_data_quality() TO mcp_reader;
GRANT EXECUTE ON FUNCTION scout.run_math_invariant_checks() TO mcp_reader;

-- 6) Ensure RLS remains enforced
-- (Tables with RLS will still enforce row-level restrictions)

-- 7) Create monitoring query to verify permissions
CREATE OR REPLACE FUNCTION public.verify_mcp_reader_permissions()
RETURNS TABLE (
    object_type TEXT,
    object_name TEXT,
    privilege TEXT,
    granted BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'table'::TEXT as object_type,
        schemaname||'.'||tablename as object_name,
        'SELECT'::TEXT as privilege,
        has_table_privilege('mcp_reader', schemaname||'.'||tablename, 'SELECT') as granted
    FROM pg_tables 
    WHERE schemaname IN ('scout', 'bronze', 'silver', 'gold')
    
    UNION ALL
    
    SELECT 
        'table'::TEXT as object_type,
        schemaname||'.'||tablename as object_name,
        'INSERT'::TEXT as privilege,
        has_table_privilege('mcp_reader', schemaname||'.'||tablename, 'INSERT') as granted
    FROM pg_tables 
    WHERE schemaname IN ('scout', 'bronze', 'silver', 'gold')
    ORDER BY object_name, privilege;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Test the role permissions
SELECT * FROM public.verify_mcp_reader_permissions() 
WHERE granted = true AND privilege != 'SELECT';