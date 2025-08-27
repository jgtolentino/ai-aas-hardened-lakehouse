#!/usr/bin/env bash
set -euo pipefail

echo "🔑 Adding missing SUPABASE_ACCESS_TOKEN to GitHub secrets"
echo "========================================================"

cd /Users/tbwa/ai-aas-hardened-lakehouse

# Clear any GITHUB_TOKEN env var to use proper keyring token
unset GITHUB_TOKEN 2>/dev/null || true

echo ""
echo "Current secrets:"
gh secret list

echo ""
echo "We need SUPABASE_ACCESS_TOKEN for CLI operations."
echo "Get your Personal Access Token from: https://app.supabase.com/account/tokens"
echo ""
read -s -p "Enter Supabase Personal Access Token: " ACCESS_TOKEN
echo ""

if [ -n "$ACCESS_TOKEN" ]; then
    gh secret set SUPABASE_ACCESS_TOKEN -b"$ACCESS_TOKEN"
    echo "✅ SUPABASE_ACCESS_TOKEN added successfully"
else
    echo "❌ Empty token provided"
    exit 1
fi

echo ""
echo "📋 Updated secrets list:"
gh secret list