-- ChatGPT Database Bridge Support Functions
-- Provides secure database access for ChatGPT via REST API

-- Function to get all enterprise schemas
CREATE OR REPLACE FUNCTION get_enterprise_schemas()
RETURNS TABLE(schema_name TEXT) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT ns.nspname::TEXT
    FROM pg_namespace ns
    WHERE ns.nspname IN (
        'hr_admin',
        'financial_ops', 
        'operations',
        'corporate',
        'creative_insights',
        'scout_dash',
        'public'
    )
    ORDER BY ns.nspname;
END;
$$;

-- Function to get tables in a schema
CREATE OR REPLACE FUNCTION get_schema_tables(schema_name TEXT)
RETURNS TABLE(
    table_name TEXT,
    table_type TEXT,
    row_count BIGINT,
    table_comment TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Validate schema name
    IF schema_name NOT IN ('hr_admin', 'financial_ops', 'operations', 'corporate', 'creative_insights', 'scout_dash', 'public') THEN
        RAISE EXCEPTION 'Invalid schema name: %', schema_name;
    END IF;

    RETURN QUERY
    SELECT 
        t.table_name::TEXT,
        t.table_type::TEXT,
        COALESCE(s.n_tup_ins - s.n_tup_del, 0) as row_count,
        obj_description(c.oid)::TEXT as table_comment
    FROM information_schema.tables t
    LEFT JOIN pg_class c ON c.relname = t.table_name
    LEFT JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = t.table_schema
    LEFT JOIN pg_stat_user_tables s ON s.relname = t.table_name AND s.schemaname = t.table_schema
    WHERE t.table_schema = schema_name
      AND t.table_type IN ('BASE TABLE', 'VIEW')
    ORDER BY t.table_name;
END;
$$;

-- Function to get table columns
CREATE OR REPLACE FUNCTION get_table_columns(schema_name TEXT, table_name TEXT)
RETURNS TABLE(
    column_name TEXT,
    data_type TEXT,
    is_nullable TEXT,
    column_default TEXT,
    description TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Validate schema name
    IF schema_name NOT IN ('hr_admin', 'financial_ops', 'operations', 'corporate', 'creative_insights', 'scout_dash', 'public') THEN
        RAISE EXCEPTION 'Invalid schema name: %', schema_name;
    END IF;

    RETURN QUERY
    SELECT 
        c.column_name::TEXT,
        c.data_type::TEXT,
        c.is_nullable::TEXT,
        c.column_default::TEXT,
        col_description(pgc.oid, c.ordinal_position)::TEXT as description
    FROM information_schema.columns c
    LEFT JOIN pg_class pgc ON pgc.relname = c.table_name
    LEFT JOIN pg_namespace pgn ON pgn.oid = pgc.relnamespace AND pgn.nspname = c.table_schema
    WHERE c.table_schema = schema_name
      AND c.table_name = table_name
    ORDER BY c.ordinal_position;
END;
$$;

-- Function to get all enterprise tables with metadata
CREATE OR REPLACE FUNCTION get_all_enterprise_tables()
RETURNS TABLE(
    schema_name TEXT,
    table_name TEXT,
    table_type TEXT,
    row_count BIGINT,
    size_bytes BIGINT,
    last_analyzed TIMESTAMP,
    description TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.table_schema::TEXT,
        t.table_name::TEXT,
        t.table_type::TEXT,
        COALESCE(s.n_tup_ins - s.n_tup_del, 0) as row_count,
        COALESCE(pg_total_relation_size(c.oid), 0) as size_bytes,
        s.last_analyze as last_analyzed,
        obj_description(c.oid)::TEXT as description
    FROM information_schema.tables t
    LEFT JOIN pg_class c ON c.relname = t.table_name
    LEFT JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = t.table_schema
    LEFT JOIN pg_stat_user_tables s ON s.relname = t.table_name AND s.schemaname = t.table_schema
    WHERE t.table_schema IN ('hr_admin', 'financial_ops', 'operations', 'corporate', 'creative_insights', 'scout_dash', 'public')
      AND t.table_type IN ('BASE TABLE', 'VIEW')
    ORDER BY t.table_schema, t.table_name;
END;
$$;

-- Function to get table statistics
CREATE OR REPLACE FUNCTION get_table_stats(schema_name TEXT, table_name TEXT)
RETURNS TABLE(
    row_count BIGINT,
    size_bytes BIGINT,
    primary_keys TEXT[],
    foreign_keys JSONB,
    indexes JSONB
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    table_oid OID;
BEGIN
    -- Validate schema name
    IF schema_name NOT IN ('hr_admin', 'financial_ops', 'operations', 'corporate', 'creative_insights', 'scout_dash', 'public') THEN
        RAISE EXCEPTION 'Invalid schema name: %', schema_name;
    END IF;

    -- Get table OID
    SELECT c.oid INTO table_oid
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = table_name AND n.nspname = schema_name;

    IF table_oid IS NULL THEN
        RAISE EXCEPTION 'Table %.% not found', schema_name, table_name;
    END IF;

    RETURN QUERY
    SELECT 
        COALESCE(s.n_tup_ins - s.n_tup_del, 0) as row_count,
        COALESCE(pg_total_relation_size(table_oid), 0) as size_bytes,
        ARRAY(
            SELECT a.attname
            FROM pg_index i
            JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
            WHERE i.indrelid = table_oid AND i.indisprimary
        ) as primary_keys,
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'column', a.attname,
                    'referenced_table', referenced_table.relname,
                    'referenced_column', referenced_attr.attname,
                    'referenced_schema', referenced_ns.nspname
                )
            ) FILTER (WHERE con.contype = 'f'),
            '[]'::jsonb
        ) as foreign_keys,
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'name', idx.relname,
                    'unique', i.indisunique,
                    'columns', array_agg(attr.attname ORDER BY array_position(i.indkey, attr.attnum))
                )
            ) FILTER (WHERE i.indisprimary = false),
            '[]'::jsonb
        ) as indexes
    FROM pg_stat_user_tables s
    LEFT JOIN pg_constraint con ON con.conrelid = table_oid
    LEFT JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = ANY(con.conkey)
    LEFT JOIN pg_class referenced_table ON referenced_table.oid = con.confrelid
    LEFT JOIN pg_attribute referenced_attr ON referenced_attr.attrelid = con.confrelid AND referenced_attr.attnum = ANY(con.confkey)
    LEFT JOIN pg_namespace referenced_ns ON referenced_ns.oid = referenced_table.relnamespace
    LEFT JOIN pg_index i ON i.indrelid = table_oid
    LEFT JOIN pg_class idx ON idx.oid = i.indexrelid
    LEFT JOIN pg_attribute attr ON attr.attrelid = i.indrelid AND attr.attnum = ANY(i.indkey)
    WHERE s.relname = table_name AND s.schemaname = schema_name
    GROUP BY s.n_tup_ins, s.n_tup_del;
