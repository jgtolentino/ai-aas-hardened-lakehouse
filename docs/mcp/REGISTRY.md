# MCP Server Registry

## Overview

This registry documents all Model Context Protocol (MCP) servers configured for the Scout Analytics Platform. Each server provides specific tools and capabilities for different aspects of the development workflow.

## Active Servers

| Server | Transport | Auth Mode | Port/Endpoint | Status | Tools Available |
|--------|-----------|-----------|---------------|--------|-----------------|
| **Figma Dev Mode** | stdio | Desktop SSO | Managed by plugin | ✅ Active | `file.export`, `selection.read`, `component.props` |
| **Supabase Primary** | http | GitHub Secrets | 3845 | ✅ Active | `sql.exec`, `schema.diff`, `migration.apply`, `functions.deploy` |
| **Supabase Alternate** | http | Service Role | 3846 | ✅ Active | `agent.registry`, `sql.exec`, `branch.create` |
| **GitHub** | stdio/http | Desktop/gh CLI | 3847 or stdio | ✅ Active | `repo.read`, `pr.create`, `file.commit`, `issues.list` |
| **Filesystem** | stdio | Local access | stdio | ✅ Active | `file.read`, `file.write`, `directory.list`, `file.search` |
| **Postgres Local** | http | Connection string | 3848 | 🟡 Optional | `query.exec`, `schema.inspect` |

## Server Details

### 🎨 Figma Dev Mode MCP
**Purpose**: Design-to-code integration, component inspection  
**Authentication**: Token-free via Claude Desktop SSO  
**Configuration**: Managed by Figma Desktop plugin  

**Available Tools**:
- `figma.file.export` - Export design assets
- `figma.selection.read` - Get selected component properties
- `figma.component.props` - Extract component prop definitions
- `figma.layer.inspect` - Analyze layer structure and styles

**Usage Example**:
```typescript
// Automatically available in Claude Desktop when Figma is open
"Extract props from the selected KPI Tile component"
```

**Rate Limits**: None (local desktop app)  
**Safety Notes**: 
- Only works when Figma Desktop is running
- Requires Dev Mode to be enabled
- No credentials stored or transmitted

---

### 🗄️ Supabase Primary
**Purpose**: Main database operations, schema management  
**Authentication**: Personal Access Token via GitHub Secrets  
**Endpoint**: `https://cxzllzyxwpyptfretryc.supabase.co`

**Configuration**:
```json
{
  "command": "npx",
  "args": ["-y", "@supabase/mcp-server-supabase@latest", "--project-ref=cxzllzyxwpyptfretryc"],
  "env": {
    "SUPABASE_ACCESS_TOKEN": "sbp_c4c5fa81cc1fde770145ace4e79a33572748b25f"
  }
}
```

**Available Tools**:
- `supabase.sql.exec` - Execute SQL queries
- `supabase.schema.diff` - Compare schema changes
- `supabase.migration.apply` - Apply database migrations
- `supabase.functions.deploy` - Deploy Edge Functions
- `supabase.storage.upload` - File storage operations
- `supabase.auth.config` - Authentication settings

**Rate Limits**: 1000 requests/hour  
**Safety Notes**: 
- Read-only mode available with `--read-only` flag
- All operations logged for audit
- RLS policies enforced

---

### 🗄️ Supabase Alternate  
**Purpose**: Agent registry, experimental features  
**Authentication**: Service Role Key  
**Endpoint**: `https://texxwmlroefdisgxpszc.supabase.co`

**Available Tools**:
- `supabase.agent.registry` - Manage agent configurations
- `supabase.sql.exec` - Execute SQL queries
- `supabase.branch.create` - Create database branches
- `supabase.experiment.run` - Run experimental queries

**Rate Limits**: 500 requests/hour  
**Safety Notes**: 
- Used for agent coordination
- Separate from production data
- Enhanced logging enabled

---

### 🐙 GitHub MCP
**Purpose**: Repository operations, CI/CD integration  
**Authentication**: Token-free via `gh` CLI or GitHub App  
**Transport**: stdio (preferred) or HTTP on port 3847

**Configuration**:
```json
{
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-github"],
  "env": {
    "GITHUB_TOKEN": "github_pat_..." // Optional, uses gh CLI if available
  }
}
```

**Available Tools**:
- `github.repo.read` - Read repository contents
- `github.pr.create` - Create pull requests
- `github.pr.merge` - Merge pull requests
- `github.file.commit` - Commit file changes
- `github.issues.list` - List and manage issues
- `github.workflow.run` - Trigger GitHub Actions
- `github.release.create` - Create releases

