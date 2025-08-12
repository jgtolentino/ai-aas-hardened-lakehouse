# Lyra Orchestration System for Scout v5

**Parallel improvements orchestration with Bruno executor integration**

## Overview

The Lyra orchestration system enables parallel deployment of 9 Scout v5 work-streams with comprehensive gate validation, tenant/RBAC alignment, and rollback capabilities.

## Architecture

```
Pulser (Orchestrator) → Bruno (Executor) → Supabase Edge Functions
                    ↓
            [9 Parallel Workstreams]
                    ↓
            [Success Gate Validation]
                    ↓
            [Final Report Generation]
```

## Work-streams

| ID | Work-stream | Gate Condition | Priority |
|----|-------------|----------------|----------|
| W1 | Azure Design System | Build passes, <0.5% Percy diffs | Medium |
| W2 | Docs Hub RAG hydration | 10 queries return ≥2 citations in <1.2s | High |
| W3 | Ask Scout hardening | 8 prompts return 200, cache HITs observed | High |
| W4 | SQL Playground v1.1 | UPDATE/INSERT blocked, EXPLAIN returns JSON | Medium |
| W5 | Schema Explorer | Counts match meta within ±5% | Medium |
| W6 | API Explorer | 5 RPCs succeed, PostgREST errors shown | Medium |
| W7 | Live Metrics | DQ 'bad' hides export, 5 quantile bins | High |
| W8 | Learning Paths + SDKs | All samples run with mock JWT | Low |
| W9 | CDN + caching | LCP <1.5s cached, TTFB <300ms | High |

## Quick Start

### 1. Environment Setup

```bash
# Required environment variables
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_ANON_KEY="your-anon-key"
export SERVICE_ROLE="your-service-role-key"
export USER_JWT="your-user-jwt-token"
export ANALYST_JWT="your-analyst-jwt-token"
export MAPBOX_TOKEN="your-mapbox-token"
export TENANT_ID="your-tenant-id"
export BRANCH_NAME="feat/scout-v5-improvements"
export REGION="us-east-1"
```

### 2. Test All Scripts

```bash
cd orchestration/lyra
npm install
npm run test-all-scripts
```

### 3. Execute via Bruno

Copy the orchestration prompt to your Pulser instance:

```bash
# Copy the orchestration prompt
cat lyra-orchestration-prompt.md

# Paste into Pulser → Bruno executor
# Replace ALL-CAPS placeholders with actual values
```

### 4. Monitor Progress

Check artifacts directory for real-time progress:

```bash
ls -la artifacts/
# *.json - Individual gate reports
# report.md - Final consolidated report
```

## Script Structure

```
orchestration/lyra/
├── lyra-orchestration-prompt.md     # Main orchestration prompt
├── scripts/
│   ├── apply-azure-theme.js         # W1: Design system
│   ├── docs/
│   │   ├── chunk-docs.js            # W2: Document chunking
│   │   └── embed-docs.js            # W2: Vector embedding
│   ├── ask-scout/
│   │   └── add-cache-and-guards.js  # W3: Cache + security
│   ├── playground/
│   │   └── add-saved-queries.js     # W4: SQL playground
│   ├── schema/
│   │   ├── build-graph.js           # W5: Schema visualization
│   │   └── validate-counts.js       # W5: Count validation
│   ├── api-explorer/
│   │   ├── generate-catalog.js      # W6: API catalog
│   │   └── try-five-rpcs.js         # W6: RPC testing
│   ├── metrics/
│   │   ├── validate-kpis.js         # W7: KPI validation
│   │   └── validate-choropleth.js   # W7: Map validation
│   ├── learning/
│   │   ├── build-tracks.js          # W8: Learning paths
│   │   └── test-samples.js          # W8: SDK testing
│   ├── deploy/
│   │   └── vercel-configure.js      # W9: CDN setup
│   └── report/
│       └── merge-gates.js           # Final reporting
├── artifacts/                       # Generated reports
└── samples/                         # SDK code samples
```

## Gate Validation

Each work-stream has specific success criteria:

### W1: Azure Design System
- ✅ Build passes without errors
- ✅ Theme tokens applied correctly
- ✅ Percy visual diffs <0.5% on core pages

### W2: Docs Hub RAG
- ✅ Documents chunked and embedded successfully
- ✅ 10 test queries return ≥2 citations each
- ✅ Response time <1.2s (cached)

