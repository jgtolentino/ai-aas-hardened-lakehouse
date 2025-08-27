# sc:mcp-full-stack

Goal: attach Figma, Supabase, Mapbox, Vercel MCP servers and verify tool availability.

Checklist:
- [ ] Connect Figma Dev Mode MCP → tools list visible
- [ ] Connect Supabase MCP → db tools visible (schema, query, realtime)
- [ ] Connect Mapbox MCP → geocoding/layer tools visible
- [ ] Connect Vercel MCP → deploy/status/env tools visible (if supported by your client)
- [ ] Run scripts/mcp/full_stack_check.sh and ensure all ports OK

Tip: If a client shows a red status dot, toggle the Figma MCP switch, or try /mcp instead of /sse where applicable.
