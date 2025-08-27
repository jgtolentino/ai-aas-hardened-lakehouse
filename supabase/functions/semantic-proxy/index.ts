import "jsr:@supabase/functions-js/edge-runtime.d.ts";

interface SemanticQueryRequest {
  objects: string[];
  filters?: Record<string, any>;
  metrics: string[];
  group_by?: string[];
}

Deno.serve(async (req: Request) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };

  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { objects, filters = {}, metrics, group_by = [] }: SemanticQueryRequest = await req.json();

    // Validate required fields
    if (!objects || !Array.isArray(objects) || objects.length === 0) {
      return new Response(
        JSON.stringify({ error: 'objects array is required and cannot be empty' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!metrics || !Array.isArray(metrics) || metrics.length === 0) {
      return new Response(
        JSON.stringify({ error: 'metrics array is required and cannot be empty' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Get Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    );

    // Execute semantic query via RPC
    const { data, error } = await supabaseClient.rpc('semantic_query', {
      objects,
      filters,
      metrics,
      group_by
    });

    if (error) {
      console.error('Semantic query error:', error);
      return new Response(
        JSON.stringify({ error: `Query execution failed: ${error.message}` }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify(data),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );

  } catch (error) {
    console.error('Semantic proxy error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

// Import createClient from supabase-js
import { createClient } from 'jsr:@supabase/supabase-js@2';