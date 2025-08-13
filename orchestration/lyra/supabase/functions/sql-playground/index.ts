
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-tenant-id',
};

// Rate limiting storage
const rateLimiter = new Map();
const RATE_LIMIT = 10; // requests per minute per IP
const RATE_WINDOW = 60 * 1000; // 1 minute in milliseconds

// Blocked SQL patterns for safety
const BLOCKED_PATTERNS = [
  /^\s*(update|insert|delete|drop|create|alter|grant|revoke)/i,
  /\b(pg_sleep|dblink|copy)\b/i,
  /--.*drop|;.*drop/i,
];

// Allowed patterns for EXPLAIN
const EXPLAIN_PATTERNS = [
  /^\s*explain\s+(analyze\s+)?(verbose\s+)?select/i,
];

function checkRateLimit(clientIP) {
  const now = Date.now();
  const userRequests = rateLimiter.get(clientIP) || [];
  
  // Remove old requests outside the window
  const validRequests = userRequests.filter(time => now - time < RATE_WINDOW);
  
  if (validRequests.length >= RATE_LIMIT) {
    return false; // Rate limit exceeded
  }
  
  // Add current request
  validRequests.push(now);
  rateLimiter.set(clientIP, validRequests);
  
  return true;
}

function validateSQL(sql) {
  const trimmed = sql.trim();
  
  // Check for blocked patterns
  for (const pattern of BLOCKED_PATTERNS) {
    if (pattern.test(trimmed)) {
      return {
        valid: false,
        error: 'SQL contains blocked operation. Only SELECT and EXPLAIN statements are allowed.',
        type: 'BLOCKED_OPERATION'
      };
    }
  }
  
  // Allow EXPLAIN queries
  const isExplain = EXPLAIN_PATTERNS.some(pattern => pattern.test(trimmed));
  const isSelect = /^\s*select/i.test(trimmed);
  
  if (!isSelect && !isExplain) {
    return {
      valid: false,
      error: 'Only SELECT and EXPLAIN SELECT statements are allowed.',
      type: 'INVALID_STATEMENT'
    };
  }
  
  return { valid: true, isExplain };
}

async function executeSafeSQL(supabase, sql, isExplain = false) {
  try {
    if (isExplain) {
      // For EXPLAIN queries, use RPC to safely execute
      const { data, error } = await supabase.rpc('exec_explain', {
        p_sql: sql
      });
      
      if (error) throw error;
      
      return {
        data: data,
        type: 'explain',
        execution_time_ms: 0 // EXPLAIN doesn't need timing
      };
    } else {
      // For SELECT queries, use RPC with timing
      const startTime = Date.now();
      const { data, error } = await supabase.rpc('exec_select', {
        p_sql: sql
      });
      
      if (error) throw error;
      
      return {
        data: data,
        type: 'select',
        execution_time_ms: Date.now() - startTime
      };
    }
  } catch (error) {
    throw new Error(`Query execution failed: ${error.message}`);
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  
  try {
    const clientIP = req.headers.get('x-forwarded-for') || 
                    req.headers.get('x-real-ip') || 
                    'unknown';
    
    // Rate limiting check
    if (!checkRateLimit(clientIP)) {
      return new Response(JSON.stringify({
        error: 'Rate limit exceeded. Maximum 10 requests per minute.',
        type: 'RATE_LIMIT_EXCEEDED',
        retry_after: 60
      }), {
        status: 429,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
          'Retry-After': '60'
        }
      });
    }
    
    const { p_sql: sql, action = 'execute' } = await req.json();
    const tenantId = req.headers.get('x-tenant-id');
    const authHeader = req.headers.get('authorization');
    
    if (!sql || typeof sql !== 'string') {
      throw new Error('SQL query is required');
    }
    
    if (!tenantId) {
      throw new Error('X-Tenant-Id header is required');
    }
    
    if (!authHeader) {
      throw new Error('Authorization header is required');
    }
    
    // Handle different actions
    if (action === 'save') {
      // Save query functionality
      const { query_name, query_sql, description = '' } = await req.json();
      
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL')!,
        Deno.env.get('SUPABASE_ANON_KEY')!,
        {
          global: {
            headers: {
              Authorization: authHeader,
              'X-Tenant-Id': tenantId,
            },
          },
        }
      );
      
      const { data, error } = await supabase
        .from('saved_queries')
        .insert({
          name: query_name,
          sql: query_sql,
          description: description,
          tenant_id: tenantId,
          created_by: (await supabase.auth.getUser()).data.user?.id
        });
        
      if (error) throw error;
      
      return new Response(JSON.stringify({
        success: true,
        message: 'Query saved successfully',
        query_id: data[0]?.id
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
    
    if (action === 'list') {
      // List saved queries
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL')!,
        Deno.env.get('SUPABASE_ANON_KEY')!,
        {
          global: {
            headers: {
              Authorization: authHeader,
              'X-Tenant-Id': tenantId,
            },
          },
        }
      );
      
      const { data, error } = await supabase
        .from('saved_queries')
        .select('id, name, description, created_at, updated_at')
        .eq('tenant_id', tenantId)
        .order('updated_at', { ascending: false })
        .limit(50);
        
      if (error) throw error;
      
      return new Response(JSON.stringify({
        queries: data,
        count: data.length
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
    
    // Execute query
    const validation = validateSQL(sql);
    if (!validation.valid) {
      return new Response(JSON.stringify({
        error: validation.error,
        type: validation.type,
        sql_received: sql.substring(0, 100) + '...'
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
    
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      {
        global: {
          headers: {
            Authorization: authHeader,
            'X-Tenant-Id': tenantId,
          },
        },
      }
    );
    
    const result = await executeSafeSQL(supabase, sql, validation.isExplain);
    
    return new Response(JSON.stringify({
      success: true,
      result: result.data,
      query_type: result.type,
      execution_time_ms: result.execution_time_ms,
      row_count: Array.isArray(result.data) ? result.data.length : 0,
      sql_query: sql,
      executed_at: new Date().toISOString()
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
    
  } catch (error) {
    console.error('SQL Playground error:', error);
    
    return new Response(JSON.stringify({
      error: error.message,
      type: 'EXECUTION_ERROR',
      timestamp: new Date().toISOString()
    }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});
