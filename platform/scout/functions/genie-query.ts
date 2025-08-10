// Genie Query Edge Function
// Natural language to SQL (SELECT-only) with security constraints

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const chatUrl = Deno.env.get('CHAT_URL') || 'https://api.openai.com/v1/chat/completions'
const chatKey = Deno.env.get('CHAT_KEY') || Deno.env.get('OPENAI_API_KEY')!

interface GenieRequest {
  prompt: string
  context?: {
    schema?: string
    tables?: string[]
    user_region?: string
  }
}

const SYSTEM_PROMPT = `You are a SQL query generator for a sari-sari store analytics platform.

Available schemas and tables:
- scout.silver_transactions: Transaction details (id, store_id, ts, region, barangay, product_category, brand_name, sku, peso_value, etc.)
- scout.gold_txn_daily: Daily aggregates by region/category/brand
- scout.gold_product_mix: Product performance metrics
- scout.gold_basket_patterns: Basket co-occurrence analysis
- scout.gold_demographics: Customer demographics analysis

RULES:
1. ONLY generate SELECT queries - no INSERT/UPDATE/DELETE/DROP
2. Always use table aliases
3. Include proper JOINs when needed
4. Limit results to 1000 rows max
5. Use proper date functions for time-based queries
6. Never expose sensitive data (use aggregates where appropriate)

Return ONLY the SQL query, no explanations.`

async function generateSQL(prompt: string, context?: any): Promise<string> {
  const messages = [
    { role: 'system', content: SYSTEM_PROMPT },
    { 
      role: 'user', 
      content: `Generate a SQL query for: ${prompt}${context ? '\nContext: ' + JSON.stringify(context) : ''}`
    }
  ]

  const response = await fetch(chatUrl, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${chatKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4',
      messages: messages,
      temperature: 0.1,
      max_tokens: 500,
    }),
  })

  if (!response.ok) {
    throw new Error(`Chat API error: ${response.status} ${await response.text()}`)
  }

  const data = await response.json()
  return data.choices[0].message.content.trim()
}

function sanitizeSQL(sql: string): string {
  // Remove any non-SELECT statements
  const normalized = sql.toUpperCase().trim()
  
  // Block dangerous keywords
  const blockedKeywords = [
    'INSERT', 'UPDATE', 'DELETE', 'DROP', 'CREATE', 'ALTER', 'TRUNCATE',
    'EXEC', 'EXECUTE', 'GRANT', 'REVOKE', '--', '/*', '*/', ';'
  ]
  
  for (const keyword of blockedKeywords) {
    if (normalized.includes(keyword)) {
      throw new Error(`Blocked keyword detected: ${keyword}`)
    }
  }
  
  // Ensure it starts with SELECT
  if (!normalized.startsWith('SELECT')) {
    throw new Error('Only SELECT queries are allowed')
  }
  
  // Add LIMIT if not present
  if (!normalized.includes('LIMIT')) {
    sql += ' LIMIT 1000'
  }
  
  return sql
}

serve(async (req) => {
  try {
    if (req.method === 'OPTIONS') {
      return new Response('ok', {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        },
      })
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false }
    })

    const { prompt, context }: GenieRequest = await req.json()

    if (!prompt || typeof prompt !== 'string') {
      return new Response(
        JSON.stringify({ error: 'prompt is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Generate SQL
    const generatedSQL = await generateSQL(prompt, context)
    
    // Sanitize and validate
    const sql = sanitizeSQL(generatedSQL)
    
    // Execute query
    const startTime = Date.now()
    const { data, error, count } = await supabase.rpc('exec_sql_json', {
      query: sql
    })
    const queryTime = Date.now() - startTime

    if (error) {
      return new Response(
        JSON.stringify({ 
          error: 'Query execution failed',
          details: error.message,
          sql: sql 
        }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Log for analytics
    await supabase.from('genie_query_log').insert({
      prompt: prompt,
      generated_sql: sql,
      row_count: count || data?.length || 0,
      query_time_ms: queryTime,
      context: context,
      created_at: new Date().toISOString()
    }).catch(err => console.error('Failed to log query:', err))

    return new Response(
      JSON.stringify({
        sql: sql,
        results: data || [],
        row_count: count || data?.length || 0,
        query_time_ms: queryTime,
        cached: false
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  } catch (error) {
    console.error('Genie query error:', error)
    return new Response(
      JSON.stringify({ 
        error: error.message,
        type: error.name 
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      }
    )
  }
})