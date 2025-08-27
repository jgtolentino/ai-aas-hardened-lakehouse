#!/usr/bin/env bash
set -euo pipefail

echo "🔑 Adding SUPABASE_ACCESS_TOKEN"
echo "==============================="

cd /Users/tbwa/ai-aas-hardened-lakehouse

# Clear any GITHUB_TOKEN env var to use proper keyring token
unset GITHUB_TOKEN 2>/dev/null || true

echo "Enter your Supabase Personal Access Token (PAT):"
echo "Get it from: https://app.supabase.com/account/tokens"
echo ""
read -s -p "Supabase PAT: " ACCESS_TOKEN
echo ""

if [ -n "$ACCESS_TOKEN" ]; then
    gh secret set SUPABASE_ACCESS_TOKEN -b"$ACCESS_TOKEN"
    echo "✅ SUPABASE_ACCESS_TOKEN set successfully"
else
    echo "❌ Empty token provided"
    exit 1
fi

echo ""
echo "📋 All current secrets:"
gh secret list

echo ""
echo "🔄 Re-running latest failed workflow..."
LATEST_RUN=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
gh run rerun "$LATEST_RUN" --failed

echo ""
echo "✅ Access token configured and workflow re-triggered!"