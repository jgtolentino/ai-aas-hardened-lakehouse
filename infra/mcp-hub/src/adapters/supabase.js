import fetch from "node-fetch";
import { withRetry, trackCost } from "@scout/ai-cookbook";

const REQUIRED = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE"];

export async function handleSupabase(tool, args) {
  ensureEnv();

  if (tool === "sql.select") {
    // Read-only example via PostgREST RPC or SQL via Edge Function proxy you own.
    const { table, select = "*", limit = 100, filter = {} } = args ?? {};
    if (!table) return { error: "table is required" };
    // Handle schema.table format properly
    const [schema, tableName] = table.includes('.') ? table.split('.') : ['public', table];
    const url = new URL(`${process.env.SUPABASE_URL}/rest/v1/${encodeURIComponent(tableName)}`);
    url.searchParams.set("select", select);
    url.searchParams.set("limit", String(limit));
    for (const [k,v] of Object.entries(filter)) url.searchParams.set(k, v);
    
    // Apply retry logic with cost tracking
    return await withRetry(async () => {
      const startTime = Date.now();
      const res = await fetch(url.toString(), {
        headers: {
          apikey: process.env.SUPABASE_SERVICE_ROLE,
          Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE}`
        }
      });
      
      // Track operation cost/performance
      await trackCost({
        operation: 'supabase.sql.select',
        provider: 'supabase',
        tokens: limit, // Approximate based on row limit
        duration: Date.now() - startTime,
        success: res.ok
      });
      
      if (!res.ok) {
        const errorText = await safeText(res);
        throw new Error(`Supabase ${res.status}: ${errorText}`);
      }
      return await res.json();
    }, {
      retries: 3,
      minTimeout: 1000,
      factor: 2,
      onFailedAttempt: (error) => {
        console.warn(`🔄 Supabase request failed, retrying... (${error.attemptNumber}/${error.retriesLeft + error.attemptNumber})`);
      }
    });
  }

  return { error: `unsupported tool: ${tool}` };
}

function ensureEnv() {
  const missing = REQUIRED.filter(k => !process.env[k]);
  if (missing.length) throw new Error(`Supabase adapter not configured: ${missing.join(", ")}`);
}

async function safeText(res) { try { return await res.text(); } catch { return ""; } }
