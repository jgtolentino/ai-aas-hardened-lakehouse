# Model Context Protocol (MCP) Configuration

This directory contains the secure MCP server configurations for the AI-AAS Hardened Lakehouse platform.

## Architecture

```
Claude/Cursor → MCP Servers → Security Guards → Data Sources
                     ↓
              Interceptor/Audit
```

## Configured Servers

### 1. **Filesystem** (Local Development)
- Read/write access to project files
- Execute permission disabled
- Used for code generation and file manipulation

### 2. **Context7** (Documentation)
- Read-only access to technical documentation
- Supports: Next.js, React, PostgreSQL, Supabase, TypeScript
- Rate limited: 60 requests/minute
- API key required

### 3. **Supabase Primary** (Database)
- Read-only access to primary database
- Project-scoped with personal access token
- No access to storage, functions, or secrets

### 4. **Scout Analytics** (Business Intelligence)
- Advanced analytics mode
- Cross-domain data access
- Schemas: scout, analytics, gold, platinum
- Real-time and RPC enabled

### 5. **AI Agents** (Agent Registry)
- Read/write access to agent repository
- Function execution enabled
- Schemas: agent_repository, agentic, knowledge

## Security Model

### Default Deny Policy
```json
{
  "filesystem": "deny",
  "network": "deny", 
  "execute": "deny"
}
```

### Security Guards
1. **Server Access Control** - Whitelist of allowed servers
2. **Action Validation** - Blocked actions: execute, drop, truncate
3. **Schema Protection** - Sensitive schemas: auth, private, secrets
4. **Payload Size Limits** - Max 10MB per request
5. **Query Validation** - Dangerous SQL pattern detection
6. **Sensitive Data Detection** - API keys, passwords, tokens

### Audit Logging
- All requests logged with metadata
- Blocked operations tracked
- Security reports generated on demand

## Setup Instructions

### 1. Configure Environment

```bash
# Copy template
cp mcp/config/.env.mcp.example mcp/config/.env.mcp

# Edit with your credentials
vim mcp/config/.env.mcp
```

Required variables:
- `CONTEXT7_API_KEY` - From context7.ai dashboard
- `SUPABASE_PROJECT_REF` - Your Supabase project reference
- `SUPABASE_ACCESS_TOKEN` - Personal access token from Supabase

### 2. Initialize MCP

```bash
./mcp/bin/init-mcp.sh
```

This will:
- Validate configuration
- Test connectivity
- Create audit directories
- Link to Claude Desktop
- Generate security report

### 3. Claude Desktop Integration

The configuration is automatically linked to:
```
~/.claude/mcp-servers.json
```

Restart Claude Desktop to load the servers.

### 4. Claude Code CLI Integration

```bash
# List available servers
claude mcp list

# Add specific server
claude mcp add scout_analytics -c mcp/config/mcp-servers.json
```

## Usage Examples

### Query Scout Analytics
```sql
-- Via Claude with scout_analytics server
SELECT 
  brand_name,
  market_share,
  growth_rate
FROM scout.gold_brand_performance
WHERE region = 'NCR'
  AND period = '2024-Q1';
```

### Use Context7 for Documentation
```
"Using Context7, show me the latest Next.js 14 app router patterns"
```

### Agent Registry Operations
```typescript
// Via ai_agents server
const agent = await createAgent({
  name: 'DataProcessor',
  type: 'etl',
  capabilities: ['transform', 'validate']
});
```

## Security Best Practices

1. **Never expose service role keys** - Use personal access tokens
2. **Rotate tokens regularly** - Every 7 days recommended
3. **Use read-only mode** - Unless write is absolutely necessary
4. **Monitor audit logs** - Check `mcp/logs/` regularly
5. **Validate queries** - Always use parameterized queries
6. **Limit schema access** - Only expose necessary schemas

## Troubleshooting

### Connection Issues
```bash
# Test Context7
context7-mcp --test

# Test Supabase
npx @supabase/mcp-server-supabase@latest --version

# Check logs
tail -f /tmp/mcp/logs/audit.log
```

### Permission Denied
1. Check server whitelist in security policy
2. Verify action is not in denied list
3. Ensure schema is not sensitive
4. Review audit log for details

### Rate Limiting
- Default: 100 req/min, 3000 req/hour
- Implement exponential backoff
- Use request batching where possible

## Monitoring

### Generate Security Report
```typescript
import { mcpGuard } from './guards/mcp-security-guard';
console.log(mcpGuard.generateSecurityReport());
```

### View Audit Log
```typescript
import { mcpInterceptor } from './middleware/mcp-interceptor';
const requests = mcpInterceptor.getRequestLog();
```

### Health Check
```bash
./mcp/bin/health-check.sh
```

## Development

### Adding New Server

1. Update `mcp-servers.json`:
```json
"new_server": {
  "command": "...",
  "args": [...],
  "env": {...},
  "permissions": {...}
}
```

2. Add to security whitelist:
```typescript
// mcp/guards/mcp-security-guard.ts
allowedServers: [...existing, 'new_server']
```

3. Test configuration:
```bash
./mcp/bin/init-mcp.sh
```

### Custom Security Policy

Create `mcp/config/security-policy.json`:
```json
{
  "allowedServers": ["custom_list"],
  "deniedActions": ["custom_denied"],
  "sensitiveSchemas": ["custom_sensitive"],
  "maxPayloadSize": 5242880
}
```

## Maintenance

- Review security reports weekly
- Update Context7 allowed frameworks monthly
- Rotate all tokens quarterly
- Audit server usage patterns
- Clean old audit logs (>30 days)