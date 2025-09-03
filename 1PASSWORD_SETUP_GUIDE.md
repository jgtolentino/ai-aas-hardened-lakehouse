# 1Password Secret Setup Guide

This guide explains how to store all required secrets in 1Password for secure access by Bruno and your MCP wrappers.

## 📋 Required Secrets for 1Password

Store these items in your 1Password vault with these exact field names:

### GitHub Token
- **Item Type**: API Credential
- **Title**: `GitHub Token - Scout Analytics`
- **Fields**:
  - `username`: Your GitHub username
  - `token`: `ghp_your_actual_token_here` (fine-grained PAT)
- **Notes**: Scopes: `repo`, `workflow` (limit to this repository)

### Supabase Secrets
- **Item Type**: API Credential  
- **Title**: `Supabase Credentials - Scout Analytics`
- **Fields**:
  - `SUPABASE_ANON_KEY`: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.your_anon_key`
  - `SUPABASE_SERVICE_ROLE_KEY`: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.your_service_key`
  - `SUPABASE_ACCESS_TOKEN`: `sbp_your_cli_pat`
  - `SUPABASE_JWT_SECRET`: `your_jwt_secret_value`
- **Notes**: Get these from Supabase Dashboard → Settings → API

### Vercel Tokens
- **Item Type**: API Credential
- **Title**: `Vercel Tokens - Scout Analytics`  
- **Fields**:
  - `VERCEL_TOKEN`: `your_vercel_cli_token`
  - `VERCEL_ORG_ID`: `team_your_org_id`
  - `VERCEL_PROJECT_ID_DASHBOARD`: `prj_your_dashboard_id`
  - `VERCEL_PROJECT_ID_DOCS`: `prj_your_docs_id`
- **Notes**: Get from Vercel Dashboard → Settings → Tokens

### Model API Keys (Optional)
- **Item Type**: API Credential
- **Title**: `AI Model Keys - Scout Analytics`
- **Fields**:
  - `OPENAI_API_KEY`: `sk-your-openai-key`
  - `ANTHROPIC_API_KEY`: `sk-ant-your-anthropic-key` 
  - `DEEPSEEK_API_KEY`: `your-deepseek-key`

## 🖥️ Using 1Password CLI (op)

### Installation
```bash
# Install 1Password CLI
brew install --cask 1password/tap/1password-cli

# Sign in to your account
op signin --account your-domain.1password.com
```

### Adding Secrets via CLI
```bash
# Create GitHub token item
op item create --category=API_CREDENTIAL \
  --vault="Personal" \
  --title="GitHub Token - Scout Analytics" \
  username="your_github_username" \
  token="ghp_your_actual_token"

# Create Supabase credentials item  
op item create --category=API_CREDENTIAL \
  --vault="Personal" \
  --title="Supabase Credentials - Scout Analytics" \
  SUPABASE_ANON_KEY="your_anon_key" \
  SUPABASE_SERVICE_ROLE_KEY="your_service_key" \
  SUPABASE_ACCESS_TOKEN="your_cli_pat" \
  SUPABASE_JWT_SECRET="your_jwt_secret"

# Add more items similarly...
```

### Retrieving Secrets via CLI
```bash
# Get GitHub token
export GH_TOKEN=$(op item get "GitHub Token - Scout Analytics" --field token)

# Get Supabase anon key  
export SUPABASE_ANON_KEY=$(op item get "Supabase Credentials - Scout Analytics" --field SUPABASE_ANON_KEY)

# Get all Supabase credentials at once
eval $(op item get "Supabase Credentials - Scout Analytics" --format json | jq -r '.fields[] | select(.value != null) | "export \(.label)=\(.value)"')
```

## 🖱️ Using 1Password GUI

### Manual Setup Steps:
1. Open 1Password application
2. Click "+" to create new item
3. Select "API Credential" as item type
4. Use the exact field names from above
5. Store in your preferred vault (e.g., "Personal")
6. Add appropriate tags like "scout-analytics", "api-keys"

### Recommended Folder Structure:
- Create a folder called "Scout Analytics"
- Store all related secrets in this folder
- Use consistent naming: "Service - Purpose - Environment"

## 🔧 Integration with Bruno

If Bruno supports 1Password integration:

```bash
# Bruno should be able to read from 1Password
# Configuration might look like:
bruno config set secret-provider=1password
bruno config set 1password-vault=Personal
bruno config set 1password-item="GitHub Token - Scout Analytics"

# Then Bruno can inject secrets:
bruno inject --from-1password
```

## 🧪 Testing Your Setup

### Test Secret Retrieval:
```bash
# Test retrieving one secret
op item get "GitHub Token - Scout Analytics" --field token

# Test retrieving multiple secrets
op item get "Supabase Credentials - Scout Analytics" --format json | jq '.fields[] | {label: .label, value: (.value | sub(".{10}$"; "..."))}'
```

### Test Environment Injection:
```bash
# Manual test of environment setup
export GH_TOKEN=$(op item get "GitHub Token - Scout Analytics" --field token)
export SUPABASE_ANON_KEY=$(op item get "Supabase Credentials - Scout Analytics" --field SUPABASE_ANON_KEY)

# Verify variables are set
echo "GH_TOKEN: ${GH_TOKEN:0:10}..."
echo "SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY:0:10}..."
```

## 🚨 Security Best Practices

1. **Use different items** for different environments (dev/staging/prod)
2. **Enable 2FA** on your 1Password account
3. **Use travel mode** if working on untrusted devices
4. **Regularly rotate** API tokens (every 90 days recommended)
5. **Restrict permissions** - give minimum required scopes
6. **Audit access** - review 1Password access logs regularly

## 🔄 Automation Script

Create a helper script for easy secret injection:

```bash
#!/bin/bash
# scripts/load-secrets-from-1password.sh

echo "Loading secrets from 1Password..."

# Load GitHub token
export GH_TOKEN=$(op item get "GitHub Token - Scout Analytics" --field token 2>/dev/null)

# Load Supabase secrets
export SUPABASE_ANON_KEY=$(op item get "Supabase Credentials - Scout Analytics" --field SUPABASE_ANON_KEY 2>/dev/null)
export SUPABASE_SERVICE_ROLE_KEY=$(op item get "Supabase Credentials - Scout Analytics" --field SUPABASE_SERVICE_ROLE_KEY 2>/dev/null)

echo "Secrets loaded successfully!"
```

Now you can source this script before running your MCP wrappers:

```bash
source scripts/load-secrets-from-1password.sh
./scripts/supabase_scout_mcp.sh
```

This setup ensures all secrets are securely stored in 1Password and injected at runtime without ever being committed to version control.
