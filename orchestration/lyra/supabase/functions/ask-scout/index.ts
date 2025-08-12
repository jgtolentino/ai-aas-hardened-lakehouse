
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-tenant-id',
};

// Cache configuration
const CACHE_TTL = 300; // 5 minutes
const cache = new Map();

// Guardrail patterns
const BLOCKED_PATTERNS = [
  /drop\s+table/i,
  /delete\s+from/i,
  /truncate/i,
  /alter\s+table/i,
  /create\s+table/i,
  /grant\s+/i,
  /revoke\s+/i,
];

// Response schema validation
function validateChartPayload(payload) {
  const requiredFields = ['type', 'data', 'options'];
  const validTypes = ['bar', 'line', 'pie', 'scatter', 'area'];
  
  if (!payload || typeof payload !== 'object') {
    return { valid: false, error: 'Payload must be an object' };
  }
  
  for (const field of requiredFields) {
    if (!(field in payload)) {
      return { valid: false, error: `Missing required field: ${field}` };
    }
  }
  
  if (!validTypes.includes(payload.type)) {
    return { valid: false, error: `Invalid chart type: ${payload.type}` };
  }
  
  return { valid: true };
}

// Input sanitization
function sanitizeQuery(query) {
  // Remove potentially dangerous patterns
  let sanitized = query.trim();
  
  for (const pattern of BLOCKED_PATTERNS) {
    if (pattern.test(sanitized)) {
      throw new Error(`Query contains blocked pattern: ${pattern.source}`);
    }
  }
  
  // Limit length
  if (sanitized.length > 1000) {
    sanitized = sanitized.substring(0, 1000);
  }
  
  return sanitized;
}

// Cache key generation
function getCacheKey(query, tenantId) {
  const crypto = globalThis.crypto || require('crypto');
  const data = `${query}-${tenantId}`;
  const encoder = new TextEncoder();
  const hash = crypto.subtle ? 
    crypto.subtle.digest('SHA-256', encoder.encode(data)) :
    require('crypto').createHash('sha256').update(data).digest('hex');
  return hash;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  
  try {
    const { q: query } = await req.json();
    const tenantId = req.headers.get('x-tenant-id');
    const authHeader = req.headers.get('authorization');
    
    // Validate inputs
    if (!query || typeof query !== 'string') {
      throw new Error('Query parameter is required and must be a string');
    }
    
    if (!tenantId) {
      throw new Error('X-Tenant-Id header is required');
    }
    
    if (!authHeader) {
      throw new Error('Authorization header is required');
    }
    
    // Sanitize query
    const sanitizedQuery = sanitizeQuery(query);
    
    // Check cache
    const cacheKey = await getCacheKey(sanitizedQuery, tenantId);
    const cacheKeyStr = typeof cacheKey === 'string' ? cacheKey : Array.from(new Uint8Array(cacheKey)).map(b => b.toString(16).padStart(2, '0')).join('');
    const cachedResult = cache.get(cacheKeyStr);
    const isFromCache = !!cachedResult;
    
    if (cachedResult && Date.now() - cachedResult.timestamp < CACHE_TTL * 1000) {
      console.log(`Cache HIT for key: ${cacheKeyStr.substring(0, 16)}...`);
      return new Response(JSON.stringify({
        ...cachedResult.data,
        cache_hit: true,
        cached_at: cachedResult.timestamp
      }), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
          'Cache-Control': `public, s-maxage=${CACHE_TTL}, stale-while-revalidate=60`,
          'X-Cache': 'HIT',
        }
      });
    }
    
    console.log(`Cache MISS for key: ${cacheKeyStr.substring(0, 16)}...`);
    
    // Initialize Supabase client with user JWT
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const jwt = authHeader.replace('Bearer ', '');
    
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: `Bearer ${jwt}`,
          'X-Tenant-Id': tenantId,
        },
      },
    });
    
    // Mock LLM processing (replace with actual LLM call)
    const mockResponse = {
      answer: `Analysis for "${sanitizedQuery}" shows trending brands with 15% growth in the last 30 days.`,
      chart_config: {
        type: 'bar',
        data: {
          labels: ['Brand A', 'Brand B', 'Brand C'],
          datasets: [{
            label: 'Growth %',
            data: [15, 12, 8],
            backgroundColor: ['#0078d4', '#106ebe', '#0060c7']
          }]
        },
        options: {
          responsive: true,
          plugins: {
            title: {
              display: true,
              text: 'Brand Performance - Last 30 Days'
            }
          }
        }
      },
      sql_query: 'SELECT brand_name, growth_rate FROM gold_brand_performance WHERE period = \'last_30_days\' ORDER BY growth_rate DESC LIMIT 10',
      sources: ['gold_brand_performance', 'silver_transactions'],
      confidence: 0.89
    };
    
    // Validate chart payload
    const validation = validateChartPayload(mockResponse.chart_config);
    if (!validation.valid) {
      throw new Error(`Invalid chart configuration: ${validation.error}`);
    }
    
    // Store in cache
    cache.set(cacheKeyStr, {
      data: mockResponse,
      timestamp: Date.now()
    });
    
    // Clean old cache entries periodically
    if (cache.size > 100) {
      const cutoff = Date.now() - CACHE_TTL * 1000 * 2;
      for (const [key, value] of cache.entries()) {
        if (value.timestamp < cutoff) {
          cache.delete(key);
        }
      }
    }
    
    return new Response(JSON.stringify({
      ...mockResponse,
      cache_hit: false,
      processed_at: Date.now(),
      query_sanitized: sanitizedQuery !== query
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
        'Cache-Control': `public, s-maxage=${CACHE_TTL}, stale-while-revalidate=60`,
        'X-Cache': 'MISS',
        'X-Tenant-Id': tenantId,
      }
    });
    
  } catch (error) {
    console.error('Ask Scout error:', error);
    
    return new Response(JSON.stringify({
      error: error.message,
      timestamp: Date.now(),
      type: 'ask_scout_error'
    }), {
      status: 400,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      }
    });
  }
});
