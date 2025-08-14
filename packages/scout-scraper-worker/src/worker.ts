const PG_REST = process.env.PG_REST!;
const ISKO_URL = process.env.ISKO_URL!;
const SUPABASE_ANON = process.env.SUPABASE_ANON!;

async function rpc(fn: string, args: any = {}) {
  const r = await fetch(`${PG_REST}/rpc/${fn}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(args),
  });
  if (!r.ok) throw new Error(`${fn} ${r.status} ${await r.text()}`);
  return r.json();
}

async function once(worker: string) {
  const jobs = await rpc("get_next_job", { p_worker: worker });
  const job = jobs?.[0];
  if (!job) return false;

  const { job_id, url } = job;
  let http_status = 0, etag = null, last_modified = null, content_sha256 = null;
  let parse_status = "error", parse_note = "fetch-failed", discovered: string[] = [];

  try {
    const resp = await fetch(ISKO_URL, {
      method: "POST",
      headers: { "content-type":"application/json", "Authorization": `Bearer ${SUPABASE_ANON}` },
      body: JSON.stringify({ url })
    });
    http_status = resp.status;
    const text = await resp.text();
    // lightweight hash
    const enc = new TextEncoder();
    const buf = await crypto.subtle.digest("SHA-256", enc.encode(text));
    content_sha256 = Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2,'0')).join('');

    let parsed: any = {};
    try { parsed = JSON.parse(text); } catch {}
    discovered = Array.isArray(parsed.discovered) ? parsed.discovered : [];
    parse_status = resp.ok ? "ok" : "error";
    parse_note = parsed.note || `status:${resp.status}`;
  } catch (e:any) {
    parse_status = "error"; parse_note = String(e?.message || e).slice(0,200);
  } finally {
    await rpc("report_job_result", {
      p_job_id: job_id,
      p_http_status: http_status,
      p_etag: etag,
      p_last_modified: last_modified,
      p_content_sha256: content_sha256,
      p_parse_status: parse_status,
      p_parse_note: parse_note,
      p_discovered: discovered
    });
  }
  return true;
}

(async () => {
  const worker = `w-${Math.random().toString(16).slice(2,6)}`;
  for (;;) {
    const did = await once(worker);
    if (!did) await new Promise(r => setTimeout(r, 800));
  }
})();
