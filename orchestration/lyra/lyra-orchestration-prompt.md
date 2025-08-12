# Lyra Orchestration Prompt for Scout v5 Parallel Improvements

## Usage Instructions

1. **Copy this prompt** and paste it into your Pulser orchestrator
2. **Replace ALL-CAPS variables** with your actual values:
   - `{BRANCH_NAME}` - Current git branch
   - `{TENANT_ID}` - Tenant under test
   - `{REGION}` - AWS/Edge region for functions

3. **Ensure environment variables** are set:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY` 
   - `SERVICE_ROLE`
   - `USER_JWT`
   - `ANALYST_JWT`
   - `MAPBOX_TOKEN`

4. **Run via Pulser** with Bruno as the sole executor

---

```
=== LYRA_ORCHESTRATION_PROMPT_v1 ===
OBJECTIVE
- Ship parallel improvements to Scout v5 with tenant/RBAC alignment:
  A) Azure design system 
  B) Docs Hub RAG hydration
  C) Ask Scout hardening
  D) SQL Playground v1.1
  E) Schema Explorer
  F) API Explorer
  G) Live Metrics (choropleth + KPIs)
  H) Learning Paths + multi-SDK
  I) CDN + caching
- All changes must keep RLS, RBAC, and tenant isolation intact (X-Tenant-Id).

EXECUTION MODEL
- Orchestrator: Pulser routes (planner/critic/executor).
- Executor: Bruno only. Claude has zero direct shell/DB credentials.
- All commands are idempotent. Prefer "create or replace" and safe migrations.

GLOBAL CONSTRAINTS
- Never print secrets. Use env placeholders:
  SUPABASE_URL, SUPABASE_ANON_KEY, SERVICE_ROLE, USER_JWT, ANALYST_JWT, MAPBOX_TOKEN.
- All data access is READ via caller JWT; WRITES restricted by role. Include header:
  "X-Tenant-Id: {TENANT_ID}"
- DB code runs with SECURITY INVOKER; RLS ON for all tables/views/functions.
- Stop immediately on non-zero exit; print failing step and last 60 lines of logs.

ENV & CONTEXT
- Repos:
  - app: ./scout-analytics-blueprint-doc
  - backend: ./ai-aas-hardened-lakehouse
- Current branch: {BRANCH_NAME}
- Tenant under test: {TENANT_ID}
- Region: {REGION} (for Edge Functions)
- Cache TTLs: 300s for analytics responses; 24h for docs embeddings.

PARALLEL WORK-STREAMS
W1: Azure Design System
  - Add theme tokens & CSS import; no functional diffs.
  - Gate: build passes; no Percy diffs > 0.5% on core pages.

W2: Docs Hub RAG hydration
  - Chunk markdown in /docs and /guides → docs.chunks with tenant_id NULL (global) unless overriding per-tenant.
  - Embed with text-embedding-3-small or local equivalent if OPENAI off.
  - Gate: 10 seeded Qs return ≥2 citations in <1.2s (cached).

W3: Ask Scout hardening
  - Add cache headers (s-maxage=300), guardrail text, chart payload schema.
  - Gate: 8 canned prompts return 200; HIT observed on 2nd call.

W4: SQL Playground v1.1
  - Saved queries (per user/tenant), EXPLAIN viewer, 10 rps IP limit.
  - Gate: UPDATE/INSERT blocked with clear error; EXPLAIN returns plan JSON.

W5: Schema Explorer
  - Graph view from information_schema + pg_catalog; show RLS flags.
  - Gate: counts match meta within ±5%.

W6: API Explorer
  - Enumerate RPCs/views; Try-It uses JWT + X-Tenant-Id.
  - Gate: 5 RPCs succeed live; errors show PostgREST messages.

W7: Live Metrics
  - KPIs from gold views; choropleth from gold_geo_choropleth_latest.
  - Gate: DQ 'bad' hides email export; map paints 5 quantile bins.

W8: Learning Paths + SDKs
  - Role-based tracks; runnable JS/Python/Java/C# samples.
  - Gate: All samples run locally with mock JWT.

W9: CDN + caching
  - Vercel config for static + Edge region; add SWR hints; Sentry.
  - Gate: WebPageTest LCP < 1.5s (cached), TTFB < 300ms.

PLAN
1) Preflight:
   - Verify env vars present.
   - Verify RLS on silver/gold/inferred/docs tables.
   - Ensure tenant membership exists for {TENANT_ID}.

2) Execute Streams W1–W9 in parallel batches:
   Batch 1: W1, W3, W5
   Batch 2: W2, W4, W6
   Batch 3: W7, W8, W9

3) Postflight:
   - Run smoke-pipeline.ts (Bronze→Silver→Gold checks).
   - Run eight canned Ask Scout prompts (cached).
   - Run 10 docs Qs; verify citations and latencies.
   - Generate report.md with pass/fail matrix.

