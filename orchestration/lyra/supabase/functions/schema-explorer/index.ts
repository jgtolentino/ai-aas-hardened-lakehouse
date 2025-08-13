
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
    id: `${table.schema_name}.${table.table_name}`,
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
    id: `${rel.source_schema}.${rel.source_table}.${rel.source_column}->${rel.target_schema}.${rel.target_table}.${rel.target_column}`,
    source: `${rel.source_schema}.${rel.source_table}`,
    target: `${rel.target_schema}.${rel.target_table}`,
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
