import "jsr:@supabase/functions-js/edge-runtime.ts";

function cors(res: Response) {
  const h = new Headers(res.headers);
  h.set("Access-Control-Allow-Origin", "*");
  h.set("Access-Control-Allow-Headers", "authorization, x-client-info, apikey, content-type");
  h.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  return new Response(res.body, { status: res.status, headers: h });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return cors(new Response(null, { status: 204 }));

  // AuthN: verify Supabase JWT if required (leave permissive for now).
  const url = new URL(req.url);
  const op = url.searchParams.get("op") || "health";

  if (op === "health") {
    return cors(new Response(JSON.stringify({ ok: true, ts: new Date().toISOString() }), {
      headers: { "content-type": "application/json" }
    }));
  }

  // Placeholder for future brokering (e.g., PowerBI embed token, signed export)
  return cors(new Response(JSON.stringify({ error: "op_not_implemented", op }), { status: 400,
    headers: { "content-type": "application/json" }}));
});
