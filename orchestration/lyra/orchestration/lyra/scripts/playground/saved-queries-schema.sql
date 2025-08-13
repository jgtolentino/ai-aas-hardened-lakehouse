
-- Schema for saved queries functionality
CREATE TABLE IF NOT EXISTS saved_queries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  sql TEXT NOT NULL,
  description TEXT DEFAULT '',
  tenant_id TEXT NOT NULL,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  is_public BOOLEAN DEFAULT FALSE,
  tags TEXT[] DEFAULT '{}',
  execution_count INTEGER DEFAULT 0,
  last_executed_at TIMESTAMPTZ
);

-- RLS policies
ALTER TABLE saved_queries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their tenant's saved queries" ON saved_queries
  FOR ALL USING (
    tenant_id = current_setting('request.headers')::json->>'x-tenant-id'
  );

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_saved_queries_tenant_id ON saved_queries(tenant_id);
CREATE INDEX IF NOT EXISTS idx_saved_queries_created_by ON saved_queries(created_by);
CREATE INDEX IF NOT EXISTS idx_saved_queries_updated_at ON saved_queries(updated_at DESC);

-- RPC functions for safe SQL execution
CREATE OR REPLACE FUNCTION exec_select(p_sql TEXT)
RETURNS TABLE(result JSON)
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN
  -- Validate that it's a SELECT statement
  IF NOT (p_sql ~* '^\s*SELECT') THEN
    RAISE EXCEPTION 'Only SELECT statements are allowed';
  END IF;
  
  -- Execute and return as JSON
  RETURN QUERY EXECUTE format('
    SELECT to_json(array_agg(row_to_json(t))) 
    FROM (%s) t
  ', p_sql);
END;
$$;

CREATE OR REPLACE FUNCTION exec_explain(p_sql TEXT)
RETURNS TABLE(result JSON)
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN
  -- Validate that it's an EXPLAIN statement
  IF NOT (p_sql ~* '^\s*EXPLAIN') THEN
    RAISE EXCEPTION 'Only EXPLAIN statements are allowed';
  END IF;
  
  -- Execute EXPLAIN and return as JSON
  RETURN QUERY EXECUTE format('
    SELECT to_json(array_agg(row_to_json(t))) 
    FROM (%s) t
  ', p_sql);
END;
$$;
