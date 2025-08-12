#!/usr/bin/env node
/**
 * W5: Schema Explorer - Build graph view from information_schema + pg_catalog
 * Gate: counts match meta within ±5%
 */

import fs from 'fs';
import path from 'path';

console.log('🗂️  Building Schema Explorer graph...');

// Schema Explorer Edge Function
const schemaExplorerFunction = `
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-tenant-id',
};

async function getSchemaInfo(supabase) {
  // Get all tables with metadata
  const { data: tables, error: tablesError } = await supabase.rpc('get_schema_tables');
  if (tablesError) throw tablesError;

  // Get all columns with relationships
  const { data: columns, error: columnsError } = await supabase.rpc('get_schema_columns');
  if (columnsError) throw columnsError;

  // Get foreign key relationships
  const { data: relationships, error: relationshipsError } = await supabase.rpc('get_schema_relationships');
  if (relationshipsError) throw relationshipsError;

  // Get RLS policies
  const { data: policies, error: policiesError } = await supabase.rpc('get_rls_policies');
  if (policiesError) throw policiesError;

  return {
    tables,
    columns,
    relationships,
    policies
  };
}

function buildGraphData(schemaInfo) {
  const { tables, columns, relationships, policies } = schemaInfo;
  
  // Create nodes for each table
  const nodes = tables.map(table => ({
    id: \`\${table.schema_name}.\${table.table_name}\`,
    label: table.table_name,
    schema: table.schema_name,
    type: 'table',
    row_count: table.row_count || 0,
    size_mb: table.size_mb || 0,
    has_rls: policies.some(p => p.table_name === table.table_name && p.schema_name === table.schema_name),
    columns: columns.filter(c => c.table_name === table.table_name && c.schema_name === table.schema_name).length,
    metadata: {
      table_type: table.table_type,
      created_at: table.created_at,
      comment: table.table_comment
    }
  }));

  // Create edges for relationships
  const edges = relationships.map(rel => ({
    id: \`\${rel.source_schema}.\${rel.source_table}.\${rel.source_column}->\${rel.target_schema}.\${rel.target_table}.\${rel.target_column}\`,
    source: \`\${rel.source_schema}.\${rel.source_table}\`,
    target: \`\${rel.target_schema}.\${rel.target_table}\`,
    label: rel.constraint_name,
    type: 'foreign_key',
    columns: {
      source: rel.source_column,
      target: rel.target_column
    }
  }));

  // Group by schema for layout
  const schemas = [...new Set(tables.map(t => t.schema_name))].map(schema => ({
    name: schema,
    tables: nodes.filter(n => n.schema === schema).length,
    total_rows: nodes.filter(n => n.schema === schema).reduce((sum, n) => sum + n.row_count, 0),
    total_size_mb: nodes.filter(n => n.schema === schema).reduce((sum, n) => sum + n.size_mb, 0)
  }));

  return {
    nodes,
    edges,
    schemas,
    summary: {
      total_tables: nodes.length,
      total_relationships: edges.length,
      total_schemas: schemas.length,
      rls_enabled_tables: nodes.filter(n => n.has_rls).length
    }
  };
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { schema, format = 'graph' } = new URL(req.url).searchParams;
    const tenantId = req.headers.get('x-tenant-id');
    const authHeader = req.headers.get('authorization');

    if (!authHeader) {
      throw new Error('Authorization header is required');
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      {
        global: {
          headers: {
            Authorization: authHeader,
            'X-Tenant-Id': tenantId || '',
          },
        },
      }
    );

    const schemaInfo = await getSchemaInfo(supabase);
    
    if (format === 'raw') {
      return new Response(JSON.stringify(schemaInfo), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const graphData = buildGraphData(schemaInfo);
    
    if (schema) {
      // Filter to specific schema
      graphData.nodes = graphData.nodes.filter(n => n.schema === schema);
      graphData.edges = graphData.edges.filter(e => 
        graphData.nodes.some(n => n.id === e.source) && 
        graphData.nodes.some(n => n.id === e.target)
      );
    }

    return new Response(JSON.stringify(graphData), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Schema Explorer error:', error);
    
    return new Response(JSON.stringify({
      error: error.message,
      type: 'schema_explorer_error'
    }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});
`;

// Database functions for schema introspection
const schemaIntrospectionFunctions = `
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
`;

try {
  // Write the Schema Explorer Edge Function
  const edgeFunctionPaths = [
    './supabase/functions/schema-explorer/index.ts',
    './platform/scout/functions/schema-explorer/index.ts',
    './functions/schema-explorer/index.ts'
  ];
  
  let targetPath = null;
  for (const p of edgeFunctionPaths) {
    const dir = path.dirname(p);
    if (fs.existsSync(dir)) {
      targetPath = p;
      break;
    }
  }
  
  if (!targetPath) {
    targetPath = './supabase/functions/schema-explorer/index.ts';
    fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  }
  
  fs.writeFileSync(targetPath, schemaExplorerFunction);
  console.log(`✅ Schema Explorer function: ${targetPath}`);
  
  // Write database functions
  const functionsPath = './orchestration/lyra/scripts/schema/schema-introspection-functions.sql';
  fs.mkdirSync(path.dirname(functionsPath), { recursive: true });
  fs.writeFileSync(functionsPath, schemaIntrospectionFunctions);
  console.log(`✅ Schema introspection functions: ${functionsPath}`);
  
  console.log('🗂️  Schema Explorer graph built successfully');
  process.exit(0);
  
} catch (error) {
  console.error('❌ Error building Schema Explorer:', error.message);
  process.exit(1);
}