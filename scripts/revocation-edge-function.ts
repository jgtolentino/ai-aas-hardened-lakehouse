import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface RevokeRequest {
  token?: string
  jti?: string
  reason?: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }), 
        { 
          status: 405, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const { token, jti, reason = 'Manual revocation' } = await req.json() as RevokeRequest

    if (!token && !jti) {
      return new Response(
        JSON.stringify({ error: 'Either token or jti must be provided' }), 
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Extract JTI from token if provided
    let tokenJti = jti
    if (token && !jti) {
      try {
        const parts = token.split('.')
        if (parts.length !== 3) {
          throw new Error('Invalid JWT format')
        }
        
        const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')))
        tokenJti = payload.jti
        
        if (!tokenJti) {
          return new Response(
            JSON.stringify({ error: 'Token does not contain jti claim' }), 
            { 
              status: 400, 
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          )
        }
      } catch (error) {
        return new Response(
          JSON.stringify({ error: 'Failed to parse token', details: error.message }), 
          { 
            status: 400, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }
    }

    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Create revoked_tokens table if it doesn't exist
    await supabaseClient.rpc('exec', {
      sql: `
        CREATE TABLE IF NOT EXISTS revoked_tokens (
          jti TEXT PRIMARY KEY,
          revoked_at TIMESTAMP DEFAULT NOW(),
          reason TEXT
        );
      `
    })

    // Add token to revocation list
    const { data, error } = await supabaseClient
      .from('revoked_tokens')
      .upsert({ 
        jti: tokenJti, 
        reason,
        revoked_at: new Date().toISOString()
      })

    if (error) {
      console.error('Database error:', error)
      return new Response(
        JSON.stringify({ error: 'Failed to revoke token', details: error.message }), 
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Token revoked successfully',
        jti: tokenJti,
        revoked_at: new Date().toISOString()
      }), 
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('Revocation error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }), 
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})