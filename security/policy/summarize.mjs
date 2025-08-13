// security/policy/summarize.mjs
import fs from "fs";

function readJsonSafe(p, fallback) {
  try { return JSON.parse(fs.readFileSync(p, "utf8") || fallback); }
  catch { return JSON.parse(fallback); }
}

const args = process.argv.slice(2);
const get = (k) => {
  const i = args.indexOf(k);
  return i >= 0 ? args[i+1] : null;
};

const trufflePath = get("--truffle");
const trivyPath   = get("--trivy");
const semgrepPath = get("--semgrep");
const outputsPath = get("--outputs");
const slackOut    = get("--slack-out");

const truffle = trufflePath ? readJsonSafe(trufflePath, "[]") : [];
const trivy   = trivyPath ? readJsonSafe(trivyPath, "{}") : {};
const semgrep = semgrepPath ? readJsonSafe(semgrepPath, "{}") : {};

const trivyResults = trivy?.runs?.[0]?.results ?? [];
const semgrepResults = semgrep?.runs?.[0]?.results ?? [];

const sevCount = { CRITICAL:0, HIGH:0, MEDIUM:0, LOW:0 };
for (const r of trivyResults) {
  const sev = (r?.properties?.severity || r?.level || "LOW").toUpperCase();
  if (sevCount[sev] !== undefined) sevCount[sev]++;
}

const semgrepCount = { ERROR:0, WARNING:0, NOTE:0 };
for (const r of semgrepResults) {
  const lvl = (r?.level || "note").toUpperCase();
  if (semgrepCount[lvl] !== undefined) semgrepCount[lvl]++;
}

const truffleCount = Array.isArray(truffle) ? truffle.length : 0;

const summary = {
  trufflehog_verified: truffleCount,
  trivy: sevCount,
  semgrep: semgrepCount,
};

const slackBlocks = [
  { type: "section", text: { type: "mrkdwn", text: "*🔒 Nightly Security Sweep Results*" } },
  { type: "context", elements: [{ type: "mrkdwn", text: `Run: ${process.env.GITHUB_RUN_ID} • Repo: ${process.env.GITHUB_REPOSITORY}` }]},
  { type: "divider" },
  { type: "section", fields: [
      { type: "mrkdwn", text: `*TruffleHog (verified)*\n${truffleCount}` },
      { type: "mrkdwn", text: `*Trivy CRIT/HIGH/MED*\n${sevCount.CRITICAL}/${sevCount.HIGH}/${sevCount.MEDIUM}` },
      { type: "mrkdwn", text: `*Semgrep ERR/WARN*\n${semgrepCount.ERROR}/${semgrepCount.WARNING}` },
    ]},
  { type: "context", elements: [{ type: "mrkdwn", text: "_Artifacts uploaded for full details. Thresholds enforced in PR workflow only._" }]},
];

const slackPayload = { blocks: slackBlocks, text: `Nightly Security: truffle=${truffleCount}, trivy(H/M/C)=${sevCount.HIGH}/${sevCount.MEDIUM}/${sevCount.CRITICAL}, semgrep(E/W)=${semgrepCount.ERROR}/${semgrepCount.WARNING}` };

if (slackOut) fs.writeFileSync(slackOut, JSON.stringify(slackPayload));

if (outputsPath) {
  fs.appendFileSync(outputsPath, `trufflehog_verified=${truffleCount}\n`);
  fs.appendFileSync(outputsPath, `trivy_critical=${sevCount.CRITICAL}\n`);
  fs.appendFileSync(outputsPath, `trivy_high=${sevCount.HIGH}\n`);
  fs.appendFileSync(outputsPath, `trivy_medium=${sevCount.MEDIUM}\n`);
  fs.appendFileSync(outputsPath, `semgrep_error=${semgrepCount.ERROR}\n`);
  fs.appendFileSync(outputsPath, `semgrep_warning=${semgrepCount.WARNING}\n`);
}

console.log(JSON.stringify({ ok: true, summary }, null, 2));