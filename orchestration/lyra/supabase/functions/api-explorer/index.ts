
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
        throw new Error(`Endpoint not found: ${endpoint}`);
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
        url: `/rest/v1/rpc/${fn.name}`,
        method: 'POST',
        try_it_params: fn.parameters || []
      })),
      views: views.map(view => ({
        ...view,
        url: `/rest/v1/${view.name}`,
        method: 'GET',
        supports_filtering: true,
        supports_ordering: true
      })),
      tables: tables.map(table => ({
        ...table,
        url: `/rest/v1/${table.name}`,
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
