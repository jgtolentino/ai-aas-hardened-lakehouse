# MCP Hub

Secure webhook for a Custom GPT Action to reach internal tools (adapters).

## Endpoints
- `GET /openapi.json` — OpenAPI for GPT Action
- `POST /mcp/run` — secured by `X-API-Key`
- `GET /health`

## Security
- Set `HUB_API_KEY` (32+ chars)
- Use **read-only** Supabase creds (gold views only)
- Rate limit enabled

## Run
pnpm i
cp .env.example .env  # fill values
pnpm start
