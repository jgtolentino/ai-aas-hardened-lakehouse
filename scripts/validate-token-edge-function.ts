import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Extract token from Authorization header
    const authHeader = req.headers.get('authorization')
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({ error: 'Missing or invalid authorization header' }), 
        { 
          status: 401, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const token = authHeader.substring(7) // Remove 'Bearer '

    // Parse token
    let payload: any
    try {
      const parts = token.split('.')
      if (parts.length !== 3) {
        throw new Error('Invalid JWT format')
      }
      
      payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')))
    } catch (error) {
      return new Response(
        JSON.stringify({ error: 'Invalid token format', valid: false }), 
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Check expiration
    const now = Math.floor(Date.now() / 1000)
    if (payload.exp && payload.exp < now) {
      return new Response(
        JSON.stringify({ 
          error: 'Token expired', 
          valid: false,
          expired_at: new Date(payload.exp * 1000).toISOString()
        }), 
        { 
          status: 401, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Check revocation if JTI is present
    if (payload.jti) {
      const supabaseClient = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      )

      const { data: revokedToken } = await supabaseClient
        .from('revoked_tokens')
        .select('jti, revoked_at, reason')
        .eq('jti', payload.jti)
        .single()

      if (revokedToken) {
        return new Response(
          JSON.stringify({ 
            error: 'Token has been revoked', 
            valid: false,
            revoked_at: revokedToken.revoked_at,
            reason: revokedToken.reason
          }), 
          { 
            status: 401, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }
    }

    // Token is valid
    return new Response(
      JSON.stringify({ 
        valid: true,
        claims: {
          sub: payload.sub,
          email: payload.email,
          role: payload.role,
          exp: payload.exp,
          exp_iso: new Date(payload.exp * 1000).toISOString(),
          jti: payload.jti
        }
      }), 
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('Validation error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', valid: false }), 
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})