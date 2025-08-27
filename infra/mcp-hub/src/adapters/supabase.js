import fetch from "node-fetch";

const REQUIRED = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE"];

export async function handleSupabase(tool, args) {
  ensureEnv();

  if (tool === "sql.select") {
    // Read-only example via PostgREST RPC or SQL via Edge Function proxy you own.
    const { table, select = "*", limit = 100, filter = {} } = args ?? {};
    if (!table) return { error: "table is required" };
    const url = new URL(`${process.env.SUPABASE_URL}/rest/v1/${encodeURIComponent(table)}`);
    url.searchParams.set("select", select);
    url.searchParams.set("limit", String(limit));
    for (const [k,v] of Object.entries(filter)) url.searchParams.set(k, v);
    const res = await fetch(url.toString(), {
      headers: {
        apikey: process.env.SUPABASE_SERVICE_ROLE,
        Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE}`
      }
    });
    if (!res.ok) return { error: `supabase ${res.status}`, details: await safeText(res) };
    return await res.json();
  }

  return { error: `unsupported tool: ${tool}` };
}

function ensureEnv() {
  const missing = REQUIRED.filter(k => !process.env[k]);
  if (missing.length) throw new Error(`Supabase adapter not configured: ${missing.join(", ")}`);
}

async function safeText(res) { try { return await res.text(); } catch { return ""; } }
