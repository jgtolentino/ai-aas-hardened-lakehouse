// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type ConfRow = { run_date: string; actual_brand: string; predicted_brand: string; n: number };
type Summary = {
  brand_missing_pct: number; 
  price_missing_pct: number;
  demographics_missing_pct: number; 
  low_confidence_pct: number;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SRK = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CLICKUP_TOKEN = Deno.env.get("CLICKUP_TOKEN");
const CLICKUP_LIST_ID = Deno.env.get("CLICKUP_LIST_ID");
const GITHUB_TOKEN = Deno.env.get("GITHUB_TOKEN");
const GITHUB_REPO = Deno.env.get("GITHUB_REPO");

const sb = createClient(SUPABASE_URL, SRK, { auth: { persistSession: false } });

async function runChecks() {
  // 1) Fetch quality summary
  const { data: sumData, error: e1 } = await sb.rpc("suqi_get_quality_summary", {});
  if (e1) throw e1;
  const s: Summary = sumData;

  // 2) Fetch per-brand confusion today
  const { data: confData, error: e2 } = await sb.rpc("suqi_get_confusion_today", {});
  if (e2) throw e2;
  const rows: ConfRow[] = confData || [];

  // 3) Get macro F1 score
  const { data: f1Data, error: e3 } = await sb.rpc("get_macro_f1", {});
  if (e3) throw e3;
  const macroF1 = f1Data as number;

  // Thresholds
  const T_BRAND_MISS = 20.0;   // %
  const T_PRICE_MISS = 20.0;   // %
  const T_DEMO_MISS  = 50.0;   // %
  const T_LOWCONF    = 30.0;   // %
  const T_MACRO_F1   = 0.70;   // F1 score
  
  const TOP_CONFUSIONS = rows
    .filter(r => r.actual_brand !== r.predicted_brand && r.actual_brand !== 'UNK' && r.predicted_brand !== 'UNK')
    .sort((a,b) => b.n - a.n)
    .slice(0, 5);

  const issues: Array<{key:string; severity:'low'|'med'|'high'|'crit'; title:string; body:string}> = [];
  const today = new Date().toISOString().slice(0,10);
  
  function pushIncident(keySuffix:string, sev:any, title:string, body:string) {
    issues.push({ key: `${keySuffix}:${today}`, severity: sev, title, body });
  }

  // Check thresholds
  if (s.brand_missing_pct >= T_BRAND_MISS) {
    pushIncident("BRAND_MISSING", "crit",
      `Brand coverage degraded (${s.brand_missing_pct}%)`,
      `Brand missing percentage is ${s.brand_missing_pct}%. Target: <${T_BRAND_MISS}%.\n\nAction needed:\n- Review unrecognized brands\n- Update STT dictionary\n- Check detection methods\n\nSummary: ${JSON.stringify(s, null, 2)}`
    );
  }
  
  if (s.price_missing_pct >= T_PRICE_MISS) {
    pushIncident("PRICE_MISSING", "high",
      `Price capture degraded (${s.price_missing_pct}%)`,
      `Price missing percentage is ${s.price_missing_pct}%. Target: <${T_PRICE_MISS}%.\n\nAction needed:\n- Check edge device price detection\n- Update catalog pricing\n- Review OCR accuracy`
    );
  }
  
  if (s.demographics_missing_pct >= T_DEMO_MISS) {
    pushIncident("DEMO_MISSING", "med",
      `Demographics coverage low (${s.demographics_missing_pct}%)`,
      `Demographics missing: ${s.demographics_missing_pct}%. Target: <${T_DEMO_MISS}%.\n\nConsider:\n- Enabling demographics inference on more stores\n- Checking camera angles`
    );
  }
  
  if (s.low_confidence_pct >= T_LOWCONF) {
    pushIncident("LOW_CONF", "med",
      `Low-confidence items elevated (${s.low_confidence_pct}%)`,
      `Items with confidence <0.6: ${s.low_confidence_pct}%. Target: <${T_LOWCONF}%.\n\nReview:\n- Detection method distribution\n- Calibration weights\n- Environmental factors`
    );
  }
  
  if (macroF1 < T_MACRO_F1) {
    pushIncident("LOW_MACRO_F1", "crit",
      `Brand macro F1 score dropped (${macroF1.toFixed(3)})`,
      `Macro F1: ${macroF1.toFixed(3)}. Target: ≥${T_MACRO_F1}.\n\nCritical: Overall brand detection accuracy is below acceptable threshold.\n\nImmediate actions:\n- Review confusion matrix\n- Update brand mappings\n- Field audit high-error stores`
    );
  }
  
  if (TOP_CONFUSIONS.length) {
    const lines = TOP_CONFUSIONS.map(r => `- ${r.actual_brand} → ${r.predicted_brand}: ${r.n} times`).join('\n');
    pushIncident("CONFUSION_TOP", "med",
      `Top brand confusions detected`,
      `Most frequent mislabels today:\n${lines}\n\nActions:\n- Add variant mappings for confused pairs\n- Update STT dictionary\n- Review similar product placement`
    );
  }

  return issues;
}

async function ensureIncidentLogged(inc: any) {
  const { data, error } = await sb
    .from("suqi_incident_log")
    .select("id, clickup_task_id, github_issue_number")
    .eq("incident_key", inc.key)
    .maybeSingle();
  if (error) throw error;
  return data;
}

async function logIncident(inc: any, clickupId?: string, ghNumber?: number) {
  const { error } = await sb.from("suqi_incident_log").upsert({
    incident_key: inc.key,
    severity: inc.severity,
    summary: inc.title,
    details: { body: inc.body },
    clickup_task_id: clickupId ?? null,
    github_issue_number: ghNumber ?? null
  }, { onConflict: "incident_key" });
  if (error) throw error;
}

async function createClickUp(inc: any): Promise<string | undefined> {
  if (!CLICKUP_TOKEN || !CLICKUP_LIST_ID) return;
  
  const priority = inc.severity === 'crit' ? 1 : 
                   inc.severity === 'high' ? 2 : 
                   inc.severity === 'med' ? 3 : 4;
  
  const res = await fetch(`https://api.clickup.com/api/v2/list/${CLICKUP_LIST_ID}/task`, {
    method: "POST",
    headers: { 
      "Authorization": CLICKUP_TOKEN, 
      "Content-Type": "application/json" 
    },
    body: JSON.stringify({
      name: `[${inc.severity.toUpperCase()}] ${inc.title}`,
      description: inc.body,
      status: "open",
      priority: priority,
      tags: ["suqi", "quality", "automated"],
      due_date: Date.now() + (inc.severity === 'crit' ? 4 : 24) * 3600 * 1000
    })
  });
  
  if (!res.ok) {
    const errorText = await res.text();
    console.error(`ClickUp error: ${res.status} ${errorText}`);
    return undefined;
  }
  
  const j = await res.json();
  return j.id;
}

async function createGitHub(inc: any): Promise<number | undefined> {
  if (!GITHUB_TOKEN || !GITHUB_REPO) return;
  
  const res = await fetch(`https://api.github.com/repos/${GITHUB_REPO}/issues`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${GITHUB_TOKEN}`,
      "Accept": "application/vnd.github+json"
    },
    body: JSON.stringify({
      title: `[${inc.severity.toUpperCase()}] ${inc.title}`,
      body: `${inc.body}\n\n---\n_Automated by Scout Edge Quality Sentinel_\n_Incident Key: ${inc.key}_`,
      labels: ["suqi", "quality", "automated", inc.severity]
    })
  });
  
  if (!res.ok) {
    const errorText = await res.text();
    console.error(`GitHub error: ${res.status} ${errorText}`);
    return undefined;
  }
  
  const j = await res.json();
  return j.number;
}

serve(async (req) => {
  try {
    // Optional: require a secret header
    const auth = req.headers.get("x-sentinel-key");
    const expectedKey = Deno.env.get("SENTINEL_KEY");
    
    if (expectedKey && (!auth || auth !== expectedKey)) {
      return new Response("Unauthorized", { status: 401 });
    }

    const issues = await runChecks();
    const results: any[] = [];
    
    for (const inc of issues) {
      const existing = await ensureIncidentLogged(inc);
      let clickupId = existing?.clickup_task_id;
      let ghNumber = existing?.github_issue_number;

      // Create only if new
      if (!clickupId) clickupId = await createClickUp(inc);
      if (!ghNumber) ghNumber = await createGitHub(inc);
      
      await logIncident(inc, clickupId, ghNumber ?? undefined);
      results.push({ 
        key: inc.key, 
        severity: inc.severity,
        clickupId, 
        ghNumber,
        isNew: !existing
      });
    }
    
    return new Response(
      JSON.stringify({ 
        ok: true, 
        timestamp: new Date().toISOString(),
        issues_found: issues.length,
        results: results 
      }), 
      { headers: { "content-type": "application/json" }}
    );
  } catch (e) {
    console.error("Quality Sentinel error:", e);
    return new Response(
      JSON.stringify({ error: String(e) }), 
      { status: 500, headers: { "content-type": "application/json" }}
    );
  }
});