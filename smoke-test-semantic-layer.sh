#!/bin/bash
set -euo pipefail

echo "🧪 Running Scout v5.2 Semantic Layer Smoke Tests..."

# Set Supabase URL
SUPABASE_URL="https://cxzllzyxwpyptfretryc.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4emxsenlkd3B5cHRmcmV0cnljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjM2NDczNjQsImV4cCI6MjAzOTIyMzM2NH0.gTJXGSJhgTqsUrwgW2UO5U_YQ4nxQz6XGBKXHG3oRFk"

echo ""
echo "1️⃣ Testing semantic-proxy (RPC via Edge)..."
PROXY_RESPONSE=$(curl -s -X POST \
  "${SUPABASE_URL}/functions/v1/semantic-proxy" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "objects": ["Revenue", "Date"],
    "filters": {"date_range": "last_30_days"},
    "metrics": ["sum", "count"],
    "group_by": ["date"]
  }' || echo "ERROR")

if [[ $PROXY_RESPONSE == *"ERROR"* ]] || [[ $PROXY_RESPONSE == *"error"* ]]; then
  echo "❌ semantic-proxy test failed"
  echo "Response: $PROXY_RESPONSE"
else
  echo "✅ semantic-proxy responding"
  echo "Sample response: $(echo $PROXY_RESPONSE | jq -r '.data[0:2] // .message // "No data"' 2>/dev/null || echo "Response received")"
fi

echo ""
echo "2️⃣ Testing semantic-calc (NL calc)..."
CALC_RESPONSE=$(curl -s -X POST \
  "${SUPABASE_URL}/functions/v1/semantic-calc" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "expression": "basket size = units / transactions"
  }' || echo "ERROR")

if [[ $CALC_RESPONSE == *"ERROR"* ]] || [[ $CALC_RESPONSE == *"error"* ]]; then
  echo "❌ semantic-calc test failed"
  echo "Response: $CALC_RESPONSE"
else
  echo "✅ semantic-calc responding"
  echo "Sample response: $(echo $CALC_RESPONSE | jq -r '.sql // .expression // "Calculation processed"' 2>/dev/null || echo "Response received")"
fi

echo ""
echo "3️⃣ Testing semantic-suggest (Catalog suggest)..."
SUGGEST_RESPONSE=$(curl -s -X GET \
  "${SUPABASE_URL}/functions/v1/semantic-suggest?query=revenue&limit=5" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" || echo "ERROR")

if [[ $SUGGEST_RESPONSE == *"ERROR"* ]] || [[ $SUGGEST_RESPONSE == *"error"* ]]; then
  echo "❌ semantic-suggest test failed"
  echo "Response: $SUGGEST_RESPONSE"
else
  echo "✅ semantic-suggest responding"
  echo "Sample response: $(echo $SUGGEST_RESPONSE | jq -r '.suggestions[0:3] // .metrics // "Suggestions available"' 2>/dev/null || echo "Response received")"
fi

echo ""
echo "🔍 Testing database RPC functions directly..."
DB_TEST=$(curl -s -X POST \
  "${SUPABASE_URL}/rest/v1/rpc/semantic_query" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -d '{
    "object_names": ["Revenue"],
    "filters": {},
    "metrics": ["sum"],
    "group_by": []
  }' || echo "ERROR")

if [[ $DB_TEST == *"ERROR"* ]] || [[ $DB_TEST == *"error"* ]]; then
  echo "❌ Database RPC test failed"
  echo "Response: $DB_TEST"
else
  echo "✅ Database RPC responding"
  echo "Sample response: $(echo $DB_TEST | head -c 100)..."
fi

echo ""
echo "🌐 Testing UI route availability..."
# Check if the semantic layer route exists in the UI
if [[ -f "/Users/tbwa/scout-analytics-blueprint-doc/src/App.tsx" ]]; then
  if grep -q "semantic.*SemanticLayer" "/Users/tbwa/scout-analytics-blueprint-doc/src/App.tsx"; then
    echo "✅ UI route wired correctly"
  else
    echo "❌ UI route not found in App.tsx"
  fi
else
  echo "❌ App.tsx not found"
fi

if [[ -f "/Users/tbwa/scout-analytics-blueprint-doc/src/components/Sidebar.tsx" ]]; then
  if grep -q "Semantic Layer" "/Users/tbwa/scout-analytics-blueprint-doc/src/components/Sidebar.tsx"; then
    echo "✅ Sidebar navigation wired correctly"
  else
    echo "❌ Semantic Layer not found in Sidebar.tsx"
  fi
else
  echo "❌ Sidebar.tsx not found"
fi

echo ""
echo "📁 Verifying file deployments..."
FILES_TO_CHECK=(
  "/Users/tbwa/ai-aas-hardened-lakehouse/supabase/migrations/20250827_semantic_layer_security_fix.sql"
  "/Users/tbwa/ai-aas-hardened-lakehouse/supabase/functions/semantic-proxy/index.ts"
  "/Users/tbwa/ai-aas-hardened-lakehouse/supabase/functions/semantic-calc/index.ts"
  "/Users/tbwa/ai-aas-hardened-lakehouse/supabase/functions/semantic-suggest/index.ts"
  "/Users/tbwa/ai-aas-hardened-lakehouse/pulser/agents/semantic-layer.yaml"
  "/Users/tbwa/ai-aas-hardened-lakehouse/deploy-edge-functions.sh"
)

for file in "${FILES_TO_CHECK[@]}"; do
  if [[ -f "$file" ]]; then
    echo "✅ $(basename "$file")"
  else
    echo "❌ $(basename "$file") - MISSING"
  fi
done

echo ""
echo "🎯 Smoke test summary:"
echo "- Edge Functions: semantic-proxy, semantic-calc, semantic-suggest"
echo "- Database RPC: semantic_query function"
echo "- UI Integration: /semantic route with navigation"
echo "- File Deployments: Migration, functions, agent config"
echo ""
echo "⚠️  Note: Edge Functions deployed with --no-verify-jwt for testing"
echo "   Remove this flag for production deployment"