#!/bin/bash

# Scout Edge Ingest - Quick Test Script
# Usage: ./test-curl.sh

# Check if environment variables are set
if [ -z "$SUPABASE_ANON_KEY" ]; then
    echo "Error: SUPABASE_ANON_KEY environment variable not set"
    echo "Please run: export SUPABASE_ANON_KEY='your-anon-key'"
    exit 1
fi

# Set the function URL (update with your project reference)
FUNC="${SUPABASE_FUNC_URL:-https://your-project-ref.functions.supabase.co/scout-edge-ingest}"

echo "Testing Scout Edge Ingest at: $FUNC"
echo "Using auth key: ${SUPABASE_ANON_KEY:0:20}..."
echo ""

# Test with golden fixture
echo "Testing with golden fixture..."
curl -sS -X POST "$FUNC" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  --data-binary @../fixtures/golden.json | jq .

echo ""
echo "Test complete!"