**Rate Limits**: 5000 requests/hour (authenticated)  
**Safety Notes**: 
- Prefers `gh` CLI authentication when available
- Repository permissions enforced by GitHub
- All operations create audit trail

---

### 📁 Filesystem MCP
**Purpose**: Local file operations, code generation  
**Authentication**: Local filesystem permissions  
**Transport**: stdio

**Available Tools**:
- `fs.file.read` - Read file contents
- `fs.file.write` - Write file contents
- `fs.directory.list` - List directory contents
- `fs.file.search` - Search files by pattern
- `fs.file.move` - Move/rename files
- `fs.directory.create` - Create directories

**Rate Limits**: None (local operations)  
**Safety Notes**: 
- Respects file system permissions
- Cannot access files outside allowed directories
- All operations logged

---

### 🐘 Postgres Local (Optional)
**Purpose**: Local database development, testing  
**Authentication**: Connection string  
**Endpoint**: `postgresql://postgres:postgres@localhost:54322/postgres`

**Configuration**:
```json
{
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-postgres", "postgresql://postgres:postgres@localhost:54322/postgres"]
}
```

**Available Tools**:
- `postgres.query.exec` - Execute SQL queries
- `postgres.schema.inspect` - Inspect database schema
- `postgres.table.describe` - Get table definitions

**Rate Limits**: None (local database)  
**Safety Notes**: 
- Only for local development
- No production data access
- Used with `supabase start`

## Server Management

### Starting Servers
Most servers start automatically with Claude Desktop. For manual control:

```bash
# Check server status
curl http://127.0.0.1:3845/health  # Supabase Primary
curl http://127.0.0.1:3847/health  # GitHub (if HTTP mode)

# Start local Postgres
supabase start

# Restart Claude Desktop to reload MCP config
osascript -e 'tell application "Claude" to quit'
open -a Claude
```

### Stopping Servers
```bash
# Stop local Postgres
supabase stop

# Kill specific HTTP servers
pkill -f "mcp-server-supabase"
pkill -f "server-github"
```

### Health Checks
```bash
# Comprehensive health check
./scripts/check-mcp-health.sh

# Individual server tests
pnpm run test:mcp:supabase
pnpm run test:mcp:github
pnpm run test:mcp:figma
```

## Troubleshooting

### Common Issues

**Server Not Responding**:
```bash
# Check if server process is running
ps aux | grep mcp-server

# Check port conflicts
lsof -i :3845

# Restart Claude Desktop
osascript -e 'tell application "Claude" to quit' && sleep 2 && open -a Claude
```

**Authentication Failures**:
```bash
# Verify GitHub CLI auth
gh auth status

# Check Supabase token
echo $SUPABASE_ACCESS_TOKEN | head -c 20

# Test manual connection
npx @supabase/mcp-server-supabase@latest --project-ref=cxzllzyxwpyptfretryc
```

**Tool Not Available**:
- Verify server is running and healthy
- Check Claude Desktop MCP configuration
- Ensure correct server supports the tool
- Verify authentication and permissions

### Debug Commands

```bash
# Enable MCP debug logging
export MCP_DEBUG=1

# Test specific server
npx @supabase/mcp-server-supabase@latest --help

# Validate configuration
node -e "console.log(JSON.parse(require('fs').readFileSync('$HOME/Library/Application Support/Claude/claude_desktop_config.json', 'utf8')))"
```

## Security Guidelines

### Token Management
- Store sensitive tokens in GitHub Secrets or macOS Keychain
- Use read-only tokens where possible
- Rotate tokens regularly (quarterly)
- Never commit tokens to git history

### Network Security
- HTTP servers bind to localhost only
- Use stdio transport when available
- Enable HTTPS for external endpoints
- Monitor for unusual network activity

### Access Control
- Apply principle of least privilege
- Use service accounts with limited scope
- Enable audit logging for all operations
- Regular access reviews

## Monitoring

### Metrics to Track
- Server uptime and response times
- Tool usage patterns and success rates
- Authentication failures
- Rate limit violations

### Alerting
- Server health checks every 5 minutes
- Authentication failure notifications
- Rate limit warnings at 80% threshold
- Disk space and memory monitoring

---

**Last Updated**: August 28, 2025  
**Configuration Version**: 2.1.0  
**Contact**: TBWA Platform Team