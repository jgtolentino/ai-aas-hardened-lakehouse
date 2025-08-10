import { createClient } from "@supabase/supabase-js";

const url = process.env.SUPABASE_URL!;
const key = process.env.SUPABASE_SERVICE_KEY!;
const supa = (url && key) ? createClient(url, key) : null;

export async function upsertRun(flowId: string, browser: string, status: string, logs: any[]) {
  if (!supa) {
    console.warn("Supabase client not configured - skipping result upload");
    return;
  }
  
  try {
    const { data, error } = await supa.from("qa_runs").insert({
      flow_id: flowId, 
      browser, 
      status, 
      logs, 
      started_at: new Date().toISOString()
    });
    
    if (error) {
      console.error("Failed to insert QA run:", error);
    }
  } catch (e) {
    console.error("Error uploading to Supabase:", e);
  }
}