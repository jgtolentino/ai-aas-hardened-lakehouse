#!/bin/bash
# Verify Scout Schema Alignment After Cleanup Migration
# Run this after applying 20250823_alignment_cleanup.sql

set -euo pipefail

# Load environment
[[ -f .env ]] && source .env
[[ -f /Users/tbwa/.env ]] && source /Users/tbwa/.env

# Build DB URL if needed
if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
  if [[ -n "${SUPABASE_PROJECT_REF:-}" && -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
    SUPABASE_DB_URL="postgresql://postgres.${SUPABASE_PROJECT_REF}:${SUPABASE_SERVICE_ROLE_KEY}@aws-0-us-west-1.pooler.supabase.com:6543/postgres"
  else
    echo "❌ Missing database connection info"
    exit 1
  fi
fi

echo "🔍 Verifying Scout Schema Alignment..."
echo "=================================="

# Run verification queries
psql "$SUPABASE_DB_URL" --no-psqlrc -t -A -c "
-- Check that singular tables are now VIEWS
SELECT 
    CASE 
        WHEN COUNT(*) = 4 AND COUNT(*) FILTER (WHERE table_type = 'VIEW') = 4 
        THEN '✅ All singular dims are now views'
        ELSE '❌ Singular dims not properly converted: ' || string_agg(table_name || '=' || table_type, ', ')
    END as status
FROM information_schema.tables
WHERE table_schema='scout' 
    AND table_name IN ('dim_store','dim_product','dim_customer','dim_campaign');
"

echo ""

psql "$SUPABASE_DB_URL" --no-psqlrc -t -A -c "
-- Check FK targets are plural
SELECT 
    CASE 
        WHEN COUNT(*) > 0 
        THEN '✅ ' || COUNT(*) || ' FKs properly point to plural dims'
        ELSE '⚠️ No FKs found pointing to plural dims'
    END as status
FROM pg_constraint con
JOIN pg_class src ON src.oid = con.conrelid
JOIN pg_class tgt ON tgt.oid = con.confrelid
JOIN pg_namespace ns ON ns.oid = src.relnamespace
WHERE ns.nspname='scout' AND con.contype='f'
    AND tgt.relname IN ('dim_stores','dim_products','dim_customers','dim_campaigns');
"

echo ""

# Test function signatures
echo "📊 Testing Function Signatures..."
echo "----------------------------------"

# Test parameterized KPI function
psql "$SUPABASE_DB_URL" --no-psqlrc -t -A -c "
SELECT 
    CASE 
        WHEN COUNT(*) >= 0 
        THEN '✅ get_dashboard_kpis(dates) works - ' || COUNT(*) || ' rows'
        ELSE '❌ get_dashboard_kpis(dates) failed'
    END
FROM scout.get_dashboard_kpis(CURRENT_DATE-7, CURRENT_DATE);
" 2>/dev/null || echo "❌ get_dashboard_kpis(dates) failed"

# Test no-arg KPI function
psql "$SUPABASE_DB_URL" --no-psqlrc -t -A -c "
SELECT 
    CASE 
        WHEN COUNT(*) >= 0 
        THEN '✅ get_dashboard_kpis() works - ' || COUNT(*) || ' rows'
        ELSE '❌ get_dashboard_kpis() failed'
    END
FROM scout.get_dashboard_kpis();
" 2>/dev/null || echo "❌ get_dashboard_kpis() failed"

echo ""

# Check deprecation notices
echo "⏰ Deprecation Schedule..."
echo "--------------------------"
psql "$SUPABASE_DB_URL" --no-psqlrc -c "
SELECT 
    days_until_removal || ' days' as \"Time Left\",
    object_name as \"Object\",
    migration_note as \"Migration Note\"
FROM scout.check_deprecations()
ORDER BY days_until_removal;
"

echo ""
echo "🎯 Alignment Summary"
echo "===================="

psql "$SUPABASE_DB_URL" --no-psqlrc -t -A -c "
WITH stats AS (
    SELECT 
        (SELECT COUNT(*) FROM information_schema.tables 
         WHERE table_schema='scout' AND table_type='BASE TABLE' 
         AND table_name LIKE 'dim_%') as dim_tables,
        (SELECT COUNT(*) FROM information_schema.tables 
         WHERE table_schema='scout' AND table_type='VIEW' 
         AND table_name LIKE 'dim_%') as dim_views,
        (SELECT COUNT(*) FROM information_schema.tables 
         WHERE table_schema='scout' AND table_type='BASE TABLE' 
         AND table_name LIKE 'fact_%') as fact_tables,
        (SELECT COUNT(*) FROM information_schema.tables 
         WHERE table_schema='scout' AND table_type='VIEW' 
         AND table_name LIKE 'gold_%') as gold_views,
        (SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid 
         WHERE n.nspname='scout') as functions
)
SELECT 
    '• Dimension Tables: ' || dim_tables || E'\n' ||
    '• Dimension Views (compat): ' || dim_views || E'\n' ||
    '• Fact Tables: ' || fact_tables || E'\n' ||
    '• Gold Views: ' || gold_views || E'\n' ||
    '• Functions: ' || functions
FROM stats;
"

echo ""
echo "✅ Verification Complete!"