END;
$$;

-- Function to execute safe queries (SELECT only)
CREATE OR REPLACE FUNCTION execute_safe_query(query_text TEXT)
RETURNS TABLE(result JSONB) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    cleaned_query TEXT;
BEGIN
    -- Clean and validate query
    cleaned_query := TRIM(UPPER(query_text));
    
    -- Only allow SELECT statements
    IF NOT cleaned_query LIKE 'SELECT%' THEN
        RAISE EXCEPTION 'Only SELECT queries are allowed in safe mode';
    END IF;

    -- Block dangerous keywords
    IF cleaned_query ~ '(DROP|DELETE|INSERT|UPDATE|ALTER|TRUNCATE|CREATE)' THEN
        RAISE EXCEPTION 'Dangerous SQL keywords not allowed in safe mode';
    END IF;

    -- Execute query and return as JSONB
    RETURN QUERY
    EXECUTE format('SELECT to_jsonb(t.*) FROM (%s) t', query_text);
END;
$$;

-- Function to execute enterprise queries with validation
CREATE OR REPLACE FUNCTION execute_enterprise_query(
    query_text TEXT,
    query_params JSONB DEFAULT '[]'::jsonb,
    target_schema TEXT DEFAULT NULL
)
RETURNS TABLE(result JSONB) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    cleaned_query TEXT;
    param_count INTEGER;
