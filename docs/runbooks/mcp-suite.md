# MCP Suite Runbook — Figma, Supabase, Mapbox, Vercel

## Start/Stop
- Figma: enable Dev Mode MCP in Figma desktop; expects 127.0.0.1:3845 (/sse or /mcp)
- Supabase MCP: start server on 127.0.0.1:3846
- Mapbox MCP: start server on 127.0.0.1:3847
- Vercel MCP: start server on 127.0.0.1:3848

## Health
- Run `scripts/mcp/full_stack_check.sh` — all ✅
- If a server shows red in the client, toggle service, try alternate path (/mcp vs /sse), verify port open.

## Security
- Tokens only in secure client stores or Vercel project envs; never in repo or shell rc.
- Rotate keys quarterly or on leakage.
- Limit scopes (read-only where possible); use separate tokens per environment.

## Incident Steps
- Loss of design read (Figma): restart Figma MCP, reselect frame.
- Supabase failures: check PostgREST logs, RLS violations, quotas.
- Mapbox rate limits: throttle tiles, reduce layer density, apply caching.
- Vercel deploy stuck: check build logs; roll back to previous deployment.
