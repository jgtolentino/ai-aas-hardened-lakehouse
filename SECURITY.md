# 🔒 Security Guidelines

> **⚠️ CRITICAL**: This repository previously contained exposed Supabase tokens. All tokens have been rotated and git history purged.

## 🚨 Never Commit These

- `sbp_*` - Supabase Personal Access Tokens
- `eyJ*.*.*` - JWT tokens (service role, anon keys)
- Database passwords or connection strings with credentials
- API keys, webhooks secrets, or private keys
- `.env` files with real values

## ✅ Safe Practices

### Environment Variables
```bash
# ✅ Good - Use environment variables
export SUPABASE_ACCESS_TOKEN="your-token-here"
export MCP_DB_PASSWORD="your-db-password"

# ❌ Bad - Never in code
const token = "sbp_abc123..."
```

### MCP Configuration
```json
// ✅ Good - Placeholder in repo
{
  "mcpServers": {
    "postgres_readonly": {
      "args": ["postgresql://mcp_reader:${MCP_DB_PASSWORD}@..."]
    }
  }
}

// ❌ Bad - Live token in repo
{
  "env": {
    "SUPABASE_ACCESS_TOKEN": "sbp_abc123..."
  }
}
```

## 🛡️ Security Features Enabled

### Automated Scanning
- **Pre-commit hooks**: Block secrets before they're committed
- **GitHub Actions**: Scan every PR with Gitleaks
- **Custom patterns**: Detect Supabase/JWT tokens specifically

### Database Security
- **Read-only role**: MCP uses `mcp_reader` role with SELECT-only privileges
- **No service role**: Never expose `service_role` to external tools
- **Row Level Security**: Remains enforced on all sensitive tables

### Secret Management
- **GitHub Secrets**: Store production secrets in repository settings
- **Environment isolation**: Development vs production token separation
- **Token rotation**: Regular rotation of all access tokens

## 🚀 Developer Setup

### Local MCP Configuration
```bash
# Set environment variables (never commit these)
export SUPABASE_PROJECT_REF=cxzllzyxwpyptfretryc
export MCP_DB_PASSWORD="your-strong-password-here"

# Add MCP server locally (safe)
claude mcp add postgres_readonly -- npx -y @modelcontextprotocol/server-postgres@latest \
  "postgresql://mcp_reader:${MCP_DB_PASSWORD}@db.${SUPABASE_PROJECT_REF}.supabase.co:5432/postgres"
```

### Installing Security Tools
```bash
# Install pre-commit hook
./scripts/security/install_pre_commit_hook.sh

# Scan existing repository
docker run --rm -v "$(pwd):/path" zricethezav/gitleaks:latest detect -s /path
```

## 🆘 Incident Response

### If Secrets Are Exposed
1. **Immediate**: Revoke/rotate all exposed tokens in Supabase dashboard
2. **Git**: Run `./scripts/security/purge_secrets_from_git.sh`
3. **CI/CD**: Update all GitHub Secrets and redeploy environments
4. **Team**: Notify all contributors to re-clone repository

### Recovery Checklist
- [ ] Tokens revoked in Supabase (Account → Tokens)
- [ ] Service/Anon keys regenerated (Project → Settings → API)
- [ ] Git history purged and force-pushed
- [ ] GitHub repository secrets updated
- [ ] All environments redeployed with new secrets
- [ ] Team notified to re-clone

## 📞 Contact

For security concerns or incidents:
- Create private issue in repository
- Tag security team members
- Follow responsible disclosure practices

---

> **Remember**: Security is everyone's responsibility. When in doubt, ask!