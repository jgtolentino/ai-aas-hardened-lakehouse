#!/bin/bash
# Scout Platform Deployment Script

echo "🚀 Scout Platform Deployment"
echo "=========================="

# Check if we're in the right directory
if [ ! -f "functions/ingest-transaction.ts" ]; then
    echo "❌ Error: Not in the scout directory"
    echo "Please run from platform/scout/"
    exit 1
fi

echo ""
echo "📦 Step 1: Deploy Edge Function"
echo "------------------------------"
echo "Run these commands:"
echo ""
echo "cd functions"
echo "supabase functions deploy ingest-transaction --no-verify-jwt"
echo ""

echo "📊 Step 2: Run SQL Migrations"
echo "----------------------------"
echo "Open Supabase SQL Editor at:"
echo "https://supabase.com/dashboard/project/cxzllzyxwpyptfretryc/sql/new"
echo ""
echo "Run these files in order:"
echo "1. migrations/001_scout_enums_dims.sql"
echo "2. migrations/002_scout_bronze_silver.sql"
echo "3. migrations/003_scout_gold_views.sql"
echo "4. migrations/004_scout_platinum_features.sql"
echo ""

echo "🧪 Step 3: Test with Bruno"
echo "-------------------------"
echo "1. Open Bruno"
echo "2. Import collection from: $(pwd)/bruno"
echo "3. Select 'development' environment"
echo "4. Run tests in this order:"
echo "   - 18_test_connection.bru"
echo "   - 09_seed_dims.bru"
echo "   - 10_txn_ingest.bru"
echo "   - 11_verify_silver.bru"
echo "   - 12_query_gold_daily.bru"
echo ""

echo "📈 Step 4: Import Superset Dashboard"
echo "-----------------------------------"
echo "superset import-dashboards -p superset/scout_dashboard.yaml"
echo ""

echo "✅ Deployment Checklist"
echo "---------------------"
echo "[ ] Edge Function deployed"
echo "[ ] SQL migrations applied"
echo "[ ] Bruno tests passing"
echo "[ ] Superset dashboard imported"
echo "[ ] Gold views refreshing (5 min)"
echo ""