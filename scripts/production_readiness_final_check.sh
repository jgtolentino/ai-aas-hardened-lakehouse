#!/usr/bin/env bash
set -euo pipefail

# Scout v5.2 - Final Production Readiness Check
# Comprehensive verification that all components are working

DATABASE_URL="${DATABASE_URL:-postgresql://postgres:password@localhost:54322/postgres}"
SUPABASE_URL="https://cxzllzyxwpyptfretryc.supabase.co"

echo "🚀 Scout v5.2 Final Production Readiness Check"
echo "=============================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_status() {
  if [ $1 -eq 0 ]; then
    echo -e "${GREEN}✅ $2${NC}"
  else
    echo -e "${RED}❌ $2${NC}"
    ((FAILED_CHECKS++))
  fi
}

FAILED_CHECKS=0

echo -e "\n📋 1. Core Database Schema Check"
echo "--------------------------------"

# Check critical tables
echo "Checking critical tables..."
psql "$DATABASE_URL" -tAc "
SELECT 
  CASE WHEN to_regclass('scout.edge_health') IS NOT NULL THEN 0 ELSE 1 END +
  CASE WHEN to_regclass('scout.edge_installation_checks') IS NOT NULL THEN 0 ELSE 1 END +
  CASE WHEN to_regclass('scout.stt_brand_dictionary') IS NOT NULL THEN 0 ELSE 1 END +
  CASE WHEN to_regclass('scout.silver_line_items') IS NOT NULL THEN 0 ELSE 1 END +
  CASE WHEN to_regclass('scout.gold_brand_competitive_30d') IS NOT NULL THEN 0 ELSE 1 END +
  CASE WHEN to_regclass('scout.gold_region_choropleth') IS NOT NULL THEN 0 ELSE 1 END +
  CASE WHEN to_regclass('scout.fact_substitutions') IS NOT NULL THEN 0 ELSE 1 END +
  CASE WHEN to_regclass('scout.store_clusters') IS NOT NULL THEN 0 ELSE 1 END +
  CASE WHEN to_regclass('scout.knowledge_vectors') IS NOT NULL THEN 0 ELSE 1 END +
  CASE WHEN to_regclass('scout.platinum_ai_insights') IS NOT NULL THEN 0 ELSE 1 END
" > /tmp/table_check_result

table_result=$(cat /tmp/table_check_result)
check_status $table_result "Critical tables existence"

echo -e "\n🔧 2. Core Functions Check"
echo "-------------------------"

# Check critical functions
echo "Checking critical functions..."
psql "$DATABASE_URL" -tAc "
SELECT 
  CASE WHEN to_regproc('scout.run_installation_check(text)') IS NOT NULL THEN 0 ELSE 1 END +
  CASE WHEN to_regproc('scout.get_relevant_insights(text, jsonb, integer)') IS NOT NULL THEN 0 ELSE 1 END +
  CASE WHEN to_regproc('scout.assign_store_clusters()') IS NOT NULL THEN 0 ELSE 1 END +
  CASE WHEN to_regproc('scout.populate_fact_substitutions()') IS NOT NULL THEN 0 ELSE 1 END
" > /tmp/function_check_result

function_result=$(cat /tmp/function_check_result)
check_status $function_result "Critical functions existence"

echo -e "\n📊 3. Migration Manifest Check"
echo "------------------------------"

