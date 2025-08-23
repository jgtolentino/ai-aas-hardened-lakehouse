# GitHub MCP Quick Reference Card

## 🚀 One-Time Setup

```bash
# 1. Store PAT in Keychain
read -s -p "Paste GitHub PAT: " PAT; echo
security add-generic-password -a "$USER" -s GITHUB_PAT -w "$PAT" -U

# 2. Create launcher
mkdir -p ~/bin
cat > ~/bin/mcp-github.sh <<'EOF'
#!/usr/bin/env bash
export GITHUB_TOKEN="$(security find-generic-password -s GITHUB_PAT -w)"
exec docker run -i --rm -e GITHUB_TOKEN ghcr.io/model-context-protocol/github:latest
EOF
chmod +x ~/bin/mcp-github.sh

# 3. Register MCP server
mkdir -p ~/.mcp
echo '{"github":{"command":"~/bin/mcp-github.sh","args":[]}}' > ~/.mcp/mcp.json
```

## 📋 Common Commands

### Quick Actions
```bash
# Load macros
source scripts/github-mcp-macros.sh

# Run workflows
gh-todos        # Convert TODOs to issues
gh-prs          # PR dashboard
gh-triage       # Bug triage
gh-ci           # CI failures to issues
gh-metrics      # Weekly report
gh-security     # Security audit
gh-menu         # Interactive menu
```

### Direct Claude Commands

**Discover Tools:**
```
"List all GitHub MCP tools available"
```

**TODO → Issues:**
```
"Scan for TODO/FIXME markers and create GitHub issues with 'tech-debt' label"
```

**PR Summary:**
```
"Show all open PRs with reviewers and status"
```

**Data Quality Issues:**
```
"Check Suqi Chat performance metrics and create issues if p95 > 2000ms"
```

## 🔧 Troubleshooting

```bash
# Check token
security find-generic-password -s GITHUB_PAT -w

# Test MCP server
~/bin/mcp-github.sh </dev/null | head -5

# Verify repo context
git remote get-url origin

# Check token scopes
curl -H "Authorization: token $(security find-generic-password -s GITHUB_PAT -w)" \
  https://api.github.com/user -I | grep X-OAuth-Scopes
```

## 🔒 Security

```bash
# Rotate token (every 60-90 days)
security delete-generic-password -s GITHUB_PAT

# Scan for leaks
grep -R "ghp_" . --exclude-dir=.git

# Minimal scopes needed:
# - Issues: Read/Write
# - Metadata: Read
# - Pull Requests: Read (optional)
```

## 📊 Lakehouse-Specific Workflows

**Monitor Data Pipeline:**
```
"Check dbt run logs for failures and create issues for each failed model"
```

**Track AI Performance:**
```
"Monitor Suqi Chat metrics: if cache hit rate < 30% or p95 > 2s, create P1 issue"
```

**Quality Gates:**
```
"Run Great Expectations validations and create issues for critical failures"
```

## 🎯 Pro Tips

1. **Always run in repo directory** - MCP uses CWD to determine repository
2. **Use labels consistently** - Helps with automation and filtering
3. **Link related issues** - Use epic management commands
4. **Batch operations** - Group similar TODOs into single issues
5. **Monitor rate limits** - GitHub API has hourly limits

## 🔗 Resources

- [Full Integration Guide](./MCP_GITHUB_INTEGRATION.md)
- [Workflow Macros](../scripts/github-mcp-macros.sh)
- [AI Orchestration Guide](./AI_ORCHESTRATION_GUIDE.md)
- [Suqi Chat Documentation](./SUQI_CHAT_GUIDE.md)