#!/bin/bash

# Deploy Parquet Export Function to Supabase Edge Functions
# This script automates the deployment and setup

set -e

echo "🚀 Deploying Parquet Export Function..."
echo "======================================"

# Check prerequisites
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Install from: https://supabase.com/docs/guides/cli"
    exit 1
fi

if [ ! -f "supabase/config.toml" ]; then
    echo "❌ Not in a Supabase project directory. Run from project root."
    exit 1
fi

# Check if we're linked to a project
if ! supabase status | grep -q "API URL"; then
    echo "❌ Not linked to a Supabase project. Run 'supabase link' first."
    exit 1
fi

echo "📦 Deploying export-parquet function..."
supabase functions deploy export-parquet

if [ $? -eq 0 ]; then
    echo "✅ Function deployed successfully"
else
    echo "❌ Function deployment failed"
    exit 1
fi

# Create Python requirements file for PyArrow support
echo "📝 Creating Python requirements..."
cat > platform/scout/functions/export-parquet/requirements.txt << EOF
pyarrow>=14.0.0
pandas>=2.0.0
EOF

# Check Python/PyArrow availability
echo ""
echo "🐍 Checking Python/PyArrow support..."

# Test if function has Python/PyArrow available
FUNCTION_URL="$(supabase status | grep 'API URL' | awk '{print $3}')/functions/v1/export-parquet"

# Get service role key for testing
SERVICE_KEY=$(supabase status | grep 'service_role key' | awk '{print $3}')

HEALTH_CHECK=$(curl -s -H "Authorization: Bearer $SERVICE_KEY" "$FUNCTION_URL/health" || echo '{"status":"error"}')

if echo "$HEALTH_CHECK" | grep -q '"parquet_support":true'; then
    echo "✅ PyArrow support detected"
    PYARROW_VERSION=$(echo "$HEALTH_CHECK" | grep -o '"pyarrow_version":"[^"]*"' | cut -d'"' -f4)
    echo "📦 PyArrow version: $PYARROW_VERSION"
else
    echo "⚠️  PyArrow not detected in Edge Functions environment"
    echo "💡 Note: Parquet exports will fall back to CSV/JSON formats"
fi

# Test dataset listing
echo ""
echo "📊 Testing dataset availability..."

DATASETS_RESPONSE=$(curl -s -H "Authorization: Bearer $SERVICE_KEY" "$FUNCTION_URL/datasets" || echo '{"error":"failed"}')

if echo "$DATASETS_RESPONSE" | grep -q '"datasets"'; then
    DATASET_COUNT=$(echo "$DATASETS_RESPONSE" | grep -o '"name":"[^"]*"' | wc -l)
    echo "✅ Found $DATASET_COUNT available datasets:"
    echo "$DATASETS_RESPONSE" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | sed 's/^/  - /'
else
    echo "❌ Failed to retrieve datasets"
    echo "Response: $DATASETS_RESPONSE"
fi

# Create test script
echo ""
echo "📝 Creating test script..."

cat > scripts/test-parquet-export.js << 'EOF'
#!/usr/bin/env node

/**
 * Test script for Parquet Export function
 */

const API_URL = process.env.SUPABASE_URL + '/functions/v1/export-parquet';
const API_KEY = process.env.SUPABASE_SERVICE_KEY;

if (!API_URL || !API_KEY) {
  console.error('Please set SUPABASE_URL and SUPABASE_SERVICE_KEY environment variables');
  process.exit(1);
}

async function testExport() {
  console.log('🧪 Testing Parquet Export...');
  
  // Test health check
  console.log('1. Health check...');
  const healthResponse = await fetch(`${API_URL}/health`, {
    headers: { 'Authorization': `Bearer ${API_KEY}` }
  });
  
  const health = await healthResponse.json();
  console.log(`   Status: ${health.status}`);
  console.log(`   Parquet support: ${health.parquet_support}`);
  
  // Test dataset listing
  console.log('2. Listing datasets...');
  const datasetsResponse = await fetch(`${API_URL}/datasets`, {
    headers: { 'Authorization': `Bearer ${API_KEY}` }
  });
  
  const datasets = await datasetsResponse.json();
  console.log(`   Found ${datasets.datasets?.length || 0} datasets`);
  
  // Test small export
  console.log('3. Testing small export...');
  const exportResponse = await fetch(`${API_URL}/export`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      dataset: 'daily_transactions',
      format: 'json',
      limit: 10
    })
  });
  
  if (exportResponse.ok) {
    const exportResult = await exportResponse.json();
    console.log(`   ✅ Export successful: ${exportResult.row_count} rows, ${exportResult.file_size} bytes`);
    console.log(`   📁 File: ${exportResult.file_path}`);
    
    if (exportResult.signed_url) {
      console.log(`   🔗 Download URL available (expires in 1 hour)`);
    }
  } else {
    console.log(`   ❌ Export failed: ${exportResponse.statusText}`);
    const error = await exportResponse.json().catch(() => ({}));
    console.log(`   Error: ${error.error || 'Unknown error'}`);
  }
}

testExport().catch(console.error);
EOF

chmod +x scripts/test-parquet-export.js

echo "✅ Test script created: scripts/test-parquet-export.js"

# Summary
echo ""
echo "🎉 Deployment Summary"
echo "===================="
echo "Function URL: $FUNCTION_URL"
echo "Available endpoints:"
echo "  POST /export        - Request dataset export"
echo "  GET  /datasets       - List available datasets"  
echo "  GET  /health         - Health check"
echo ""
echo "📋 Next Steps:"
echo "1. Test the deployment:"
echo "   node scripts/test-parquet-export.js"
echo ""
echo "2. Use the ParquetExportClient in your applications:"
echo "   import { createParquetClient } from '@shared/parquet-client'"
echo ""
echo "3. Example export request:"
echo "   curl -X POST '$FUNCTION_URL/export' \\"
echo "     -H 'Authorization: Bearer YOUR_API_KEY' \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"dataset\":\"daily_transactions\",\"format\":\"parquet\",\"limit\":1000}'"
echo ""
echo "📖 Full documentation: docs/PARQUET_EXPORT_GUIDE.md"