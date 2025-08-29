# 🚀 Team Onboarding Quick Start - 5 Minutes to Production

## ⚡ Overview
Get any team member from zero to fully operational with enterprise-grade secret management and zero-click automation in under 5 minutes.

## 🎯 Pre-Requisites (Install Once)
```bash
# Install Bruno CLI
brew install bruno-cli

# Or download Bruno GUI
# https://www.usebruno.com/downloads
```

## 🏃‍♂️ 5-Minute Setup

### Step 1: Clone & Diagnose (1 minute)
```bash
# Clone the repo
git clone <repo-url>
cd <repo-name>

# Run diagnostic - shows exactly what's missing
./diagnose-mcp-secrets
```

**Expected Output:**
```
🔍 DIAGNOSIS COMPLETE - Here's what needs attention:

❌ GITHUB_TOKEN - Missing from Bruno vault
❌ SUPABASE_ACCESS_TOKEN - Missing from Bruno vault  
❌ SUPABASE_SERVICE_ROLE_KEY - Missing from Bruno vault
❌ FIGMA_ACCESS_TOKEN - Missing from Bruno vault

📋 COPY THESE COMMANDS TO FIX:
:bruno env:set GITHUB_TOKEN "your_token_here"
:bruno env:set SUPABASE_ACCESS_TOKEN "your_token_here"
:bruno env:set SUPABASE_SERVICE_ROLE_KEY "your_token_here"
:bruno env:set FIGMA_ACCESS_TOKEN "your_token_here"
```

### Step 2: Bruno Vault Setup (2 minutes)

**Option A: Bruno CLI (Faster)**
```bash
# Set secrets directly via CLI
bruno env:set GITHUB_TOKEN "ghp_your_personal_access_token_here"
bruno env:set SUPABASE_ACCESS_TOKEN "sbp_your_supabase_token_here"
bruno env:set SUPABASE_SERVICE_ROLE_KEY "your_service_role_key_here"
bruno env:set FIGMA_ACCESS_TOKEN "figd_your_figma_token_here"
```

**Option B: Bruno GUI (Visual)**
1. Open Bruno GUI
2. Navigate to project collection
3. Go to Environments > Add variables
4. Paste the tokens from your secure notes

### Step 3: Inject & Verify (1 minute)
```bash
# Auto-inject secrets from Bruno vault
./fix-injection-and-export

# Verify all APIs work
./verify-live-apis
```

**Expected Output:**
```
✅ GitHub API - 200 OK (Rate limit: 4,823/5,000)
✅ Supabase API - 200 OK (Project: active)
✅ Figma API - 200 OK (Teams: 3 accessible)

🎉 ALL SYSTEMS OPERATIONAL
```

### Step 4: Claude Configuration (30 seconds)
```bash
# Generate Claude Desktop MCP configuration
./write-claude-mcp-config

# Restart Claude Desktop (close and reopen)
```

### Step 5: Test Zero-Click Automation (30 seconds)
```bash
# Execute complete automation workflow
./retarget-dashboard.sh "executive kpi" "TBWA"
```

**Expected Output:**
```
[INFO] Starting zero-click dashboard retargeting
[INFO] Query: executive kpi
[INFO] Brand: TBWA
[SUCCESS] Found design: Executive KPI Dashboard
[SUCCESS] Brand patch applied successfully
[SUCCESS] Design exported to: ./output/TBWA-dashboard-20241219-143022.png
[SUCCESS] Zero-click retargeting complete!
```

---

## 🛠️ Token Generation Guide

### GitHub Personal Access Token
1. Go to [GitHub Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens)
2. Generate new token (classic)
3. Select scopes: `repo`, `workflow`, `read:org`, `read:user`
4. Copy token (starts with `ghp_`)

### Supabase Access Token  
1. Go to [Supabase Dashboard > Account > Access Tokens](https://app.supabase.com/account/tokens)
2. Create new token
3. Copy token (starts with `sbp_`)

### Supabase Service Role Key
1. Go to your Supabase project settings
2. API section > Project API keys
3. Copy "service_role" key (long JWT token)

### Figma Access Token
1. Go to [Figma Settings > Personal access tokens](https://www.figma.com/settings)
2. Generate new token
3. Copy token (starts with `figd_`)

---

## 🚨 Troubleshooting

### "Bruno command not found"
```bash
# Install Bruno CLI
npm install -g @usebruno/cli
```

### "Scripts not executable"
```bash
# Make scripts executable
chmod +x diagnose-mcp-secrets fix-injection-and-export verify-live-apis write-claude-mcp-config
```

### "MCP servers not showing in Claude"
1. Ensure Claude Desktop is completely closed
2. Run `./write-claude-mcp-config` 
3. Restart Claude Desktop
4. Wait 30 seconds for MCP servers to initialize

### "API calls returning 401"
1. Check token validity: `./verify-live-apis`
2. Regenerate tokens if expired
3. Update Bruno vault with new tokens
4. Re-run `./fix-injection-and-export`

---

## ✅ Success Verification

After setup, verify everything works:

```bash
# 1. Secrets properly injected
ls -la .env*
# Should show .env with 600 permissions

# 2. APIs responding
./verify-live-apis  
# Should show all green checkmarks

# 3. Claude MCP operational
# Ask Claude: "List my GitHub repositories"
# Should return actual repo list

# 4. Zero-click automation working
./retarget-dashboard.sh "dashboard" "TestBrand"
# Should complete without errors
```

---

## 🎯 Daily Usage

### Morning Routine (10 seconds)
```bash
./diagnose-mcp-secrets
# If any issues, run: ./fix-injection-and-export
```

### Before Commits (5 seconds)  
```bash
git add .
gitleaks detect --source .
# Should show: "No leaks detected"
```

### Before Deployments (5 seconds)
```bash
./verify-live-apis
# All APIs should be green
```

---

## 🏆 You're Done!

**Congratulations!** You now have:

✅ **Enterprise-grade secret management** (no secrets in Git)  
✅ **Automated MCP server configuration** (GitHub + Supabase + Figma)  
✅ **Zero-click dashboard automation** (find → clone → modify → export)  
✅ **Production-ready CI/CD integration** (secure deployments)  

**Next Steps:**
- Join the team Slack channel: `#enterprise-automation`  
- Bookmark the [CI/CD Secrets Playbook](./CICD_SECRETS_PLAYBOOK.md)
- Start using zero-click automation for your projects!

---

**Questions?** Ping the team in Slack or check the full playbook documentation.