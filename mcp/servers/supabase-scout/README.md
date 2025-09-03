# Supabase Scout MCP Server

A Model Context Protocol (MCP) server for interacting with the Scout schema in Supabase.

## Features

### Session History Management
- Create and retrieve session history entries
- Track user, assistant, and system messages
- Store metadata and embeddings

### Agent Registry
- Register and manage AI agents
- Update agent status and configuration
- List agents by type and status

### Event System
- Create and track Scout events
- Mark events as processed
- Query events by type and status

### Knowledge Base
- Add documents to knowledge base
- Search documents by content
- Store embeddings and metadata

### Migration Tools
- Execute SQL migrations
- Query schema information
- Safe SQL execution with logging

## Setup

### 1. Install Dependencies
```bash
cd mcp/servers/supabase-scout
npm install
```

### 2. Build the Server
```bash
npm run build
```

### 3. Configure Environment

The server requires the following environment variables:
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY`: Service role key for admin access
- `SUPABASE_ANON_KEY`: Anonymous key (optional fallback)

These are loaded automatically from:
1. macOS Keychain (via `load-secrets-from-keychain.sh`)
2. `supabase/.env.local` file

### 4. Run the Server

Using the wrapper script (recommended):
```bash
./scripts/supabase_scout_mcp_full.sh
```

Or directly:
```bash
cd mcp/servers/supabase-scout
npm start
```

## Available Tools

### Session History
- `scout_create_session`: Create a new session entry
- `scout_get_sessions`: Retrieve session history

### Agent Management
- `scout_register_agent`: Register a new agent
- `scout_list_agents`: List all agents
- `scout_update_agent_status`: Update agent status

### Event System
- `scout_create_event`: Create a new event
- `scout_get_events`: Query events
- `scout_mark_event_processed`: Mark event as processed

### Knowledge Base
- `scout_add_knowledge`: Add document to knowledge base
- `scout_search_knowledge`: Search documents

### Database Operations
- `scout_run_migration`: Execute SQL migrations
- `scout_get_schema_info`: Get schema information

## Database Schema

The Scout schema includes:
- `scout.session_history`: Session and message tracking
- `scout.agents`: Agent registry
- `scout.events`: Event logging
- `scout.knowledge_base`: Document storage

All tables include:
- UUID identifiers
- Timestamps (created_at, updated_at)
- JSONB metadata fields
- Vector embeddings (where applicable)
- Row Level Security (RLS) policies

## Security

- RLS is enabled on all tables
- Policies restrict access to authenticated users
- Service role has full access
- Anonymous users have read-only access

## Development

### Run in Development Mode
```bash
npm run dev
```

### Clean Build Files
```bash
npm run clean
```

### Project Structure
```
supabase-scout/
├── src/
│   └── index.ts        # Main MCP server implementation
├── dist/               # Compiled JavaScript
├── package.json        # Dependencies
├── tsconfig.json       # TypeScript configuration
└── README.md          # This file
```

## Integration with Claude

To use this MCP server with Claude Desktop:

1. Add to Claude's MCP configuration:
```json
{
  "mcpServers": {
    "supabase-scout": {
      "command": "/path/to/scripts/supabase_scout_mcp_full.sh"
    }
  }
}
```

2. The server will be available as tools in Claude for managing Scout data.

## Troubleshooting

### Missing Environment Variables
Ensure `SUPABASE_URL` and keys are set in either:
- macOS Keychain (use `security add-generic-password`)
- `supabase/.env.local` file

### Build Errors
```bash
# Clean and rebuild
npm run clean
npm install
npm run build
```

### Connection Issues
- Verify Supabase project is running
- Check network connectivity
- Validate API keys are correct

## License

Part of the AI-AAS Hardened Lakehouse project.
