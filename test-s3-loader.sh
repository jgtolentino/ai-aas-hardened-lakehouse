#!/bin/bash

# Test S3 Data Loader Edge Function
# This script tests the deployed Edge Function

set -e

echo "🚀 Testing S3 Data Loader Edge Function"
echo "========================================"

# Get Supabase credentials
SUPABASE_URL="https://cxzllzyxwpyptfretryc.supabase.co"
FUNCTION_URL="${SUPABASE_URL}/functions/v1/s3-data-loader"

# You need to set your ANON_KEY
echo "Please ensure you have set SUPABASE_ANON_KEY in your environment"
echo ""

# Test 1: Load development sample data
echo "📊 Test 1: Loading sample data from development environment..."
curl -X POST "${FUNCTION_URL}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "environment": "development",
    "storageType": "s3",
    "dataType": "transactions"
  }' | jq '.'

echo ""
echo "✅ Test complete!"
echo ""

# Check results
echo "📈 Checking ETL pipeline status..."
cat << 'EOF' > check_status.sql
-- Check S3 ETL Pipeline Status
SELECT * FROM scout.s3_etl_status;

-- Check recent ETL jobs
SELECT 
    job_name,
    source_type,
    status,
    records_processed,
    started_at,
    completed_at
FROM scout.etl_jobs
WHERE started_at >= NOW() - INTERVAL '1 hour'
ORDER BY started_at DESC
LIMIT 5;

-- Check latest transactions
SELECT 
    COUNT(*) as total_s3_transactions
FROM scout.scout_gold_transactions
WHERE transaction_id LIKE 'S3-%';
EOF

echo "Run the above SQL in Supabase dashboard to verify results"
