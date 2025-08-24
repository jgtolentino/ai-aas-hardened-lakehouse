-- 🚨 EXECUTE THIS IMMEDIATELY IN SUPABASE SQL EDITOR 🚨
-- URL: https://app.supabase.com/project/cxzllzyxwpyptfretryc/sql/new

-- ⚠️ CRITICAL: Create Read-Only MCP Role for Production Database
-- This prevents MCP from having write access to production data

-- Step 1: Create dedicated read-only user for MCP
CREATE USER mcp_reader WITH PASSWORD 'MCP_SECURE_2024_ReadOnly_Token';

-- Step 2: Grant minimal required privileges
GRANT CONNECT ON DATABASE postgres TO mcp_reader;
GRANT USAGE ON SCHEMA public TO mcp_reader;
GRANT USAGE ON SCHEMA scout TO mcp_reader;

-- Step 3: Grant SELECT ONLY (no write operations)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO mcp_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA scout TO mcp_reader;

-- Step 4: BLOCK all dangerous operations
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM mcp_reader;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA scout FROM mcp_reader;
REVOKE CREATE ON SCHEMA public FROM mcp_reader;
REVOKE CREATE ON SCHEMA scout FROM mcp_reader;

-- Step 5: Block access to sensitive Supabase schemas
REVOKE ALL ON SCHEMA auth FROM mcp_reader;
REVOKE ALL ON SCHEMA storage FROM mcp_reader;
REVOKE ALL ON SCHEMA supabase_migrations FROM mcp_reader;

-- Step 6: Add security limits
ALTER USER mcp_reader CONNECTION LIMIT 3;
ALTER USER mcp_reader SET statement_timeout = '30s';

-- ✅ VERIFICATION: Run this to confirm security
SELECT 
    schemaname,
    tablename, 
    privilege_type
FROM information_schema.table_privileges 
WHERE grantee = 'mcp_reader'
ORDER BY schemaname, tablename;

-- 🔐 RESULT: mcp_reader should ONLY have SELECT privileges