OUTPUT FORMAT (STRICT)
Return JSON only:
{
  "ok": boolean,
  "branch": "{BRANCH_NAME}",
  "tenant_id": {TENANT_ID},
  "batch_results": [
    {"batch":"1","ok":true,"steps":[...]},
    {"batch":"2","ok":true,"steps":[...]},
    {"batch":"3","ok":true,"steps":[...]}
  ],
  "gates": {
    "design_system": "pass|fail",
    "docs_rag": "pass|fail",
    "ask_scout_cache": "pass|fail",
    "playground": "pass|fail",
    "schema_explorer": "pass|fail",
    "api_explorer": "pass|fail",
    "live_metrics": "pass|fail",
    "learning_paths": "pass|fail",
    "cdn_caching": "pass|fail"
  },
  "artifacts": [
    {"name":"report","path":"artifacts/report.md"},
    {"name":"percy","path":"artifacts/percy.json"}
  ],
  "rollback": "none|partial|full",
  "notes": "short text"
}

COMMAND LIBRARY (USE THESE ONLY VIA BRUNO)
# Preflight
:bruno run 'test -n "$SUPABASE_URL" -a -n "$SUPABASE_ANON_KEY" -a -n "$USER_JWT"'
:bruno run 'curl -sS "$SUPABASE_URL/rest/v1/tenant_memberships_me" \
 -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $USER_JWT" | jq .'

# W1 Design System
:bruno run 'node scripts/apply-azure-theme.js'
:bruno run 'npm run build'

# W2 Docs RAG hydrate
:bruno run 'node scripts/docs/chunk-docs.js --src docs --out .chunks.jsonl'
:bruno run 'node scripts/docs/embed-docs.js --in .chunks.jsonl --tenant null'
:bruno run 'curl -sS -X POST "$SUPABASE_URL/functions/v1/doc-hub-chat" \
 -H "Authorization: Bearer $USER_JWT" -H "X-Tenant-Id: {TENANT_ID}" \
 -H "Content-Type: application/json" -d "{\"q\":\"How to use SQL playground?\"}" | jq .citations'

# W3 Ask Scout hardening
:bruno run 'node scripts/ask-scout/add-cache-and-guards.js'
:bruno run 'curl -i -sS -X POST "$SUPABASE_URL/functions/v1/ask-scout" \
 -H "Authorization: Bearer $USER_JWT" -H "X-Tenant-Id: {TENANT_ID}" \
 -H "Content-Type: application/json" -d "{\"q\":\"Top brands last 30 days\"}" | sed -n "1,10p"'

# W4 Playground v1.1
:bruno run 'node scripts/playground/add-saved-queries.js'
:bruno run 'curl -sS -X POST "$SUPABASE_URL/rest/v1/rpc/exec_select" \
 -H "Authorization: Bearer $USER_JWT" -H "X-Tenant-Id: {TENANT_ID}" -H "apikey: $SUPABASE_ANON_KEY" \
 -H "Content-Type: application/json" -d "{\"p_sql\":\"select 1\"}" | jq .'

# W5 Schema Explorer
:bruno run 'node scripts/schema/build-graph.js'
:bruno run 'node scripts/schema/validate-counts.js'

# W6 API Explorer
:bruno run 'node scripts/api-explorer/generate-catalog.js'
:bruno run 'node scripts/api-explorer/try-five-rpcs.js'

# W7 Live Metrics
:bruno run 'node scripts/metrics/validate-kpis.js'
:bruno run 'node scripts/metrics/validate-choropleth.js'

# W8 Learning Paths
:bruno run 'node scripts/learning/build-tracks.js'
:bruno run 'node scripts/learning/test-samples.js'

# W9 CDN + caching
:bruno run 'node scripts/deploy/vercel-configure.js'
:bruno run 'npm run deploy:web'

# Postflight
:bruno run 'npm run smoke'
:bruno run 'node scripts/report/merge-gates.js > artifacts/report.md'
:bruno run 'jq -n --arg ok "true" --arg branch "{BRANCH_NAME}" --argjson tenant {TENANT_ID} \
  --slurpfile gates artifacts/gates.json \
  "{ ok: (\$ok==\"true\"), branch: \$branch, tenant_id: \$tenant, batch_results: [], gates: \$gates[0], artifacts: [ {name:\"report\",path:\"artifacts/report.md\"} ], rollback: \"none\", notes: \"All gates passed.\" }"'

ROLLBACK
- If any gate fails:
  1) Revert affected files (git checkout {BRANCH_NAME} -- <paths>)
  2) Re-deploy previous Edge functions (supabase functions deploy with pinned commit).
  3) Re-run npm run build, smoke.
  4) Return JSON with rollback:"partial" and list of reverted items.

STOP CONDITIONS
- Missing env var
- RLS off on any target table
- Any Edge function deploy error
- Any gate fail

END_OF_PROMPT
=== LYRA_ORCHESTRATION_PROMPT_v1 ===
```