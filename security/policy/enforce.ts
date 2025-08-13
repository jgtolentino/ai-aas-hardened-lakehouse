#!/usr/bin/env -S npx tsx
import fs from "fs";
import path from "path";
import yaml from "yaml";

const [,, reportPath, policyPath] = process.argv;
if (!reportPath || !policyPath) {
  console.error("Usage: enforce.ts <report.(sarif|json)> <policy.yaml>");
  process.exit(2);
}
const policy = yaml.parse(fs.readFileSync(policyPath, "utf8"));

function load(file: string) {
  const raw = fs.readFileSync(file, "utf8");
  return file.endsWith(".sarif") ? JSON.parse(raw) : JSON.parse(raw || "[]");
}

function countTrivy(sarif: any) {
  const results = sarif?.runs?.[0]?.results ?? [];
  const bySev: Record<string, number> = { CRITICAL:0, HIGH:0, MEDIUM:0, LOW:0 };
  for (const r of results) {
    const sev = r?.properties?.severity?.toUpperCase?.() ?? r?.level?.toUpperCase?.() ?? "LOW";
    if (bySev[sev] !== undefined) bySev[sev]++;
  }
  return bySev;
}

function countSemgrep(sarif: any) {
  const results = sarif?.runs?.[0]?.results ?? [];
  const byLevel: Record<string, number> = { ERROR:0, WARNING:0, NOTE:0 };
  for (const r of results) {
    const lvl = (r?.level ?? "note").toUpperCase();
    if (byLevel[lvl] !== undefined) byLevel[lvl]++;
  }
  return byLevel;
}

function countTrufflehog(json: any[]) {
  // expecting array; using --only-verified in CI
  return { VERIFIED_FINDINGS: json.length };
}

const file = load(reportPath);
let ok = true;

if (reportPath.includes("trivy") && reportPath.endsWith(".sarif")) {
  const c = countTrivy(file);
  const t = policy.fail_thresholds.trivy;
  for (const k of Object.keys(t)) if (c[k] > t[k]) { ok = false; console.error(`Trivy ${k}: ${c[k]} > ${t[k]}`); }
}
else if (reportPath.includes("semgrep") && reportPath.endsWith(".sarif")) {
  const c = countSemgrep(file);
  const t = policy.fail_thresholds.semgrep;
  for (const k of Object.keys(t)) if (c[k] > t[k]) { ok = false; console.error(`Semgrep ${k}: ${c[k]} > ${t[k]}`); }
}
else if (reportPath.includes("trufflehog") && reportPath.endsWith(".json")) {
  const c = countTrufflehog(Array.isArray(file) ? file : []);
  const t = policy.fail_thresholds.trufflehog;
  if (c.VERIFIED_FINDINGS > t.VERIFIED_FINDINGS) { ok = false; console.error(`TruffleHog verified: ${c.VERIFIED_FINDINGS} > ${t.VERIFIED_FINDINGS}`); }
}
else {
  console.error(`Unknown report type: ${reportPath}`);
  process.exit(2);
}

if (!ok) process.exit(1);
console.log("Policy OK");