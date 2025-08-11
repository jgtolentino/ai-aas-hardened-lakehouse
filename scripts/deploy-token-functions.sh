#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Deploying Token Management Edge Functions..."

# Check if supabase CLI is available
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Install with: npm install -g supabase"
    exit 1
fi

# Check if we're logged in
if ! supabase projects list &> /dev/null; then
    echo "❌ Not logged in to Supabase. Run: supabase login"
    exit 1
fi

# Create functions directory if it doesn't exist
mkdir -p supabase/functions/revoke-token
mkdir -p supabase/functions/validate-token

# Copy Edge Functions
echo "📋 Copying Edge Functions..."
cp scripts/revocation-edge-function.ts supabase/functions/revoke-token/index.ts
cp scripts/validate-token-edge-function.ts supabase/functions/validate-token/index.ts

# Deploy revocation function
echo "🔄 Deploying revoke-token function..."
supabase functions deploy revoke-token --no-verify-jwt

# Deploy validation function  
echo "🔄 Deploying validate-token function..."
supabase functions deploy validate-token --no-verify-jwt

# Set function secrets (if they don't exist)
echo "🔑 Setting function secrets..."
supabase secrets list | grep -q SUPABASE_SERVICE_ROLE_KEY || {
    echo "⚠️  SUPABASE_SERVICE_ROLE_KEY not found in secrets"
    echo "   Set it with: supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key"
}

supabase secrets list | grep -q SUPABASE_URL || {
    echo "⚠️  SUPABASE_URL not found in secrets"  
    echo "   Set it with: supabase secrets set SUPABASE_URL=https://your-project.supabase.co"
}

echo ""
echo "✅ Token Management Functions Deployed!"
echo ""
echo "📖 Usage:"
echo ""
echo "🔴 Revoke a token:"
echo "   curl -X POST https://your-project.supabase.co/functions/v1/revoke-token \\"
echo "     -H 'Authorization: Bearer YOUR_SERVICE_ROLE_KEY' \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"token\": \"eyJ...\", \"reason\": \"Security breach\"}'"
echo ""
echo "✅ Validate a token:"
echo "   curl https://your-project.supabase.co/functions/v1/validate-token \\"
echo "     -H 'Authorization: Bearer TOKEN_TO_VALIDATE'"
echo ""
echo "🔍 View functions:"
echo "   https://app.supabase.com/project/$(supabase projects list --output json | jq -r '.[0].id')/functions"