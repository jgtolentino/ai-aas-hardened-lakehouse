# Figma Integration Strategy

## APIs Used

### 1. Plugin API → On-canvas helpers
- **Purpose**: AI prompts, Jira ticket fetch, asset generation
- **Location**: `creative-studio/plugins/`
- **Execution**: Runs inside Figma, in the open file
- **Authentication**: Handled by Claude Desktop MCP extension (no tokens)

### 2. Widget API → Persistent objects
- **Purpose**: Scout KPI widgets, metrics visible in Figma
- **Location**: `creative-studio/widgets/`
- **Execution**: Persistent objects on the canvas
- **Authentication**: Claude Desktop MCP

### 3. REST API → External automation
- **Purpose**: Nightly export jobs, CI/CD sync
- **Execution**: MCP Hub → GitHub sync
- **Authentication**: Routed through Claude Desktop (no PAT duplication)

### 4. Code Connect → Component mapping
- **Purpose**: Live mapping of React components to Figma variants
- **Location**: `creative-studio/code-connect/`
- **Execution**: Designers see real code components in Figma

## Local Execution

- **Managed by**: Claude Desktop MCP extension
- **No tokens**: Authentication handled at desktop level
- **Plugins/Widgets**: Load from `creative-studio/plugins` and `creative-studio/widgets`
- **REST calls**: Routed through MCP Hub, not raw PATs

## Workflow

```
Designer edits file → Dev Mode MCP exposes nodes → Claude Desktop → repo sync
```

## MCP Hub Integration

The MCP Hub (`infra/mcp-hub/`) provides:
- Unified API for all Figma operations
- Token-free architecture
- Production-ready routing for Custom GPTs and CI/CD
- Centralized logging and monitoring

## Development Setup

1. **Enable Figma Dev Mode MCP** in Figma Preferences
2. **Start MCP Hub**: `cd infra/mcp-hub && npm run dev`
3. **Develop plugins**: Work in `creative-studio/plugins/`
4. **Test widgets**: Develop in `creative-studio/widgets/`

## Security

- No Figma tokens stored in repository
- All authentication through Claude Desktop
- Service role keys only in server-side environments
- Public keys properly prefixed with `NEXT_PUBLIC_`
