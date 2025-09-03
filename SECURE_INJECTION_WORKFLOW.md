# Secure Secret Injection Workflow

This document outlines the secure pattern for environment variable management and secret injection in the Scout Analytics platform.

## 🎯 Overview

The secure workflow follows this pattern:
1. **Claude orchestrates** actions but never reads secrets directly
2. **Bruno resolves** secrets from secure storage (keychain/vault)
3. **Environment is injected** securely at runtime
4. **MCP wrappers execute** with the injected environment
5. **No secrets are committed** to version control

## 📁 Environment Template Structure

All environment templates are already in place:

### Root Templates
- `.env.example` - Global/CLI configuration
- `ci/.env.ci.example` - CI/CD configuration
- `mcp/config/.env.mcp.example` - MCP server configuration

### Component Templates
- `apps/scout-dashboard/.env.local.example` - Next.js application
- `supabase/.env.local.example` - Edge Functions
- `services/mm-scorer/.env.example` - MM-Scorer service
- `docs/.env.example` - Documentation build

## 🔐 Security Measures

### Git Protection
- `.gitignore` properly excludes all actual environment files:
  - `.env`
  - `.env.*` 
  - `*.local`
- Template files (`.example`) are safe to commit
- Actual secret files are never committed

### Secret Injection Pattern
```bash
# Secure workflow (Bruno handles secrets)
:bruno inject --tokens gh,supabase,vercel
export $(bruno env)  # Bruno injects into environment
./scripts/supabase_scout_mcp.sh  # MCP wrapper uses injected env
```

## 🛠️ MCP Wrapper Scripts

Created secure wrapper scripts that expect environment injection:

### `scripts/supabase_scout_mcp.sh`
- Validates Supabase environment variables
- Tests database connections
- Starts MCP server with secure environment

### `scripts/memory_bridge.sh` 
- Validates model API keys (OpenAI, Anthropic, DeepSeek)
- Tests Supabase connections for persistence
- Starts memory bridge MCP server

### `scripts/demo_bruno_injection.sh`
- Demonstration of the complete secure workflow
- Simulates Bruno secret resolution and injection
- Shows environment validation and MCP startup

## 🗝️ Required Secrets for Bruno

Bruno should have these secrets in your keychain/vault:

### GitHub
- `GH_TOKEN` - Fine-grained PAT with `repo` and `workflow` scopes

### Supabase
- `SUPABASE_ACCESS_TOKEN` - CLI personal access token
- `SUPABASE_ANON_KEY` - Browser/client access
- `SUPABASE_SERVICE_ROLE_KEY` - Server-only (never expose to browser)
- `SUPABASE_JWT_SECRET` - For JWT minting/verification

### Vercel
- `VERCEL_TOKEN` - Vercel CLI token
- `VERCEL_ORG_ID` - Organization ID
- `VERCEL_PROJECT_ID_DASHBOARD` - Dashboard project ID
- `VERCEL_PROJECT_ID_DOCS` - Docs project ID

### Model Providers (Optional)
- `OPENAI_API_KEY` - OpenAI API key
- `ANTHROPIC_API_KEY` - Anthropic API key  
- `DEEPSEEK_API_KEY` - DeepSeek API key

## 🚀 Usage Workflow

### Local Development
```bash
# Bruno resolves and injects secrets
:bruno inject --tokens supabase,github

# Environment is now available for MCP wrappers
./scripts/supabase_scout_mcp.sh
./scripts/memory_bridge.sh
```

### CI/CD Pipeline
```yaml
# GitHub Actions - use built-in secrets
env:
  SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
  SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
  # ... other secrets

# PR_TARGET jobs - no secrets, read-only
permissions:
  contents: read
persist-credentials: false
```

### Production Deployment
- Vercel: Set environment variables in project settings
- Supabase Functions: Use Supabase Dashboard secrets
- Never mark service role keys as public in Vercel

## ✅ Validation Checklist

- [ ] All secrets stored in Bruno/keychain with correct names
- [ ] MCP wrappers start when required environment variables are present
- [ ] CI secrets configured in GitHub Actions
- [ ] Branch protections don't require Vercel preview on PR branches
- [ ] `pull_request_target` jobs use `permissions: contents: read`
- [ ] No secrets committed to version control
- [ ] Service role keys never exposed to client-side code

## 🎯 Next Steps

1. **Store actual secrets** in your keychain/vault with the names above
2. **Test Bruno integration** with your actual secret storage
3. **Complete MCP server implementations** in `mcp/servers/`
4. **Configure CI/CD** with GitHub Actions secrets
5. **Deploy to production** with proper environment separation

## 🔒 Security Rules

- **Never** expose `SUPABASE_SERVICE_ROLE_KEY` to browser
- **Never** commit actual `.env` files to git
- **Always** use Bruno/keychain for secret resolution
- **Validate** environment before MCP startup
- **Separate** projects for dashboard and docs in Vercel

This secure pattern ensures that Claude can orchestrate actions without ever accessing sensitive credentials directly, while Bruno handles the secure secret injection following best practices.
