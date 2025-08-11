import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { sign, verify } from 'https://deno.land/x/djwt@v3.0.1/mod.ts';

/**
 * Superset JWT Proxy for Lovable App Integration
 * 
 * This Edge Function creates a secure proxy between Lovable app and Apache Superset,
 * handling JWT authentication and dashboard embedding.
 */

interface SupersetConfig {
  url: string;
  username: string;
  password: string;
  jwtSecret: string;
  dbId: number;
}

interface DashboardEmbedRequest {
  dashboardId: string;
  filters?: Record<string, any>;
  guestToken?: string;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('LOVABLE_APP_URL') || 'https://*.lovable.app',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-superset-dashboard',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

const supersetConfig: SupersetConfig = {
  url: Deno.env.get('SUPERSET_URL') || 'http://localhost:8088',
  username: Deno.env.get('SUPERSET_USERNAME') || 'admin',
  password: Deno.env.get('SUPERSET_PASSWORD') || 'admin',
  jwtSecret: Deno.env.get('SUPERSET_JWT_SECRET') || 'your-secret-key',
  dbId: parseInt(Deno.env.get('SUPERSET_DB_ID') || '1'),
};

/**
 * Authenticate with Superset and get access token
 */
async function getSupersetToken(): Promise<string> {
  const loginResponse = await fetch(`${supersetConfig.url}/api/v1/security/login`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      username: supersetConfig.username,
      password: supersetConfig.password,
      provider: 'db',
      refresh: true,
    }),
  });

  if (!loginResponse.ok) {
    throw new Error(`Superset login failed: ${loginResponse.statusText}`);
  }

  const loginData = await loginResponse.json();
  return loginData.access_token;
}

/**
 * Create a guest token for dashboard embedding
 */
async function createGuestToken(dashboardId: string, filters: Record<string, any> = {}): Promise<string> {
  const accessToken = await getSupersetToken();
  
  const guestTokenPayload = {
    user: {
      username: 'guest',
      first_name: 'Guest',
      last_name: 'User',
    },
    resources: [{
      type: 'dashboard',
      id: dashboardId,
    }],
    rls: [], // Row Level Security rules
    exp: Math.floor(Date.now() / 1000) + (60 * 60), // 1 hour expiry
  };

  const guestTokenResponse = await fetch(`${supersetConfig.url}/api/v1/security/guest_token/`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`,
    },
    body: JSON.stringify(guestTokenPayload),
  });

  if (!guestTokenResponse.ok) {
    throw new Error(`Guest token creation failed: ${guestTokenResponse.statusText}`);
  }

  const guestTokenData = await guestTokenResponse.json();
  return guestTokenData.token;
}

/**
 * Generate embedded dashboard URL with authentication
 */
async function getEmbeddedDashboardUrl(dashboardId: string, filters: Record<string, any> = {}): Promise<string> {
  try {
    const guestToken = await createGuestToken(dashboardId, filters);
    
    const embedParams = new URLSearchParams({
      standalone: '3', // Standalone mode for embedding
      height: '700',
      guest_token: guestToken,
    });

    // Add filters if provided
    if (Object.keys(filters).length > 0) {
      embedParams.append('preselect_filters', JSON.stringify(filters));
    }

    return `${supersetConfig.url}/superset/dashboard/${dashboardId}/embedded?${embedParams.toString()}`;
  } catch (error) {
    console.error('Error creating embedded dashboard URL:', error);
    throw error;
  }
}

/**
 * Validate Lovable app authentication
 */
async function validateLovableAuth(request: Request): Promise<boolean> {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return false;
  }

  try {
    const token = authHeader.substring(7);
    const lovableSecret = Deno.env.get('LOVABLE_JWT_SECRET');
    
    if (!lovableSecret) {
      console.error('LOVABLE_JWT_SECRET not configured');
      return false;
    }

    const payload = await verify(token, lovableSecret, 'HS256');
    return payload && payload.iss === 'lovable-app';
  } catch (error) {
    console.error('Token validation failed:', error);
    return false;
  }
}

/**
 * Proxy Superset API requests with authentication
 */
async function proxySuperset(request: Request, path: string): Promise<Response> {
  const accessToken = await getSupersetToken();
  
  const proxyUrl = `${supersetConfig.url}${path}`;
  const proxyHeaders = new Headers();
  
  // Copy relevant headers
  request.headers.forEach((value, key) => {
    if (!key.toLowerCase().startsWith('host') && 
        !key.toLowerCase().startsWith('origin')) {
      proxyHeaders.set(key, value);
    }
  });
  
  // Add Superset authentication
  proxyHeaders.set('Authorization', `Bearer ${accessToken}`);
  
  const proxyResponse = await fetch(proxyUrl, {
    method: request.method,
    headers: proxyHeaders,
    body: request.method !== 'GET' ? await request.blob() : undefined,
  });

  // Copy response headers and add CORS
  const responseHeaders = new Headers(corsHeaders);
  proxyResponse.headers.forEach((value, key) => {
    if (!key.toLowerCase().startsWith('access-control')) {
      responseHeaders.set(key, value);
    }
  });

  return new Response(proxyResponse.body, {
    status: proxyResponse.status,
    statusText: proxyResponse.statusText,
    headers: responseHeaders,
  });
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const { pathname } = url;

    // Validate authentication from Lovable app
    const isAuthenticated = await validateLovableAuth(req);
    if (!isAuthenticated) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Route: Get embedded dashboard URL
    if (pathname === '/embed-dashboard') {
      const dashboardId = url.searchParams.get('dashboard_id');
      if (!dashboardId) {
        return new Response(JSON.stringify({ error: 'dashboard_id parameter required' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // Parse filters from query params
      const filters: Record<string, any> = {};
      url.searchParams.forEach((value, key) => {
        if (key.startsWith('filter_')) {
          const filterName = key.substring(7); // Remove 'filter_' prefix
          filters[filterName] = value;
        }
      });

      const embedUrl = await getEmbeddedDashboardUrl(dashboardId, filters);
      
      return new Response(JSON.stringify({ 
        embed_url: embedUrl,
        expires_in: 3600,
        dashboard_id: dashboardId,
        filters: filters,
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Route: List available dashboards
    if (pathname === '/dashboards') {
      return await proxySuperset(req, '/api/v1/dashboard/');
    }

    // Route: Get dashboard metadata
    if (pathname.startsWith('/dashboard/')) {
      const dashboardId = pathname.split('/')[2];
      return await proxySuperset(req, `/api/v1/dashboard/${dashboardId}`);
    }

    // Route: Proxy general Superset API calls
    if (pathname.startsWith('/api/')) {
      return await proxySuperset(req, pathname + url.search);
    }

    // Route: Health check
    if (pathname === '/health') {
      return new Response(JSON.stringify({ 
        status: 'healthy',
        superset_url: supersetConfig.url,
        timestamp: new Date().toISOString(),
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({ error: 'Route not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error('Superset JWT Proxy Error:', error);
    
    return new Response(JSON.stringify({ 
      error: 'Internal server error',
      message: error.message,
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});