# Agents & Attribution

We record **who (agent)** performed changes via **Git commit trailers** and surface them on PRs.

## Commit Trailers
- `Agent:` one of `superclaude|bruno|claude-desktop|human`
- `Tool:` freeform (e.g., `mcp:figma`, `mcp:github`, `vercel-cli`)
- `Corr-ID:` a short correlation id (e.g., `sc-2025-08-28-001`)

Example:
```
feat(dashboard): wire Geo module choropleth

Agent: superclaude
Tool: mcp:sync.figmaFileToRepo
Corr-ID: sc-2025-08-28-001
```

Trailers are **required** on PRs to `main`. CI rejects missing/unknown agents.