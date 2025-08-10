import { createClient } from "@supabase/supabase-js";
const url = process.env.SUPABASE_URL\!;
const key = process.env.SUPABASE_SERVICE_KEY\!;
const supa = (url && key) ? createClient(url, key) : null;

export async function upsertRun(flowId: string, browser: string, status: string, logs:any[]) {
  if (\!supa) return;
  await supa.from("qa_runs").insert({
    flow_id: flowId, browser, status, logs, started_at: new Date().toISOString()
  });
}
EOF < /dev/null