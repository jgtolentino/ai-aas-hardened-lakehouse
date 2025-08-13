#!/usr/bin/env node
/**
 * W4: SQL Playground v1.1 - Add saved queries, EXPLAIN viewer, rate limiting
 * Gate: UPDATE/INSERT blocked with clear error; EXPLAIN returns plan JSON
 */

import fs from 'fs';
import path from 'path';

console.log('🔧 Enhancing SQL Playground v1.1...');

// SQL Playground Edge Function with enhanced features
const sqlPlaygroundFunction = `
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
  /^\\s*(update|insert|delete|drop|create|alter|grant|revoke)/i,
  /\\b(pg_sleep|dblink|copy)\\b/i,
  /--.*drop|;.*drop/i,
];

// Allowed patterns for EXPLAIN
const EXPLAIN_PATTERNS = [
  /^\\s*explain\\s+(analyze\\s+)?(verbose\\s+)?select/i,
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
  const isSelect = /^\\s*select/i.test(trimmed);
  
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
    throw new Error(\`Query execution failed: \${error.message}\`);
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
`;

// Database schema for saved queries
const savedQueriesSchema = `
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
  IF NOT (p_sql ~* '^\\s*SELECT') THEN
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
  IF NOT (p_sql ~* '^\\s*EXPLAIN') THEN
    RAISE EXCEPTION 'Only EXPLAIN statements are allowed';
  END IF;
  
  -- Execute EXPLAIN and return as JSON
  RETURN QUERY EXECUTE format('
    SELECT to_json(array_agg(row_to_json(t))) 
    FROM (%s) t
  ', p_sql);
END;
$$;
`;

try {
  // Write the enhanced Edge Function
  const edgeFunctionPaths = [
    './supabase/functions/sql-playground/index.ts',
    './platform/scout/functions/sql-playground/index.ts',
    './functions/sql-playground/index.ts'
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
    targetPath = './supabase/functions/sql-playground/index.ts';
    fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  }
  
  fs.writeFileSync(targetPath, sqlPlaygroundFunction);
  console.log(`✅ Enhanced SQL Playground function: ${targetPath}`);
  
  // Write database schema
  const schemaPath = './orchestration/lyra/scripts/playground/saved-queries-schema.sql';
  fs.mkdirSync(path.dirname(schemaPath), { recursive: true });
  fs.writeFileSync(schemaPath, savedQueriesSchema);
  console.log(`✅ Saved queries schema: ${schemaPath}`);
  
  // Create test queries for validation
  const testQueries = {
    valid: [
      "SELECT 1 as test",
      "EXPLAIN SELECT * FROM gold_brand_performance LIMIT 10",
      "EXPLAIN ANALYZE SELECT brand_name, sum(revenue) FROM silver_transactions GROUP BY brand_name"
    ],
    blocked: [
      "UPDATE users SET name = 'hacked'",
      "INSERT INTO test VALUES (1)",
      "DELETE FROM important_table",
      "DROP TABLE users"
    ]
  };
  
  const testFile = path.join(path.dirname(targetPath), 'test-queries.json');
  fs.writeFileSync(testFile, JSON.stringify(testQueries, null, 2));
  console.log(`✅ Test queries created: ${testFile}`);
  
  console.log('🔧 SQL Playground v1.1 enhancement complete');
  process.exit(0);
  
} catch (error) {
  console.error('❌ Error enhancing SQL Playground:', error.message);
  process.exit(1);
}