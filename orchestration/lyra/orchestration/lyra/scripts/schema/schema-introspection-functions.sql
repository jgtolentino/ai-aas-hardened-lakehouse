
-- Function to get table information with row counts and sizes
CREATE OR REPLACE FUNCTION get_schema_tables()
RETURNS TABLE (
  schema_name TEXT,
  table_name TEXT,
  table_type TEXT,
  row_count BIGINT,
  size_mb NUMERIC,
  table_comment TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE SQL
SECURITY INVOKER
AS $$
  SELECT 
    t.table_schema::TEXT,
    t.table_name::TEXT,
    t.table_type::TEXT,
    COALESCE(s.n_tup_ins + s.n_tup_upd - s.n_tup_del, 0) as row_count,
    ROUND(COALESCE(pg_total_relation_size(c.oid), 0) / 1024.0 / 1024.0, 2) as size_mb,
    obj_description(c.oid, 'pg_class')::TEXT as table_comment,
    NOW() as created_at
  FROM information_schema.tables t
  LEFT JOIN pg_class c ON c.relname = t.table_name
  LEFT JOIN pg_stat_user_tables s ON s.relname = t.table_name AND s.schemaname = t.table_schema
  WHERE t.table_schema NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
    AND t.table_type IN ('BASE TABLE', 'VIEW')
  ORDER BY t.table_schema, t.table_name;
$$;

-- Function to get column information
CREATE OR REPLACE FUNCTION get_schema_columns()
RETURNS TABLE (
  schema_name TEXT,
  table_name TEXT,
  column_name TEXT,
  data_type TEXT,
  is_nullable TEXT,
  column_default TEXT,
  is_primary_key BOOLEAN,
  is_foreign_key BOOLEAN
)
LANGUAGE SQL
SECURITY INVOKER
AS $$
  SELECT 
    c.table_schema::TEXT,
    c.table_name::TEXT,
    c.column_name::TEXT,
    c.data_type::TEXT,
    c.is_nullable::TEXT,
    c.column_default::TEXT,
    COALESCE(pk.is_primary, FALSE) as is_primary_key,
    COALESCE(fk.is_foreign, FALSE) as is_foreign_key
  FROM information_schema.columns c
  LEFT JOIN (
    SELECT 
      kcu.table_schema,
      kcu.table_name,
      kcu.column_name,
      TRUE as is_primary
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
    WHERE tc.constraint_type = 'PRIMARY KEY'
  ) pk ON c.table_schema = pk.table_schema 
    AND c.table_name = pk.table_name 
    AND c.column_name = pk.column_name
  LEFT JOIN (
    SELECT 
      kcu.table_schema,
      kcu.table_name,
      kcu.column_name,
      TRUE as is_foreign
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
  ) fk ON c.table_schema = fk.table_schema 
    AND c.table_name = fk.table_name 
    AND c.column_name = fk.column_name
  WHERE c.table_schema NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
  ORDER BY c.table_schema, c.table_name, c.ordinal_position;
$$;

-- Function to get foreign key relationships
CREATE OR REPLACE FUNCTION get_schema_relationships()
RETURNS TABLE (
  constraint_name TEXT,
  source_schema TEXT,
  source_table TEXT,
  source_column TEXT,
  target_schema TEXT,
  target_table TEXT,
  target_column TEXT
)
LANGUAGE SQL
SECURITY INVOKER
AS $$
  SELECT 
    tc.constraint_name::TEXT,
    kcu.table_schema::TEXT as source_schema,
    kcu.table_name::TEXT as source_table,
    kcu.column_name::TEXT as source_column,
    ccu.table_schema::TEXT as target_schema,
    ccu.table_name::TEXT as target_table,
    ccu.column_name::TEXT as target_column
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
  JOIN information_schema.constraint_column_usage ccu 
    ON ccu.constraint_name = tc.constraint_name
  WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
  ORDER BY tc.constraint_name;
$$;

-- Function to get RLS policies
CREATE OR REPLACE FUNCTION get_rls_policies()
RETURNS TABLE (
  schema_name TEXT,
  table_name TEXT,
  policy_name TEXT,
  policy_command TEXT,
  policy_roles TEXT[],
  policy_expression TEXT
)
LANGUAGE SQL
SECURITY INVOKER
AS $$
  SELECT 
    schemaname::TEXT,
    tablename::TEXT,
    policyname::TEXT,
    cmd::TEXT as policy_command,
    roles::TEXT[] as policy_roles,
    qual::TEXT as policy_expression
  FROM pg_policies
  WHERE schemaname NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
  ORDER BY schemaname, tablename, policyname;
$$;
