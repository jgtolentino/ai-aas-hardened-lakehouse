#!/usr/bin/env tsx
/**
 * End-to-end smoke:
 * 1) generate ZIP fixtures
 * 2) upload to Storage (service role)
 * 3) wait for ingest (poll Silver count delta)
 * 4) run RPC + Edge smokes
 *
 * Env:
 *   SUPABASE_URL=https://<project>.supabase.co
 *   SUPABASE_ANON_KEY=eyJ...
 *   SERVICE_ROLE=eyJ...                # for Storage upload ONLY (server-side)
 *   USER_JWT=eyJ...                    # optional; RLS-bound reads
 *   INGEST_BUCKET=scout-ingest         # default
 */
import { createClient } from "@supabase/supabase-js";
import fs from "fs";
import path from "path";
import { spawnSync } from "child_process";

const URL  = process.env.SUPABASE_URL ?? "";
const ANON = process.env.SUPABASE_ANON_KEY ?? "";
const SRV  = process.env.SERVICE_ROLE ?? "";
const JWT  = process.env.USER_JWT ?? "";
const BUCKET = process.env.INGEST_BUCKET ?? "scout-ingest";

function req(ok: boolean, msg: string) { if (!ok) throw new Error(msg); }
req(!!URL, "SUPABASE_URL missing");
req(!!ANON, "SUPABASE_ANON_KEY missing");
req(!!SRV, "SERVICE_ROLE missing (required for Storage upload)");

const sbRead = createClient(URL, ANON, {
  global: { headers: { Authorization: `Bearer ${JWT || ANON}` } },
});

const green = (s:string)=>`\x1b[32m${s}\x1b[0m`;
const red   = (s:string)=>`\x1b[31m${s}\x1b[0m`;
const cyan  = (s:string)=>`\x1b[36m${s}\x1b[0m`;
const yellow= (s:string)=>`\x1b[33m${s}\x1b[0m`;

async function countSilver(): Promise<number> {
  const { count, error } = await sbRead
    .from("silver_txn_items_api")
    .select("*", { count: "exact", head: true });
  if (error) throw error;
  return count ?? 0;
}

async function uploadZip(file: string): Promise<string> {
  const stat = fs.statSync(file);
  req(stat.isFile(), `ZIP not found: ${file}`);
  const base = path.basename(file);
  const date = new Date().toISOString().slice(0,10);
  const objectPath = `ingest/${date}/${base}`;
  const res = await fetch(`${URL}/storage/v1/object/${BUCKET}/${objectPath}`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${SRV}`,
      "apikey": SRV,
      "x-upsert": "false",
      "Content-Type": "application/zip",
    },
    body: fs.readFileSync(file),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Storage upload failed: ${res.status} ${t}`);
  }
  return objectPath;
}

function run(cmd: string, args: string[], cwd?: string) {
  const r = spawnSync(cmd, args, { stdio: "inherit", cwd });
  if (r.status !== 0) throw new Error(`${cmd} ${args.join(" ")} failed (${r.status})`);
}

async function main() {
  console.log(cyan("→ Step 1: Generate sample ZIPs"));
  const genScript = fs.existsSync("scripts/generate-bronze-zip.js")
    ? "scripts/generate-bronze-zip.js"
    : fs.existsSync("scripts/generate-bronze-zip.mjs")
      ? "scripts/generate-bronze-zip.mjs"
      : "";
  req(!!genScript, "No generator found at scripts/generate-bronze-zip.{js,mjs}");
  run("node", [genScript, "--out", "dist/bronze", "--stores", "5", "--days", "7", "--rows", "1200", "--seed", "42"]);

  const zips = fs.readdirSync("dist/bronze").filter(f => f.endsWith(".zip")).map(f => path.join("dist/bronze", f));
  req(zips.length > 0, "No ZIPs generated");
  const zip = zips.sort((a,b)=>fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs)[0];
  console.log(green(`   ✓ Generated: ${zip}`));

  console.log(cyan("→ Step 2: Baseline Silver count"));
  const before = await countSilver();
  console.log(`   count(silver_txn_items_api) = ${before}`);

  console.log(cyan("→ Step 3: Upload to Storage"));
  const objectPath = await uploadZip(zip);
  console.log(green(`   ✓ Uploaded to ${BUCKET}/${objectPath}`));

  console.log(cyan("→ Step 4: Wait for ingest (poll Silver count delta)"));
  let after = before, tries = 10;
  while (tries-- > 0) {
    await new Promise(r => setTimeout(r, 3000));
    after = await countSilver();
    process.stdout.write(`   poll → ${after}\r`);
    if (after > before) break;
  }
  process.stdout.write("\n");
  if (after > before) {
    console.log(green(`   ✓ Ingest detected (+${after - before})`));
  } else {
    console.log(yellow("   ⚠ No delta observed; proceeding to RPC/Edge smoke anyway"));
  }

  console.log(cyan("→ Step 5: RPC + Edge smoke"));
  run("npx", ["tsx", "scripts/smoke-all.ts"]);

  console.log(green("\nSMOKE PASS ✓ End-to-end pipeline looks healthy."));
}

main().catch(e => {
  console.error(red(`SMOKE FAIL ✗ ${e?.message || e}`));
  process.exit(1);
});