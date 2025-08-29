# MCP Hub

A unified HTTP API gateway that routes to multiple Model Context Protocol (MCP) servers, including Claude Desktop MCPs.

## Architecture

MCP Hub serves as a centralized proxy for:
- **Supabase**: Database operations and analytics (direct adapter)
- **Mapbox**: Geospatial data and mapping services (direct adapter)
- **Figma**: Design file access via Claude Desktop MCP (MCP routing)
- **GitHub**: Repository operations via Claude Desktop MCP (MCP routing)
- **Sync Operations**: Figma → GitHub workflows via MCP routing

## Endpoints
- `GET /openapi.json` — OpenAPI for GPT Action
- `POST /mcp/run` — secured by `X-API-Key`
- `GET /health`

## Adapters

### Direct Adapters (with tokens)
- **Supabase**: Database operations, uses service role
- **Mapbox**: Geospatial operations, requires API token

### MCP Routing Adapters (no tokens needed)
- **Figma MCP Router**: Routes to Claude Desktop's Figma MCP
  - Selection-aware operations in Dev Mode
  - Tool mappings: `file.exportJSON` → `get_file_data`, `nodes.get` → `get_selection`
- **GitHub MCP Router**: Routes to Claude Desktop's GitHub MCP
  - Tool mappings: `repo.commitFile` → `create_or_update_file`
- **Sync MCP Router**: Orchestrates Figma → GitHub workflows
  - `sync.figmaFileToRepo`: Export full Figma file and commit
  - `sync.figmaSelectionToRepo`: Export current selection and commit

## Security
- Set `HUB_API_KEY` (32+ chars)
- Use **read-only** Supabase creds (gold views only)
- MCP routing uses stdio protocol (no exposed tokens)
- Rate limit enabled

## Run
```bash
pnpm i
cp .env.example .env  # fill values
pnpm start
```
CI trigger test - 1756323905
