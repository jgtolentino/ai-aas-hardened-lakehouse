#!/usr/bin/env node
/**
 * W6: API Explorer - Generate catalog from RPCs/views with Try-It functionality
 * Gate: 5 RPCs succeed live; errors show PostgREST messages
 */

import fs from 'fs';
import path from 'path';

console.log('🔌 Generating API Explorer catalog...');

const apiExplorerFunction = `
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-tenant-id',
};

async function getAPIEndpoints(supabase) {
  // Get all functions (RPCs)
  const { data: functions, error: functionsError } = await supabase.rpc('get_api_functions');
  if (functionsError) throw functionsError;

  // Get all views
  const { data: views, error: viewsError } = await supabase.rpc('get_api_views');
  if (viewsError) throw viewsError;

  // Get all tables accessible via REST API
  const { data: tables, error: tablesError } = await supabase.rpc('get_api_tables');
  if (tablesError) throw tablesError;

  return { functions, views, tables };
}

async function testEndpoint(supabase, endpoint, params = {}) {
  try {
    const startTime = Date.now();
    let result;
    let method = 'GET';

    if (endpoint.type === 'function') {
      // Test RPC call
      method = 'POST';
      const { data, error } = await supabase.rpc(endpoint.name, params);
      if (error) throw error;
      result = data;
    } else {
      // Test table/view access
      const { data, error } = await supabase
        .from(endpoint.name)
        .select('*')
        .limit(1);
      if (error) throw error;
      result = data;
    }

    return {
      success: true,
      response_time_ms: Date.now() - startTime,
      method,
      result_preview: Array.isArray(result) ? result.slice(0, 3) : result
    };

  } catch (error) {
    return {
      success: false,
      error: error.message,
      postgrest_code: error.code,
      postgrest_details: error.details,
      postgrest_hint: error.hint
    };
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const action = url.searchParams.get('action') || 'catalog';
    const endpoint = url.searchParams.get('endpoint');
    const testParams = url.searchParams.get('params');
    
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

    if (action === 'test' && endpoint) {
      // Test specific endpoint
      const params = testParams ? JSON.parse(testParams) : {};
      
      // Find endpoint details
      const { functions, views, tables } = await getAPIEndpoints(supabase);
      const allEndpoints = [...functions, ...views, ...tables];
      const targetEndpoint = allEndpoints.find(e => e.name === endpoint);
      
      if (!targetEndpoint) {
        throw new Error(\`Endpoint not found: \${endpoint}\`);
      }

      const testResult = await testEndpoint(supabase, targetEndpoint, params);
      
      return new Response(JSON.stringify({
        endpoint: targetEndpoint,
        test_result: testResult,
        tested_at: new Date().toISOString()
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Default: return full catalog
    const { functions, views, tables } = await getAPIEndpoints(supabase);
    
    const catalog = {
      functions: functions.map(fn => ({
        ...fn,
        url: \`/rest/v1/rpc/\${fn.name}\`,
        method: 'POST',
        try_it_params: fn.parameters || []
      })),
      views: views.map(view => ({
        ...view,
        url: \`/rest/v1/\${view.name}\`,
        method: 'GET',
        supports_filtering: true,
        supports_ordering: true
      })),
      tables: tables.map(table => ({
        ...table,
        url: \`/rest/v1/\${table.name}\`,
        methods: ['GET', 'POST', 'PATCH', 'DELETE'],
        rls_enabled: table.rls_enabled || false
      })),
      summary: {
        total_endpoints: functions.length + views.length + tables.length,
        functions: functions.length,
        views: views.length,
        tables: tables.length,
        generated_at: new Date().toISOString()
      }
    };

    return new Response(JSON.stringify(catalog), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('API Explorer error:', error);
    
    return new Response(JSON.stringify({
      error: error.message,
      type: 'api_explorer_error'
    }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});
`;

