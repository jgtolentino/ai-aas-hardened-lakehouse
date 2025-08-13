-- Create execute_sql function for Edge Functions
-- This function allows Edge Functions to execute dynamic SQL queries

CREATE OR REPLACE FUNCTION public.execute_sql(query text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result json;
BEGIN
    -- Validate that query is not empty
    IF query IS NULL OR trim(query) = '' THEN
        RAISE EXCEPTION 'Query cannot be empty';
    END IF;

    -- Execute the query and return results as JSON
    EXECUTE format('SELECT array_to_json(array_agg(row_to_json(t))) FROM (%s) t', query) INTO result;
    
    -- Return empty array if no results
    RETURN COALESCE(result, '[]'::json);
    
EXCEPTION
    WHEN OTHERS THEN
        -- Return error information as JSON
        RETURN json_build_object(
            'error', SQLERRM,
            'state', SQLSTATE,
            'query', query
        );
END;
$$;