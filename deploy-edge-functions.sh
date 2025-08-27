#!/bin/bash
set -euo pipefail

echo "🚀 Deploying Scout Semantic Layer Edge Functions..."

# Check if Supabase CLI is available
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Please install it first:"
    echo "npm install -g supabase"
    exit 1
fi

# Check for required environment variables
if [ -z "${SUPABASE_ACCESS_TOKEN:-}" ]; then
    echo "❌ SUPABASE_ACCESS_TOKEN environment variable is required"
    echo "Please set it with your Supabase Personal Access Token"
    exit 1
fi

if [ -z "${SUPABASE_PROJECT_REF:-}" ]; then
    echo "ℹ️  Using default project ref: cxzllzyxwpyptfretryc"
    export SUPABASE_PROJECT_REF="cxzllzyxwpyptfretryc"
fi

echo "🔐 Logging in to Supabase..."
supabase login --token "${SUPABASE_ACCESS_TOKEN}"

echo "🔗 Linking to project ${SUPABASE_PROJECT_REF}..."
supabase link --project-ref "${SUPABASE_PROJECT_REF}"

echo "📦 Deploying semantic-proxy function..."
supabase functions deploy semantic-proxy --no-verify-jwt

echo "📦 Deploying semantic-calc function..."
supabase functions deploy semantic-calc --no-verify-jwt

echo "📦 Deploying semantic-suggest function..."
supabase functions deploy semantic-suggest --no-verify-jwt

echo "✅ All Edge Functions deployed successfully!"
echo ""
echo "🔍 Verify deployment:"
echo "- semantic-proxy:   POST ${SUPABASE_URL}/functions/v1/semantic-proxy"
echo "- semantic-calc:    POST ${SUPABASE_URL}/functions/v1/semantic-calc" 
echo "- semantic-suggest: GET  ${SUPABASE_URL}/functions/v1/semantic-suggest"
echo ""
echo "⚠️  Note: Functions deployed with --no-verify-jwt for testing"
echo "   Remove this flag for production deployment"