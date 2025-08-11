#!/bin/bash

# Deploy Superset JWT Proxy to Supabase Edge Functions
# This script automates the deployment and configuration

set -e

echo "🚀 Deploying Superset JWT Proxy..."
echo "=================================="

# Check if supabase CLI is available
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Install from: https://supabase.com/docs/guides/cli"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "supabase/config.toml" ]; then
    echo "❌ Not in a Supabase project directory. Run from project root."
    exit 1
fi

# Deploy the function
echo "📦 Deploying superset-jwt-proxy function..."
supabase functions deploy superset-jwt-proxy

if [ $? -eq 0 ]; then
    echo "✅ Function deployed successfully"
else
    echo "❌ Function deployment failed"
    exit 1
fi

# Set environment variables
echo ""
echo "🔧 Configuring environment variables..."

# Prompt for required variables if not set
if [ -z "$SUPERSET_URL" ]; then
    read -p "Enter Superset URL (e.g., http://localhost:8088): " SUPERSET_URL
fi

if [ -z "$SUPERSET_USERNAME" ]; then
    read -p "Enter Superset username (default: admin): " SUPERSET_USERNAME
    SUPERSET_USERNAME=${SUPERSET_USERNAME:-admin}
fi

if [ -z "$SUPERSET_PASSWORD" ]; then
    read -s -p "Enter Superset password: " SUPERSET_PASSWORD
    echo
fi

if [ -z "$SUPERSET_JWT_SECRET" ]; then
    # Generate a random JWT secret if not provided
    SUPERSET_JWT_SECRET=$(openssl rand -base64 32)
    echo "Generated JWT secret: $SUPERSET_JWT_SECRET"
fi

if [ -z "$LOVABLE_APP_URL" ]; then
    read -p "Enter Lovable app URL (e.g., https://your-app.lovable.app): " LOVABLE_APP_URL
fi

if [ -z "$LOVABLE_JWT_SECRET" ]; then
    # Generate a random JWT secret for Lovable if not provided
    LOVABLE_JWT_SECRET=$(openssl rand -base64 32)
    echo "Generated Lovable JWT secret: $LOVABLE_JWT_SECRET"
fi

# Set the secrets
echo "Setting environment variables..."

supabase secrets set SUPERSET_URL="$SUPERSET_URL"
supabase secrets set SUPERSET_USERNAME="$SUPERSET_USERNAME"
supabase secrets set SUPERSET_PASSWORD="$SUPERSET_PASSWORD"
supabase secrets set SUPERSET_JWT_SECRET="$SUPERSET_JWT_SECRET"
supabase secrets set SUPERSET_DB_ID="1"
supabase secrets set LOVABLE_APP_URL="$LOVABLE_APP_URL"
supabase secrets set LOVABLE_JWT_SECRET="$LOVABLE_JWT_SECRET"

echo "✅ Environment variables configured"

# Test the deployment
echo ""
echo "🧪 Testing deployment..."

FUNCTION_URL="https://$(supabase status | grep 'API URL' | awk '{print $3}' | sed 's|https://||')/functions/v1/superset-jwt-proxy"

# Generate a test JWT token
TEST_JWT=$(node -e "
const jwt = require('jsonwebtoken');
const token = jwt.sign(
  { iss: 'lovable-app', sub: 'test', exp: Math.floor(Date.now() / 1000) + 60 },
  '$LOVABLE_JWT_SECRET'
);
console.log(token);
")

# Test health endpoint
echo "Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s -H "Authorization: Bearer $TEST_JWT" "$FUNCTION_URL/health" || echo "failed")

if [[ $HEALTH_RESPONSE == *"healthy"* ]]; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed: $HEALTH_RESPONSE"
fi

echo ""
echo "🎉 Deployment Summary"
echo "===================="
echo "Function URL: $FUNCTION_URL"
echo "Superset URL: $SUPERSET_URL"
echo "Lovable App URL: $LOVABLE_APP_URL"
echo ""
echo "📋 Next Steps:"
echo "1. Copy the LOVABLE_JWT_SECRET to your Lovable app environment:"
echo "   VITE_LOVABLE_JWT_SECRET=$LOVABLE_JWT_SECRET"
echo ""
echo "2. Add the proxy URL to your Lovable app:"
echo "   VITE_SUPERSET_PROXY_URL=$FUNCTION_URL"
echo ""
echo "3. Install the SupersetClient in your Lovable app:"
echo "   cp packages/shared-types/superset-client.ts src/lib/"
echo ""
echo "4. Test the integration using the provided React components"
echo ""
echo "📖 Full documentation: docs/SUPERSET_LOVABLE_INTEGRATION.md"