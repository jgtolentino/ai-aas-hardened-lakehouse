# MCP Secret Injection System Guide

This guide covers the complete secret injection system for GitHub and Supabase MCP servers using Bruno as the single source of truth.

## Overview

The system provides a **diagnose → fix → verify** loop for both GitHub MCP and Supabase MCP with Bruno as the single source of truth.

## Files Created

### Core Scripts
- `diagnose-mcp-secrets` - Diagnostic script to check current state
- `fix-injection-and-export` - Auto-repair missing env vars from Bruno
- `verify-live-apis` - Validate tokens against real APIs
- `write-claude-mcp-config` - Harden Claude Desktop MCP config
- `minimal-github-app-token` - Optional GitHub App token helper

### MCP Server Files
- `tools/mcp/supabase-mcp.js` - Supabase MCP server implementation
- `tools/mcp/github-mcp.js` - GitHub MCP server implementation

## Usage Workflow

### 1. Run Diagnostics

```bash
cd /Users/tbwa/ai-aas-hardened-lakehouse
./diagnose-mcp-secrets
```

This will show:
- Current environment snapshot
- Local env file presence
- Expected secret keys
- Bruno vault presence check
- Runtime environment status
- Claude MCP config existence

### 2. Populate Bruno with Secrets

Use the `:bruno set-required-secrets` commands to populate missing keys:

```bash
# GitHub (choose ONE path)
# PAT path (simple):
:bruno env:set GITHUB_TOKEN "<ghp_xxx>"

# OR GitHub App path (preferred for automation):
:bruno env:set GITHUB_APP_ID "<app_id>"
:bruno env:set GITHUB_INSTALLATION_ID "<installation_id>"
:bruno env:set GITHUB_PRIVATE_KEY_PEM "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"

# Supabase (project)
:bruno env:set SUPABASE_URL "https://xxxxxxxxxxxx.supabase.co"
:bruno env:set SUPABASE_ANON_KEY "<public_anon>"
:bruno env:set SUPABASE_SERVICE_ROLE_KEY "<service_role_secret>"

# MCP-facing (kept separate on purpose)
:bruno env:set MCP_SUPABASE_URL "https://xxxxxxxxxxxx.supabase.co"
:bruno env:set MCP_SUPABASE_KEY "<service_or_restricted_key>"
```

### 3. Fix Injection and Export

```bash
./fix-injection-and-export
```

This will:
- Pull secrets from Bruno into current shell
- Write local dev .env files (no secrets committed)
- Create frontend-safe `.env.local` for scout-dashboard
- Create server-only `.env` with hardened permissions (0600)

### 4. Verify Live APIs

```bash
./verify-live-apis
```

This validates:
- GitHub authentication (PAT or App)
- Supabase anon key accessibility
- Supabase service role accessibility
- MCP Supabase key functionality

### 5. Write Claude MCP Config

```bash
./write-claude-mcp-config
```

Creates Claude Desktop MCP configuration with environment variable references (no plaintext secrets).

### 6. Restart Claude Desktop

After writing the config, restart Claude Desktop to pick up the new MCP server settings.

## MCP Server Features

### Supabase MCP
- **query_supabase**: Execute Supabase queries with filtering, sorting, limits
- **insert_supabase**: Insert data into Supabase tables
- **update_supabase**: Update data in Supabase tables

### GitHub MCP
- **get_repo_info**: Get repository information
- **list_repos**: List repositories for users/orgs
- **search_repos**: Search repositories
- **get_issues**: Get repository issues
- **create_issue**: Create new issues

## Security Considerations

### Key Separation
- `MCP_SUPABASE_KEY` should be a service-capable key if MCP does writes
- Frontend only gets anon keys via `.env.local`
- Service roles stay in root `.env` only

### File Permissions
- Root `.env` has 0600 permissions (read/write for owner only)
- Frontend `.env.local` contains only public/anonymous keys

### Bruno Integration
- All secrets are stored in Bruno vault
- Local files are generated from Bruno, not stored in git
- Environment variable references in Claude config prevent plaintext exposure

## Common Failure Modes

### Wrong Key in Claude MCP
- **Symptom**: MCP uses `MCP_SUPABASE_KEY` but gets 401/403 errors when writing
- **Fix**: Set a restricted service key for MCP, not the anon key

### GitHub App Without Tenant Approval
- **Symptom**: `installation_id` missing or wrong org
- **Fix**: Ensure App is installed to correct org/repo; use helper to mint installation token

### Local `.env` Drift
- **Symptom**: Frontend accidentally sees service role
- **Fix**: Keep service role only in root `.env`; FE only gets anon via `.env.local`

### Claude Desktop Caching
- **Symptom**: MCP settings not updating
- **Fix**: Restart Claude Desktop after writing `settings.json`

### Bruno Profile Mismatch
- **Symptom**: Secrets saved to non-default profile
- **Fix**: `export BRUNO_PROFILE=<expected>` before `:bruno env:set`

## Integration with Existing MCP Suite

The new MCP servers integrate with your existing MCP infrastructure:

- **Location**: `tools/mcp/` directory for server implementations
- **Configuration**: Claude Desktop MCP settings reference these files
- **Dependencies**: Uses `@modelcontextprotocol/sdk` and respective client libraries

## Next Steps

1. **Install Dependencies**: Ensure required npm packages are installed for MCP servers
2. **Test Integration**: Run the full workflow to verify end-to-end functionality
3. **CI Integration**: Consider adding these scripts to your CI pipeline for secret validation
4. **Monitoring**: Set up monitoring for MCP server health and token validity

## Support

For issues with this implementation, check:
1. Bruno vault connectivity and profile settings
2. Network connectivity to GitHub and Supabase APIs
3. Claude Desktop MCP configuration file permissions
4. Environment variable availability in your shell