### W3: Ask Scout Hardening
- ✅ Cache headers configured (s-maxage=300)
- ✅ 8 canned prompts return HTTP 200
- ✅ Cache HIT observed on 2nd call

### W4: SQL Playground v1.1
- ✅ UPDATE/INSERT blocked with clear error
- ✅ EXPLAIN queries return plan JSON
- ✅ Saved queries functionality working

### W5: Schema Explorer
- ✅ Graph visualization generated
- ✅ Table counts match metadata ±5%
- ✅ RLS policies displayed correctly

### W6: API Explorer
- ✅ API catalog generated successfully
- ✅ 5 RPCs tested and succeed
- ✅ PostgREST error messages shown

### W7: Live Metrics
- ✅ KPIs accessible from gold views
- ✅ DQ 'bad' status hides email export
- ✅ Choropleth map renders 5 quantile bins

### W8: Learning Paths
- ✅ Role-based tracks configured
- ✅ All SDK samples run with mock JWT
- ✅ Multi-language examples working

### W9: CDN + Caching
- ✅ Vercel configuration deployed
- ✅ WebPageTest LCP <1.5s (cached)
- ✅ TTFB <300ms

## Rollback Strategy

If any gate fails:

1. **Partial Rollback**: Revert affected files only
2. **Function Rollback**: Redeploy previous Edge Functions
3. **Full Rollback**: Complete environment restoration
4. **Validation**: Re-run smoke tests

```bash
# Manual rollback if needed
git checkout HEAD~1 -- affected/files/
supabase functions deploy --reset
npm run smoke
```

## Troubleshooting

### Common Issues

1. **Environment Variables Missing**
   ```bash
   # Validate all required vars are set
   npm run validate-environment
   ```

2. **Rate Limiting**
   ```bash
   # OpenAI API or Supabase limits
   # Wait and retry, or use mock mode
   ```

3. **Network Timeouts**
   ```bash
   # Increase timeout in scripts
   # Check firewall/proxy settings
   ```

4. **Permission Errors**
   ```bash
   # Verify JWT has proper role
   # Check RLS policies
   ```

### Debug Mode

Set `DEBUG=1` for verbose logging:

```bash
DEBUG=1 npm run test-all-scripts
```

## Integration with Bruno

The Lyra orchestration integrates with Bruno executor through the following flow:

1. **Pulser** receives the orchestration prompt
2. **Bruno** executes commands in secure sandbox
3. **Edge Functions** process workstream operations
4. **Gates** validate success conditions
5. **Reports** consolidate all results

### Bruno Command Examples

```bash
# W1: Design System
:bruno run 'node scripts/apply-azure-theme.js'

# W2: RAG Hydration  
:bruno run 'node scripts/docs/chunk-docs.js --src docs --out .chunks.jsonl'

# W7: Metrics Validation
:bruno run 'node scripts/metrics/validate-kpis.js'
```

## Performance Considerations

- **Parallel Execution**: Work-streams run in 3 batches
- **Caching**: Aggressive caching at multiple levels
- **Rate Limiting**: Built-in backoff and retry
- **Resource Management**: Memory and timeout limits

## Security Features

- **Tenant Isolation**: All operations include X-Tenant-Id
- **RLS Enforcement**: Database security maintained
- **JWT Validation**: Proper authentication required
- **Input Sanitization**: SQL injection prevention

## Output Format

Final orchestration output:

```json
{
  "ok": true,
  "branch": "feat/scout-v5-improvements",
  "tenant_id": "production-tenant",
  "batch_results": [...],
  "gates": {
    "design_system": "pass",
    "docs_rag": "pass",
    "ask_scout_cache": "pass",
    "playground": "pass",
    "schema_explorer": "pass",
    "api_explorer": "pass",
    "live_metrics": "pass",
    "learning_paths": "pass",
    "cdn_caching": "pass"
  },
  "artifacts": [
    {"name":"report","path":"artifacts/report.md"}
  ],
  "rollback": "none",
  "notes": "All gates passed successfully"
}
```

## Support

For issues with the Lyra orchestration system:

1. Check the artifacts directory for detailed reports
2. Review the gate validation logs
3. Verify environment variable configuration
4. Test individual scripts in isolation

---

**Generated by AI-AAS Hardened Lakehouse Platform**