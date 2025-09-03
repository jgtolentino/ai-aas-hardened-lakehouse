-- Create SQL execution function for Scout MCP migrations
-- This function allows the MCP server to execute SQL migrations

CREATE OR REPLACE FUNCTION scout.exec_sql(sql_query text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result json;
BEGIN
    -- Log the execution
    INSERT INTO scout.events (event_type, source, payload)
    VALUES ('sql_execution', 'scout_mcp', jsonb_build_object('sql', sql_query));
    
    -- Execute the SQL
    EXECUTE sql_query;
    
    -- Return success
    RETURN json_build_object('success', true, 'message', 'SQL executed successfully');
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error
        INSERT INTO scout.events (event_type, source, payload, processed)
        VALUES ('sql_error', 'scout_mcp', jsonb_build_object(
            'sql', sql_query,
            'error', SQLERRM,
            'sqlstate', SQLSTATE
        ), true);
        
        -- Re-raise the error
        RAISE;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION scout.exec_sql(text) TO authenticated;
GRANT EXECUTE ON FUNCTION scout.exec_sql(text) TO service_role;

-- Create a safer version for querying (read-only)
CREATE OR REPLACE FUNCTION scout.query_sql(sql_query text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result json;
BEGIN
    -- Only allow SELECT statements
    IF NOT (sql_query ~* '^\s*SELECT') THEN
        RAISE EXCEPTION 'Only SELECT queries are allowed';
    END IF;
    
    -- Execute and return results as JSON
    EXECUTE 'SELECT json_agg(row_to_json(t)) FROM (' || sql_query || ') t'
    INTO result;
    
    RETURN COALESCE(result, '[]'::json);
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error
        INSERT INTO scout.events (event_type, source, payload, processed)
        VALUES ('query_error', 'scout_mcp', jsonb_build_object(
            'sql', sql_query,
            'error', SQLERRM,
            'sqlstate', SQLSTATE
        ), true);
        
        -- Re-raise the error
        RAISE;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION scout.query_sql(text) TO authenticated;
GRANT EXECUTE ON FUNCTION scout.query_sql(text) TO anon;
