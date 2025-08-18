-- Row Level Security (RLS) Verification for Scout Analytics Platform
-- Ensures all tables have proper security policies

-- Set strict error handling
\set ON_ERROR_STOP on

-- Create temporary table for results
CREATE TEMP TABLE rls_check_results (
    schema_name TEXT,
    table_name TEXT,
    has_rls BOOLEAN,
    policy_count INTEGER,
    policies TEXT[],
    status TEXT,
    severity TEXT
);

-- Function to check RLS status
CREATE OR REPLACE FUNCTION check_table_rls(schema_name TEXT, table_name TEXT)
RETURNS TABLE(
    has_rls BOOLEAN,
    policy_count INTEGER,
    policies TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    WITH rls_status AS (
        SELECT 
            t.relrowsecurity as has_rls,
            COALESCE(ARRAY_AGG(p.polname ORDER BY p.polname), '{}') as policies
        FROM pg_class t
        JOIN pg_namespace n ON n.oid = t.relnamespace
        LEFT JOIN pg_policy p ON p.polrelid = t.oid
        WHERE n.nspname = $1
        AND t.relname = $2
        AND t.relkind = 'r'
        GROUP BY t.relrowsecurity
    )
    SELECT 
        COALESCE(has_rls, false),
        COALESCE(array_length(policies, 1), 0),
        COALESCE(policies, '{}')
    FROM rls_status;
END;
$$ LANGUAGE plpgsql;

-- Check core Scout tables
INSERT INTO rls_check_results (schema_name, table_name, has_rls, policy_count, policies, status, severity)
SELECT 
    schema_name,
    table_name,
    (rls_check).has_rls,
    (rls_check).policy_count,
    (rls_check).policies,
    CASE 
        WHEN (rls_check).has_rls AND (rls_check).policy_count > 0 THEN 'PASS'
        WHEN NOT (rls_check).has_rls THEN 'FAIL - RLS NOT ENABLED'
        WHEN (rls_check).policy_count = 0 THEN 'FAIL - NO POLICIES'
        ELSE 'UNKNOWN'
    END as status,
    CASE 
        WHEN table_name IN ('processed_transcripts', 'chat_messages', 'employee_data') THEN 'CRITICAL'
        WHEN schema_name LIKE '%gold%' THEN 'HIGH'
        ELSE 'MEDIUM'
    END as severity
FROM (
    VALUES 
        -- Critical tables that must have RLS
        ('scout', 'processed_transcripts'),
        ('scout', 'chat_sessions'),
        ('scout', 'chat_messages'),
        ('scout_gold', 'fact_transactions'),
        ('scout_gold', 'dim_customers'),
        ('datasets', 'published_datasets'),
        ('replication', 'replication_queue'),
        ('analytics', 'user_access_logs')
) AS tables(schema_name, table_name)
CROSS JOIN LATERAL check_table_rls(schema_name, table_name) AS rls_check;

-- Check if sensitive columns are exposed without RLS
WITH sensitive_columns AS (
    SELECT 
        n.nspname as schema_name,
        c.relname as table_name,
        a.attname as column_name,
        CASE 
            WHEN a.attname LIKE '%email%' THEN 'PII - Email'
            WHEN a.attname LIKE '%phone%' THEN 'PII - Phone'
            WHEN a.attname LIKE '%address%' THEN 'PII - Address'
            WHEN a.attname LIKE '%password%' THEN 'CRITICAL - Password'
            WHEN a.attname LIKE '%token%' THEN 'CRITICAL - Token'
            WHEN a.attname LIKE '%key%' THEN 'CRITICAL - Key'
            WHEN a.attname LIKE '%ssn%' OR a.attname LIKE '%social%' THEN 'PII - SSN'
            WHEN a.attname LIKE '%credit%' THEN 'PII - Financial'
            ELSE 'Potentially Sensitive'
        END as sensitivity_type
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid
    LEFT JOIN rls_check_results r ON r.schema_name = n.nspname AND r.table_name = c.relname
    WHERE c.relkind = 'r'
    AND a.attnum > 0
    AND NOT a.attisdropped
    AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname LIKE 'scout%'
    AND (
        a.attname LIKE '%email%' OR
        a.attname LIKE '%phone%' OR
        a.attname LIKE '%address%' OR
        a.attname LIKE '%password%' OR
        a.attname LIKE '%token%' OR
        a.attname LIKE '%key%' OR
        a.attname LIKE '%ssn%' OR
        a.attname LIKE '%social%' OR
        a.attname LIKE '%credit%'
    )
    AND (r.has_rls IS NULL OR NOT r.has_rls)
)
SELECT 
    'Sensitive Column Exposure' as check_type,
    schema_name || '.' || table_name || '.' || column_name as location,
    sensitivity_type,
    'FAIL - No RLS Protection' as status,
    'HIGH' as severity
FROM sensitive_columns;

-- Check policy quality (not just existence)
WITH policy_analysis AS (
    SELECT 
        n.nspname as schema_name,
        c.relname as table_name,
        p.polname as policy_name,
        p.polcmd as command,
        p.polroles::regrole[] as roles,
        pg_get_expr(p.polqual, p.polrelid) as using_expression,
        pg_get_expr(p.polwithcheck, p.polrelid) as with_check_expression
    FROM pg_policy p
    JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname LIKE 'scout%'
)
SELECT 
    'Policy Quality Check' as check_type,
    schema_name || '.' || table_name || '::' || policy_name as location,
    CASE 
        WHEN using_expression = 'true' THEN 'FAIL - Policy allows all (using true)'
        WHEN using_expression IS NULL THEN 'FAIL - No USING clause'
        WHEN array_length(roles, 1) = 0 THEN 'FAIL - No roles specified'
        ELSE 'PASS'
    END as status,
    CASE 
        WHEN command = 'd' THEN 'DELETE'
        WHEN command = 'r' THEN 'SELECT'
        WHEN command = 'a' THEN 'INSERT'
        WHEN command = 'w' THEN 'UPDATE'
        WHEN command = '*' THEN 'ALL'
        ELSE command::text
    END as operation,
    'MEDIUM' as severity
FROM policy_analysis
WHERE using_expression = 'true' OR using_expression IS NULL OR array_length(roles, 1) = 0;

-- Summary report
SELECT 
    '=== RLS CHECK SUMMARY ===' as report_section,
    COUNT(*) FILTER (WHERE status LIKE 'PASS%') as passed_checks,
    COUNT(*) FILTER (WHERE status LIKE 'FAIL%') as failed_checks,
    COUNT(*) FILTER (WHERE severity = 'CRITICAL') as critical_issues,
    COUNT(*) FILTER (WHERE severity = 'HIGH') as high_issues,
    COUNT(*) FILTER (WHERE severity = 'MEDIUM') as medium_issues
FROM rls_check_results;

-- Detailed failures
SELECT 
    '=== FAILED RLS CHECKS ===' as report_section,
    schema_name || '.' || table_name as table_full_name,
    status,
    severity,
    CASE 
        WHEN array_length(policies, 1) > 0 
        THEN 'Policies: ' || array_to_string(policies, ', ')
        ELSE 'No policies defined'
    END as policy_info
FROM rls_check_results
WHERE status LIKE 'FAIL%'
ORDER BY 
    CASE severity 
        WHEN 'CRITICAL' THEN 1
        WHEN 'HIGH' THEN 2
        WHEN 'MEDIUM' THEN 3
        ELSE 4
    END,
    schema_name,
    table_name;

-- Overall gate status
WITH gate_status AS (
    SELECT 
        COUNT(*) FILTER (WHERE status LIKE 'FAIL%' AND severity = 'CRITICAL') as critical_failures,
        COUNT(*) FILTER (WHERE status LIKE 'FAIL%') as total_failures
    FROM rls_check_results
)
SELECT 
    '=== RLS GATE STATUS ===' as report_section,
    CASE 
        WHEN critical_failures > 0 THEN 'FAIL - Critical security issues found'
        WHEN total_failures > 0 THEN 'FAIL - Security issues found'
        ELSE 'PASS - All RLS checks passed'
    END as gate_status,
    critical_failures || ' critical, ' || total_failures || ' total failures' as details
FROM gate_status;

-- Clean up
DROP FUNCTION check_table_rls(TEXT, TEXT);