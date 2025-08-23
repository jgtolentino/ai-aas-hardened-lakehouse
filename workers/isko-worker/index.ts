import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession:false } });

async function claimJob() {
  // Claim oldest high-priority queued job atomically
  const { data, error } = await sb
    .from("sku_jobs")
    .select("*")
    .eq("status","queued")
    .lte("scheduled_for", new Date().toISOString())
    .order("priority", { ascending: true })
    .order("created_at", { ascending: true })
    .limit(1);
  if (error || !data?.length) return null;

  const job = data[0];
  const upd = await sb.from("sku_jobs")
    .update({ status: "running", started_at: new Date().toISOString(), attempts: (job.attempts ?? 0) + 1 })
    .eq("id", job.id)
    .eq("status","queued"); // optimistic lock
  if (upd.error || upd.count === 0) return null;
  return job;
}

async function saveSummary(job: any, items: any[]) {
  for (const it of items) {
    await sb.from("sku_summary").insert({
      brand: it.brand, sku_name: it.sku_name, category: it.category ?? null,
      upc: it.upc ?? null, size: it.size ?? null, pack: it.pack ?? null,
      price_min: it.price_min ?? null, price_max: it.price_max ?? null,
      currency: it.currency ?? "PHP", image_url: it.image_url ?? null, source_url: it.source_url ?? null,
      meta: it.meta ?? {}, job_id: job.id
    });
  }
}

async function finish(jobId: string, ok: boolean, err?: string) {
  await sb.from("sku_jobs").update({
    status: ok ? "success" : (err?.includes("429") ? "queued" : "failed"),
    finished_at: new Date().toISOString(),
    last_error: ok ? null : err?.slice(0, 4000) ?? "unknown"
  }).eq("id", jobId);

  await sb.rpc("push_feed", {
    p_severity: ok ? "success" : "warn",
    p_source: "isko",
    p_title: ok ? "Isko scrape completed" : "Isko scrape failed",
    p_desc: ok ? "Results saved to deep_research.sku_summary" : (err ?? "Error"),
    p_payload: { job_id: jobId },
    p_related: [],
  });
}

async function scrape(job: any) {
  // Replace with real scraping. Here: mock 3 SKUs per brand.
  const brand = job.task_payload?.brand ?? "Unknown";
  const items = Array.from({length:3}).map((_,i)=>({
    brand, sku_name: `${brand} SKU ${i+1}`, category: "Snacks",
    price_min: 10 + i, price_max: 15 + i, source_url: "https://example.com/sku",
    image_url: "https://picsum.photos/seed/"+encodeURIComponent(brand+i)+"/300/300",
    meta: { region: job.task_payload?.region ?? "PH", seed: job.task_payload?.seed ?? "auto" }
  }));
  return items;
}

export async function runOnce() {
  const job = await claimJob();
  if (!job) return { claimed: false };
  try {
    const items = await scrape(job);
    await saveSummary(job, items);
    await finish(job.id, true);
    return { claimed: true, saved: items.length };
  } catch (e) {
    await finish(job.id, false, (e as Error).message);
    return { claimed: true, error: (e as Error).message };
  }
}

// If executed directly
if (import.meta.main) {
  const res = await runOnce();
  console.log(JSON.stringify(res));
}