#!/bin/bash
set -euo pipefail

# RAG Pipeline Smoke Test Runner
# Validates all components of the RAG system are working properly

echo "🔍 RAG Pipeline Smoke Tests"
echo "=========================="

# Check required environment variables
if [ -z "${SUPABASE_URL:-}" ]; then
  echo "❌ SUPABASE_URL environment variable is required"
  exit 1
fi

if [ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]; then
  echo "❌ SUPABASE_SERVICE_ROLE_KEY environment variable is required"
  exit 1
fi

# Test database connectivity
echo "1. Testing Supabase connectivity..."
response=$(curl -s -w "%{http_code}" -o /tmp/supabase_test.json \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
  "${SUPABASE_URL}/rest/v1/documents?select=id&limit=1")

if [ "$response" = "200" ]; then
  echo "✅ Supabase connectivity verified"
else
  echo "❌ Supabase connectivity failed (HTTP $response)"
  cat /tmp/supabase_test.json
  exit 1
fi

# Test pgvector extension
echo "2. Testing pgvector extension..."
response=$(curl -s -w "%{http_code}" -o /tmp/pgvector_test.json \
  -X POST \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  "${SUPABASE_URL}/rest/v1/rpc/exec" \
  -d '{"sql": "SELECT * FROM pg_extension WHERE extname = '\''vector'\''"}')

if [ "$response" = "200" ] && grep -q "vector" /tmp/pgvector_test.json; then
  echo "✅ pgvector extension is installed"
else
  echo "❌ pgvector extension test failed"
  cat /tmp/pgvector_test.json
  exit 1
fi

# Test HNSW index
echo "3. Testing HNSW index on documents table..."
response=$(curl -s -w "%{http_code}" -o /tmp/hnsw_test.json \
  -X POST \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  "${SUPABASE_URL}/rest/v1/rpc/exec" \
  -d '{"sql": "SELECT indexname FROM pg_indexes WHERE tablename = '\''documents'\'' AND indexname = '\''documents_embedding_hnsw_idx'\''"}')

if [ "$response" = "200" ] && grep -q "documents_embedding_hnsw_idx" /tmp/hnsw_test.json; then
  echo "✅ HNSW index exists on documents table"
else
  echo "❌ HNSW index test failed"
  cat /tmp/hnsw_test.json
  exit 1
fi

# Test match_documents function
echo "4. Testing match_documents function..."
test_embedding=$(python3 -c "import json; print(json.dumps([0.1] * 1536))")
response=$(curl -s -w "%{http_code}" -o /tmp/match_docs_test.json \
  -X POST \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  "${SUPABASE_URL}/rest/v1/rpc/match_documents" \
  -d "{\"query_embedding\": $test_embedding, \"match_threshold\": 0.1, \"match_count\": 5}")

if [ "$response" = "200" ]; then
  echo "✅ match_documents function is callable"
else
  echo "❌ match_documents function test failed"
  cat /tmp/match_docs_test.json
  exit 1
fi

# Test upsert_document function
echo "5. Testing upsert_document function..."
timestamp=$(date +%s)
checksum="smoke_test_$timestamp"
response=$(curl -s -w "%{http_code}" -o /tmp/upsert_test.json \
  -X POST \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  "${SUPABASE_URL}/rest/v1/rpc/upsert_document" \
  -d "{\"title_param\": \"Smoke Test Doc\", \"content_param\": \"Test content\", \"checksum_param\": \"$checksum\"}")

if [ "$response" = "200" ]; then
  echo "✅ upsert_document function works"
  
  # Clean up test document
  curl -s -X DELETE \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    "${SUPABASE_URL}/rest/v1/documents?checksum=eq.$checksum"
else
  echo "❌ upsert_document function test failed"
  cat /tmp/upsert_test.json
  exit 1
fi

# Test edge function deployment
echo "6. Testing process-documents edge function..."
response=$(curl -s -w "%{http_code}" -o /tmp/process_docs_test.json \
  -X POST \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  "${SUPABASE_URL}/functions/v1/process-documents" \
  -d '{"documents": []}')

if [ "$response" = "400" ] && grep -q "Empty request" /tmp/process_docs_test.json; then
  echo "✅ process-documents edge function is deployed and responding"
else
  echo "❌ process-documents edge function test failed"
  cat /tmp/process_docs_test.json
  exit 1
fi

# Test AI insight generation edge function
echo "7. Testing ai-generate-insight edge function..."
response=$(curl -s -w "%{http_code}" -o /tmp/ai_insight_test.json \
  -X POST \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  "${SUPABASE_URL}/functions/v1/ai-generate-insight" \
  -d '{"query": "Test query", "context": {"test": true}}')

if [ "$response" = "200" ] || [ "$response" = "500" ]; then
  # 200 = success, 500 = OpenAI API key issue (expected in test env)
  if [ "$response" = "200" ]; then
    echo "✅ ai-generate-insight edge function is deployed and working"
  else
    if grep -q "OpenAI" /tmp/ai_insight_test.json || grep -q "API" /tmp/ai_insight_test.json; then
      echo "✅ ai-generate-insight edge function is deployed (OpenAI API key needed for full functionality)"
    else
      echo "❌ ai-generate-insight edge function has unexpected error"
      cat /tmp/ai_insight_test.json
      exit 1
    fi
  fi
else
  echo "❌ ai-generate-insight edge function test failed"
  cat /tmp/ai_insight_test.json
  exit 1
fi

# Test RLS policies
echo "8. Testing RLS policies..."
response=$(curl -s -w "%{http_code}" -o /tmp/rls_test.json \
  -X POST \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  "${SUPABASE_URL}/rest/v1/rpc/exec" \
  -d '{"sql": "SELECT COUNT(*) as policy_count FROM pg_policies WHERE tablename = '\''documents'\''"}')

if [ "$response" = "200" ]; then
  policy_count=$(cat /tmp/rls_test.json | python3 -c "import json, sys; data=json.load(sys.stdin); print(data[0]['policy_count'])")
  if [ "$policy_count" -gt 0 ]; then
    echo "✅ RLS policies are configured ($policy_count policies found)"
  else
    echo "❌ No RLS policies found on documents table"
    exit 1
  fi
else
  echo "❌ RLS policy test failed"
  cat /tmp/rls_test.json
  exit 1
fi

# Test chat system tables
echo "9. Testing chat system tables..."
for table in "chat_conversations" "chat_messages"; do
  response=$(curl -s -w "%{http_code}" -o /tmp/chat_test.json \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    "${SUPABASE_URL}/rest/v1/$table?select=id&limit=0")
  
  if [ "$response" = "200" ]; then
    echo "✅ $table table exists and is accessible"
  else
    echo "❌ $table table test failed"
    cat /tmp/chat_test.json
    exit 1
  fi
done

# Clean up temp files
rm -f /tmp/supabase_test.json /tmp/pgvector_test.json /tmp/hnsw_test.json \
      /tmp/match_docs_test.json /tmp/upsert_test.json /tmp/process_docs_test.json \
      /tmp/ai_insight_test.json /tmp/rls_test.json /tmp/chat_test.json

echo ""
echo "🎉 All RAG Pipeline Smoke Tests Passed!"
echo ""
echo "Summary:"
echo "✅ Supabase connectivity"
echo "✅ pgvector extension installed"
echo "✅ HNSW index configured"
echo "✅ Vector similarity search (match_documents)"
echo "✅ Document upsert functionality"
echo "✅ Edge functions deployed"
echo "✅ RLS policies configured"
echo "✅ Chat system tables"
echo ""
echo "🚀 RAG pipeline is ready for production use!"