BEGIN
    -- Clean query
    cleaned_query := TRIM(query_text);
    
    -- Validate target schema if provided
    IF target_schema IS NOT NULL AND target_schema NOT IN ('hr_admin', 'financial_ops', 'operations', 'corporate', 'creative_insights', 'scout_dash', 'public') THEN
        RAISE EXCEPTION 'Invalid target schema: %', target_schema;
    END IF;

    -- Basic SQL injection protection
    IF cleaned_query ~* '(--|\\/\\*|\\*\\/|;.*DROP|;.*DELETE|;.*ALTER)' THEN
        RAISE EXCEPTION 'Potentially dangerous SQL detected';
    END IF;

    -- Set search path if schema specified
    IF target_schema IS NOT NULL THEN
        EXECUTE format('SET search_path TO %I, public', target_schema);
    END IF;

    -- Execute query with parameters
    IF jsonb_array_length(query_params) > 0 THEN
        -- Handle parameterized queries (simplified version)
        RETURN QUERY
        EXECUTE cleaned_query USING query_params;
    ELSE
        -- Execute simple query
        RETURN QUERY
        EXECUTE format('SELECT to_jsonb(t.*) FROM (%s) t', cleaned_query);
    END IF;

    -- Reset search path
    RESET search_path;
END;
$$;

-- Function to get enterprise overview
CREATE OR REPLACE FUNCTION get_enterprise_overview()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    overview JSONB;
BEGIN
    SELECT jsonb_build_object(
        'total_tables', (
            SELECT COUNT(*)
            FROM information_schema.tables
            WHERE table_schema IN ('hr_admin', 'financial_ops', 'operations', 'corporate', 'creative_insights', 'scout_dash')
        ),
        'schemas', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'name', schema_name,
                    'table_count', table_count
                )
            )
            FROM (
                SELECT 
                    table_schema as schema_name,
                    COUNT(*) as table_count
                FROM information_schema.tables
                WHERE table_schema IN ('hr_admin', 'financial_ops', 'operations', 'corporate', 'creative_insights', 'scout_dash')
                GROUP BY table_schema
                ORDER BY table_schema
            ) schema_stats
        ),
        'last_updated', NOW()
    ) INTO overview;

    RETURN overview;
END;
$$;

-- Function to get enterprise KPIs
CREATE OR REPLACE FUNCTION get_enterprise_kpis()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    kpis JSONB;
BEGIN
    SELECT jsonb_build_object(
        'employee_count', COALESCE((
            SELECT COUNT(*) FROM hr_admin.employees WHERE status = 'active'
        ), 0),
        'active_projects', COALESCE((
            SELECT COUNT(*) FROM operations.projects WHERE status IN ('active', 'in_progress')
        ), 0),
        'total_budget', COALESCE((
            SELECT SUM(budget_amount) FROM financial_ops.budgets WHERE fiscal_year = EXTRACT(YEAR FROM NOW())
        ), 0),
        'active_campaigns', COALESCE((
            SELECT COUNT(*) FROM creative_insights.campaigns WHERE campaign_status = 'active'
        ), 0),
        'compliance_score', COALESCE((
            SELECT AVG(CASE WHEN compliance_status = 'compliant' THEN 100 ELSE 0 END)
            FROM corporate.compliance_records
            WHERE created_at >= NOW() - INTERVAL '30 days'
        ), 0),
        'last_calculated', NOW()
    ) INTO kpis;

    RETURN kpis;
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_enterprise_schemas() TO authenticated;
GRANT EXECUTE ON FUNCTION get_schema_tables(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_table_columns(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_enterprise_tables() TO authenticated;
GRANT EXECUTE ON FUNCTION get_table_stats(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION execute_safe_query(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION execute_enterprise_query(TEXT, JSONB, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_enterprise_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION get_enterprise_kpis() TO authenticated;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_tables_schema_name ON information_schema.tables(table_schema);
CREATE INDEX IF NOT EXISTS idx_columns_table_schema_name ON information_schema.columns(table_schema, table_name);

-- Add comments
COMMENT ON FUNCTION get_enterprise_schemas() IS 'Returns list of available enterprise schemas';
COMMENT ON FUNCTION get_schema_tables(TEXT) IS 'Returns tables in specified schema with metadata';
COMMENT ON FUNCTION get_table_columns(TEXT, TEXT) IS 'Returns column information for specified table';
COMMENT ON FUNCTION get_all_enterprise_tables() IS 'Returns all enterprise tables with statistics';
COMMENT ON FUNCTION get_table_stats(TEXT, TEXT) IS 'Returns detailed statistics for specified table';
COMMENT ON FUNCTION execute_safe_query(TEXT) IS 'Executes SELECT-only queries safely';
COMMENT ON FUNCTION execute_enterprise_query(TEXT, JSONB, TEXT) IS 'Executes validated queries with parameters';
COMMENT ON FUNCTION get_enterprise_overview() IS 'Returns enterprise-wide overview statistics';
COMMENT ON FUNCTION get_enterprise_kpis() IS 'Returns key performance indicators across all domains';