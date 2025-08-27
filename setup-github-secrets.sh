#!/usr/bin/env bash
set -euo pipefail

echo "🔐 GitHub Secrets Setup for AI AAS Hardened Lakehouse"
echo "======================================================"

# Ensure we're in the right directory
cd /Users/tbwa/ai-aas-hardened-lakehouse

# Verify GitHub CLI auth
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ Not authenticated with GitHub CLI. Run: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI authenticated"

# Function to set secret with confirmation
set_secret() {
    local secret_name="$1"
    local prompt="$2"
    local is_secret="${3:-true}"
    
    echo ""
    echo "Setting $secret_name..."
    echo "$prompt"
    
    if [ "$is_secret" = "true" ]; then
        read -s -p "Enter value (hidden): " secret_value
        echo ""
    else
        read -p "Enter value: " secret_value
    fi
    
    if [ -n "$secret_value" ]; then
        gh secret set "$secret_name" -b"$secret_value"
        echo "✅ $secret_name set successfully"
    else
        echo "⚠️  Skipping $secret_name (empty value)"
    fi
}

echo ""
echo "🔑 Setting up Supabase secrets..."

# Supabase Access Token (PAT)
set_secret "SUPABASE_ACCESS_TOKEN" \
    "Supabase Personal Access Token (from https://app.supabase.com/account/tokens)" \
    true

# Supabase Project Reference  
set_secret "SUPABASE_PROJECT_REF" \
    "Supabase Project Reference (e.g., cxzllzyxwpyptfretryc)" \
    false

# Supabase Database URL
set_secret "SUPABASE_DB_URL" \
    "Full Supabase Database URL (postgres://...)" \
    true

# Supabase Service Role Key
set_secret "SUPABASE_SERVICE_ROLE_KEY" \
    "Supabase Service Role Key (for admin operations)" \
    true

# Supabase Anon Key
set_secret "SUPABASE_ANON_KEY" \
    "Supabase Anonymous Key (for public access)" \
    true

echo ""
echo "📦 Setting up Vercel secrets (optional)..."

read -p "Do you want to configure Vercel deployment secrets? (y/N): " configure_vercel
if [[ "$configure_vercel" =~ ^[Yy]$ ]]; then
    set_secret "VERCEL_TOKEN" \
        "Vercel API Token (from https://vercel.com/account/tokens)" \
        true
    
    set_secret "VERCEL_ORG_ID" \
        "Vercel Organization ID" \
        false
    
    set_secret "VERCEL_PROJECT_ID_SCOUT_DASHBOARD" \
        "Vercel Project ID for Scout Dashboard" \
        false
    
    set_secret "VERCEL_PROJECT_ID_SCOUT_UI" \
        "Vercel Project ID for Scout UI" \
        false
fi

echo ""
echo "🌍 Setting up environment variables..."

# Set non-secret variables
gh variable set REGION -b"ap-southeast-1"
gh variable set SB_SCHEMA -b"scout"
echo "✅ Variables set: REGION, SB_SCHEMA"

echo ""
echo "📋 Verifying secrets and variables..."

echo ""
echo "📝 Repository Secrets:"
gh secret list

echo ""
echo "📝 Repository Variables:"  
gh variable list

echo ""
echo "🎉 GitHub secrets setup complete!"
echo ""
echo "Next steps:"
echo "1. Check workflow runs: gh run list --limit 5"
echo "2. Re-run failed checks: gh run rerun <RUN_ID> --failed"
echo "3. Monitor deployment status in GitHub Actions"