# Claude Project Context — ai-aas-hardened-lakehouse

## Repo Coordinates
- Root: `/Users/tbwa/ai-aas-hardened-lakehouse`
- Related project: `/Users/tbwa/scout-analytics-blueprint-doc`
  - Contains PRD, visualization blueprint, grid layout, chart registry
- Key modules in main repo:
  - `infra/mcp-hub` — Hub adapters (supabase, mapbox, figma, github, sync)
  - `supabase/` — migrations, CI/CD sync
  - `.github/workflows/` — CI/CD gates
  - `docs/` — runbooks, security, planning

## Execution Rules
- Execution intent assumed — no questions, only commits and tasks
- Never commit secrets
- Each PR limited to one intent (feat/fix/chore/docs)
- Claude can read both repos; integration tasks must bind blueprint outputs into live code paths in ai-aas-hardened-lakehouse
- Use Supabase RLS + Vercel deploy targets for dashboard

## Review Scope
Claude must:
- Parse `/Users/tbwa/scout-analytics-blueprint-doc`
- Compare PRD requirements vs. current repo implementation
- Generate migration tasks → TSX components, Supabase RPCs, chart registry
- Identify blockers to production readiness (security, CI/CD, schema completeness)
