#!/bin/bash
set -e

echo "Scout Edge Ingest Deployment Script"
echo "==================================="

# Check environment variables
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ] || [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
    echo "Error: Missing required environment variables"
    echo "Please set: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY"
    exit 1
fi

# Deploy SQL schema
echo "1. Creating Gold tables..."
if [ -n "$POSTGRES_URL" ]; then
    psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 -f sql/init_gold.sql
    echo "✓ Gold tables created"
else
    echo "⚠ POSTGRES_URL not set - skipping SQL deployment"
fi

# Deploy Edge Function
echo "2. Deploying Edge Function..."
PROJECT_REF=$(echo "$SUPABASE_URL" | sed -E 's|https://([^.]+)\.supabase\.co.*|\1|')
echo "   Project: $PROJECT_REF"

# Set secrets
supabase secrets set --project-ref "$PROJECT_REF" \
    SUPABASE_URL="$SUPABASE_URL" \
    SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SERVICE_ROLE_KEY"

# Deploy function
supabase functions deploy scout-edge-ingest --project-ref "$PROJECT_REF"
echo "✓ Edge function deployed"

# Test with golden fixture
echo "3. Testing with golden fixture..."
FUNC_URL="https://${PROJECT_REF}.supabase.co/functions/v1/scout-edge-ingest"
RESPONSE=$(curl -sS -X POST "$FUNC_URL" \
    -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
    -H "Content-Type: application/json" \
    --data-binary @fixtures/golden.json)

if echo "$RESPONSE" | jq -e '.ok' > /dev/null 2>&1; then
    echo "✓ Golden fixture test passed"
else
    echo "✗ Golden fixture test failed:"
    echo "$RESPONSE" | jq .
    exit 1
fi

echo ""
echo "Deployment complete!"
echo "Edge function URL: $FUNC_URL"