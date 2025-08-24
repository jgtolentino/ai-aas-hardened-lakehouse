/**
 * Scout v5.2 - Real-time Transaction Ingestion
 * Accepts transactions from edge devices and streams to Bronze layer
 * Features: Idempotency, deduplication, proper error handling
 */

import { serve } from "https://deno.land/std/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface TransactionItem {
  product_id: string;
  product_name: string;
  brand?: string;
  category?: string;
  qty: number;
  unit_price: number;
  line_amount: number;
  discount?: number;
}

interface TransactionPayload {
  transaction_id: string;
  store_id: string;
  ts: string;
  total_amount: number;
  net_amount?: number;
  customer_id?: string;
  payment_method?: string;
  items: TransactionItem[];
  metadata?: Record<string, any>;
}

interface IngestResponse {
  ok: boolean;
  id?: string;
  error?: string;
  duplicateDetected?: boolean;
}

serve(async (req: Request): Promise<Response> => {
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { 
      status: 200, 
      headers: corsHeaders 
    });
  }

  // Only accept POST requests
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ ok: false, error: 'Method not allowed' }),
      { 
        status: 405, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }

  try {
    // Initialize Supabase client
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    );

    // Parse and validate payload
    const payload: TransactionPayload = await req.json();
    
    // Basic validation
    if (!payload.transaction_id || !payload.store_id || !payload.items?.length) {
      return new Response(
        JSON.stringify({ 
          ok: false, 
          error: 'Missing required fields: transaction_id, store_id, or items' 
        }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Generate idempotency hash for deduplication
    const payloadString = JSON.stringify({
      transaction_id: payload.transaction_id,
      store_id: payload.store_id,
      ts: payload.ts,
      items: payload.items
    });

    // Create hash for deduplication (using Web Crypto API)
    const encoder = new TextEncoder();
    const data = encoder.encode(payloadString);
    const hashBuffer = await crypto.subtle.digest('SHA-256', data);
    const hashArray = new Uint8Array(hashBuffer);
    const eventHash = Array.from(hashArray)
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');

    // Insert into bronze_events with deduplication
    const { data: event, error } = await supabase
      .from("bronze_events")
      .insert({
        event_type: "transaction.v1",
        event_data: payload,
        event_hash: eventHash,
        source_system: req.headers.get('x-source-system') || 'unknown',
        ingested_at: new Date().toISOString(),
        metadata: {
          ip_address: req.headers.get('x-forwarded-for') || req.headers.get('cf-connecting-ip'),
          user_agent: req.headers.get('user-agent'),
          content_length: req.headers.get('content-length')
        }
      })
      .select('event_id')
      .single();

    if (error) {
      // Check if this is a duplicate (unique constraint violation)
      if (error.code === '23505' && error.message?.includes('event_hash')) {
        console.log(`Duplicate transaction detected: ${payload.transaction_id}`);
        return new Response(
          JSON.stringify({ 
            ok: true, 
            duplicateDetected: true,
            message: 'Transaction already processed'
          }),
          { 
            status: 200, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        );
      }

      console.error('Database error:', error);
      return new Response(
        JSON.stringify({ 
          ok: false, 
          error: 'Database error during ingestion',
          details: error.message
        }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Success response
    const response: IngestResponse = {
      ok: true,
      id: event.event_id
    };

    console.log(`Successfully ingested transaction: ${payload.transaction_id} -> event: ${event.event_id}`);

    return new Response(
      JSON.stringify(response),
      { 
        status: 201, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );

  } catch (error) {
    console.error('Ingestion error:', error);
    
    return new Response(
      JSON.stringify({ 
        ok: false, 
        error: 'Failed to process transaction',
        details: error instanceof Error ? error.message : 'Unknown error'
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }
});