# Check migration manifest
echo "Checking migration manifest..."
manifest_count=$(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM scout.migration_manifest WHERE file LIKE '0%_%.sql';")

if [ "$manifest_count" -ge 7 ]; then
  check_status 0 "Migration manifest (found $manifest_count migrations)"
else
  check_status 1 "Migration manifest (only found $manifest_count migrations, expected >= 7)"
fi

echo -e "\n🪣 4. Seed Data Buckets Check"
echo "----------------------------"

# Check if seed data buckets exist
echo "Checking seed data availability..."
if curl -s "$SUPABASE_URL/storage/v1/object/list/scout-sample-seeds" \
  -H "apikey: $SUPABASE_ANON_KEY" >/dev/null 2>&1; then
  check_status 0 "Seed data buckets accessible"
else
  check_status 1 "Seed data buckets not accessible"
fi

echo -e "\n🧪 5. Functional Testing"
echo "-----------------------"

# Test device installation check
echo "Testing device installation check..."
device_check_result=$(psql "$DATABASE_URL" -tAc "SELECT CASE WHEN scout.run_installation_check('TEST-DEVICE-001') IS NOT NULL THEN 0 ELSE 1 END;" 2>/dev/null || echo "1")
check_status $device_check_result "Device installation check function"

# Test AI insights
echo "Testing AI insights..."
insights_count=$(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM scout.get_relevant_insights('brand_manager', NULL, 5);" 2>/dev/null || echo "0")
if [ "$insights_count" -gt 0 ]; then
  check_status 0 "AI insights generation ($insights_count insights)"
else
  check_status 1 "AI insights generation (no insights returned)"
fi

echo -e "\n📈 6. Data Quality Check"
echo "-----------------------"

# Check data quality in key views
echo "Checking Gold layer data availability..."
gold_data_count=$(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM scout.gold_brand_competitive_30d;" 2>/dev/null || echo "0")
if [ "$gold_data_count" -gt 0 ]; then
  check_status 0 "Gold layer competitive data ($gold_data_count records)"
else
  check_status 1 "Gold layer competitive data (no data available)"
fi

# Check geographic data
geo_data_count=$(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM scout.gold_region_choropleth;" 2>/dev/null || echo "0")
if [ "$geo_data_count" -gt 0 ]; then
  check_status 0 "Geographic choropleth data ($geo_data_count regions)"
else
  check_status 1 "Geographic choropleth data (no data available)"
fi

echo -e "\n🔒 7. Security & Access Check"
echo "----------------------------"

# Check RLS policies exist
echo "Checking Row Level Security policies..."
rls_count=$(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM pg_policy WHERE schemaname = 'scout';" 2>/dev/null || echo "0")
if [ "$rls_count" -gt 0 ]; then
  check_status 0 "Row Level Security policies ($rls_count policies)"
else
  check_status 1 "Row Level Security policies (no policies found)"
fi

echo -e "\n🎨 8. Dashboard Configuration Check"
echo "----------------------------------"

# Check if Superset config exists
if [ -f "superset/scout_v5_2_dashboard_config.yaml" ]; then
  check_status 0 "Superset dashboard configuration file"
else
  check_status 1 "Superset dashboard configuration file missing"
fi

echo -e "\n📋 9. Documentation Check"
echo "------------------------"

# Check critical documentation
docs_exist=0
[ -f "docs/SCOUT_V5_2_PRD.md" ] && ((docs_exist++))
[ -f "docs/SCOUT_V5_2_DEPLOYMENT_STATUS.md" ] && ((docs_exist++))
[ -f "docs/SCOUT_V5_2_ADVANCED_INTELLIGENCE_ENGINE.md" ] && ((docs_exist++))

if [ $docs_exist -eq 3 ]; then
  check_status 0 "Critical documentation files"
else
  check_status 1 "Critical documentation files ($docs_exist/3 found)"
fi

echo -e "\n🚀 10. Final System Status"
echo "==========================="

if [ $FAILED_CHECKS -eq 0 ]; then
  echo -e "${GREEN}"
  echo "🎉 PRODUCTION READY! 🎉"
  echo "All systems operational."
  echo -e "${NC}"
  
  echo -e "\n📊 Quick Stats Summary:"
  psql "$DATABASE_URL" << 'EOSQL'
SELECT 
  'Tables' as component, COUNT(*) as count 
FROM information_schema.tables 
WHERE table_schema = 'scout'

UNION ALL

SELECT 
  'Views' as component, COUNT(*) as count 
FROM information_schema.views 
WHERE table_schema = 'scout'

UNION ALL

SELECT 
  'Functions' as component, COUNT(*) as count 
FROM information_schema.routines 
WHERE routine_schema = 'scout'

ORDER BY component;
EOSQL

  echo -e "\n🔗 Access URLs:"
  echo "• Supabase Dashboard: https://app.supabase.com/project/cxzllzyxwpyptfretryc"
  echo "• API Base URL: $SUPABASE_URL"
  echo "• Storage Buckets: $SUPABASE_URL/storage/v1/object/list/scout-sample-seeds"
  
  exit 0
else
  echo -e "${RED}"
  echo "❌ DEPLOYMENT ISSUES DETECTED"
  echo "Failed checks: $FAILED_CHECKS"
  echo -e "${NC}"
  
  echo -e "\n🔧 Next Steps:"
  echo "1. Run: ./scripts/apply_missing_migrations_with_manifest.sh"
  echo "2. Run: ./scripts/create_seed_buckets_and_upload.sh" 
  echo "3. Re-run this check: ./scripts/production_readiness_final_check.sh"
  
  exit 1
fi

# Cleanup temp files
rm -f /tmp/table_check_result /tmp/function_check_result