const apiIntrospectionFunctions = `
-- Get all accessible functions
CREATE OR REPLACE FUNCTION get_api_functions()
RETURNS TABLE (
  name TEXT,
  schema_name TEXT,
  return_type TEXT,
  parameters JSONB,
  description TEXT,
  security_definer BOOLEAN
)
LANGUAGE SQL
SECURITY INVOKER
AS $$
  SELECT 
    p.proname::TEXT as name,
    n.nspname::TEXT as schema_name,
    pg_catalog.format_type(p.prorettype, NULL)::TEXT as return_type,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'name', par.parameter_name,
          'type', par.data_type,
          'mode', par.parameter_mode,
          'default', par.parameter_default
        ) ORDER BY par.ordinal_position
      ) FILTER (WHERE par.parameter_name IS NOT NULL),
      '[]'::jsonb
    ) as parameters,
    obj_description(p.oid, 'pg_proc')::TEXT as description,
    p.prosecdef as security_definer
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  LEFT JOIN information_schema.parameters par ON 
    par.specific_name = p.proname || '_' || p.oid
  WHERE n.nspname NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
    AND p.prokind = 'f'  -- Only functions, not procedures
    AND has_function_privilege(p.oid, 'execute')
  GROUP BY p.oid, p.proname, n.nspname, p.prorettype, p.prosecdef
  ORDER BY n.nspname, p.proname;
$$;

-- Get all accessible views
CREATE OR REPLACE FUNCTION get_api_views()
RETURNS TABLE (
  name TEXT,
  schema_name TEXT,
  column_count INTEGER,
  is_updatable BOOLEAN,
  description TEXT
)
LANGUAGE SQL
SECURITY INVOKER
AS $$
  SELECT 
    v.table_name::TEXT as name,
    v.table_schema::TEXT as schema_name,
    (SELECT COUNT(*) FROM information_schema.columns c 
     WHERE c.table_name = v.table_name AND c.table_schema = v.table_schema)::INTEGER as column_count,
    v.is_updatable::BOOLEAN,
    obj_description(c.oid, 'pg_class')::TEXT as description
  FROM information_schema.views v
  LEFT JOIN pg_class c ON c.relname = v.table_name
  LEFT JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = v.table_schema
  WHERE v.table_schema NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
    AND has_table_privilege(v.table_schema || '.' || v.table_name, 'select')
  ORDER BY v.table_schema, v.table_name;
$$;

-- Get all accessible tables
CREATE OR REPLACE FUNCTION get_api_tables()
RETURNS TABLE (
  name TEXT,
  schema_name TEXT,
  column_count INTEGER,
  rls_enabled BOOLEAN,
  has_primary_key BOOLEAN,
  description TEXT
)
LANGUAGE SQL
SECURITY INVOKER
AS $$
  SELECT 
    t.table_name::TEXT as name,
    t.table_schema::TEXT as schema_name,
    (SELECT COUNT(*) FROM information_schema.columns c 
     WHERE c.table_name = t.table_name AND c.table_schema = t.table_schema)::INTEGER as column_count,
    COALESCE(c.relrowsecurity, FALSE) as rls_enabled,
    EXISTS(
      SELECT 1 FROM information_schema.table_constraints tc
      WHERE tc.table_name = t.table_name 
        AND tc.table_schema = t.table_schema 
        AND tc.constraint_type = 'PRIMARY KEY'
    ) as has_primary_key,
    obj_description(c.oid, 'pg_class')::TEXT as description
  FROM information_schema.tables t
  LEFT JOIN pg_class c ON c.relname = t.table_name
  LEFT JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = t.table_schema
  WHERE t.table_schema NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
    AND t.table_type = 'BASE TABLE'
    AND has_table_privilege(t.table_schema || '.' || t.table_name, 'select')
  ORDER BY t.table_schema, t.table_name;
$$;
`;

try {
  // Write the API Explorer Edge Function
  const edgeFunctionPath = './supabase/functions/api-explorer/index.ts';
  fs.mkdirSync(path.dirname(edgeFunctionPath), { recursive: true });
  fs.writeFileSync(edgeFunctionPath, apiExplorerFunction);
  console.log(`✅ API Explorer function: ${edgeFunctionPath}`);
  
  // Write database functions
  const functionsPath = './orchestration/lyra/scripts/api-explorer/api-introspection-functions.sql';
  fs.writeFileSync(functionsPath, apiIntrospectionFunctions);
  console.log(`✅ API introspection functions: ${functionsPath}`);
  
  console.log('🔌 API Explorer catalog generated successfully');
  process.exit(0);
  
} catch (error) {
  console.error('❌ Error generating API Explorer:', error.message);
  process.exit(1);
}