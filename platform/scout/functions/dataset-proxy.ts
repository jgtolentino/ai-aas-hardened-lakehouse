/**
 * Scout Dataset Proxy Edge Function
 * 
 * Provides secure access to Scout datasets via signed URLs
 * Features:
 * - Authentication validation
 * - Rate limiting
 * - Audit logging
 * - TTL-based signed URLs
 * 
 * Deploy: supabase functions deploy dataset-proxy
 * Usage: GET /functions/v1/dataset-proxy?dataset=gold/txn_daily&ttl=3600
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

// Types
interface DatasetRequest {
  dataset: string;
  ttl?: number;
  format?: 'csv' | 'parquet';
}

interface DatasetResponse {
  signed_url: string;
  expires_at: string;
  dataset_info: {
    id: string;
    row_count: number;
    size_bytes: number;
    last_updated: string;
    description?: string;
  };
}

interface ErrorResponse {
  error: string;
  code?: string;
  details?: any;
}

// Configuration
const BUCKET = "sample";
const BASE_PATH = "scout/v1";
const DEFAULT_TTL = 3600; // 1 hour
const MAX_TTL = 86400; // 24 hours
const MIN_TTL = 300; // 5 minutes

// Rate limiting store (in-memory, resets on function restart)
const rateLimitStore = new Map<string, { count: number; resetTime: number }>();
const RATE_LIMIT_WINDOW = 60 * 1000; // 1 minute
const RATE_LIMIT_MAX_REQUESTS = 10;

/**
 * Simple in-memory rate limiting
 */
function checkRateLimit(identifier: string): { allowed: boolean; remaining: number } {
  const now = Date.now();
  const entry = rateLimitStore.get(identifier);
  
  if (!entry || now > entry.resetTime) {
    rateLimitStore.set(identifier, {
      count: 1,
      resetTime: now + RATE_LIMIT_WINDOW
    });
    return { allowed: true, remaining: RATE_LIMIT_MAX_REQUESTS - 1 };
  }
  
  if (entry.count >= RATE_LIMIT_MAX_REQUESTS) {
    return { allowed: false, remaining: 0 };
  }
  
  entry.count++;
  return { allowed: true, remaining: RATE_LIMIT_MAX_REQUESTS - entry.count };
}

/**
 * Validate dataset ID format
 */
function validateDatasetId(datasetId: string): boolean {
  // Only allow alphanumeric, hyphens, underscores, and forward slashes
  const pattern = /^[a-zA-Z0-9_\-\/]+$/;
  return pattern.test(datasetId) && datasetId.length <= 100;
}

/**
 * Get user identifier for rate limiting
 */
function getUserIdentifier(req: Request): string {
  const authHeader = req.headers.get('authorization');
  if (authHeader) {
    // Extract user ID from JWT if available
    try {
      const token = authHeader.replace('Bearer ', '');
      const payload = JSON.parse(atob(token.split('.')[1]));
      return payload.sub || 'authenticated_user';
    } catch {
      return 'authenticated_user';
    }
  }
  
  // Fallback to IP-based rate limiting for anonymous users
  const forwardedFor = req.headers.get('x-forwarded-for');
  const realIP = req.headers.get('x-real-ip');
  return forwardedFor || realIP || 'anonymous';
}

/**
 * Log dataset access for auditing
 */
async function logAccess(
  supabase: any,
  datasetId: string,
  userIdentifier: string,
  success: boolean,
  error?: string
) {
  try {
    await supabase
      .from('dataset_access_logs')
      .insert({
        dataset_id: datasetId,
        user_identifier: userIdentifier,
        success,
        error_message: error,
        accessed_at: new Date().toISOString(),
        user_agent: undefined // Could be added if needed
      });
  } catch (logError) {
    console.error('Failed to log dataset access:', logError);
  }
}

/**
 * Main request handler
 */
serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  // Only allow GET requests
  if (req.method !== 'GET') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' } as ErrorResponse),
      { 
        status: 405, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  try {
    const url = new URL(req.url);
    const datasetId = url.searchParams.get('dataset');
    const ttlParam = url.searchParams.get('ttl');
    const format = url.searchParams.get('format') as 'csv' | 'parquet' || 'csv';

    // Validate required parameters
    if (!datasetId) {
      return new Response(
        JSON.stringify({ 
          error: 'Missing required parameter: dataset',
          code: 'MISSING_PARAMETER'
        } as ErrorResponse),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Validate dataset ID format
    if (!validateDatasetId(datasetId)) {
      return new Response(
        JSON.stringify({ 
          error: 'Invalid dataset ID format',
          code: 'INVALID_DATASET_ID'
        } as ErrorResponse),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Parse and validate TTL
    let ttl = DEFAULT_TTL;
    if (ttlParam) {
      ttl = parseInt(ttlParam, 10);
      if (isNaN(ttl) || ttl < MIN_TTL || ttl > MAX_TTL) {
        return new Response(
          JSON.stringify({ 
            error: `TTL must be between ${MIN_TTL} and ${MAX_TTL} seconds`,
            code: 'INVALID_TTL'
          } as ErrorResponse),
          { 
            status: 400, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        );
      }
    }

    // Rate limiting
    const userIdentifier = getUserIdentifier(req);
    const rateLimit = checkRateLimit(userIdentifier);
    
    if (!rateLimit.allowed) {
      await logAccess(supabase, datasetId, userIdentifier, false, 'Rate limit exceeded');
      
      return new Response(
        JSON.stringify({ 
          error: 'Rate limit exceeded',
          code: 'RATE_LIMITED'
        } as ErrorResponse),
        { 
          status: 429, 
          headers: { 
            ...corsHeaders, 
            'Content-Type': 'application/json',
            'X-RateLimit-Remaining': '0',
            'X-RateLimit-Reset': String(Math.ceil(Date.now() / 1000) + 60)
          }
        }
      );
    }

    // Fetch manifest to validate dataset exists
    const { data: manifestData, error: manifestError } = await supabase.storage
      .from(BUCKET)
      .download(`${BASE_PATH}/manifests/latest.json`);

    if (manifestError) {
      await logAccess(supabase, datasetId, userIdentifier, false, 'Manifest fetch failed');
      throw new Error(`Failed to fetch manifest: ${manifestError.message}`);
    }

    const manifest = JSON.parse(await manifestData.text());
    const dataset = manifest.datasets[datasetId];

    if (!dataset) {
      await logAccess(supabase, datasetId, userIdentifier, false, 'Dataset not found');
      
      return new Response(
        JSON.stringify({ 
          error: `Dataset '${datasetId}' not found`,
          code: 'DATASET_NOT_FOUND'
        } as ErrorResponse),
        { 
          status: 404, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Determine file path based on format
    let filePath: string;
    if (format === 'parquet' && dataset.latest_parquet) {
      filePath = dataset.latest_parquet;
    } else {
      filePath = dataset.latest_csv;
    }

    // Create signed URL
    const { data: signedUrlData, error: signedUrlError } = await supabase.storage
      .from(BUCKET)
      .createSignedUrl(filePath.replace(/^\//, ''), ttl);

    if (signedUrlError) {
      await logAccess(supabase, datasetId, userIdentifier, false, 'Signed URL creation failed');
      throw new Error(`Failed to create signed URL: ${signedUrlError.message}`);
    }

    // Log successful access
    await logAccess(supabase, datasetId, userIdentifier, true);

    const response: DatasetResponse = {
      signed_url: signedUrlData.signedUrl,
      expires_at: new Date(Date.now() + ttl * 1000).toISOString(),
      dataset_info: {
        id: datasetId,
        row_count: dataset.row_count,
        size_bytes: dataset.size_bytes,
        last_updated: dataset.last_modified,
        description: dataset.description
      }
    };

    return new Response(
      JSON.stringify(response),
      { 
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json',
          'X-RateLimit-Remaining': String(rateLimit.remaining),
          'Cache-Control': 'no-cache, no-store, must-revalidate'
        }
      }
    );

  } catch (error) {
    console.error('Dataset proxy error:', error);
    
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        code: 'INTERNAL_ERROR',
        details: error.message
      } as ErrorResponse),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }
});