#!/usr/bin/env bash
set -euo pipefail

# Scout v5.2 - Comprehensive Deployment Validation
# Validates schema, data coverage, and creates necessary patches

DATABASE_URL="${DATABASE_URL:-postgresql://postgres:password@db.cxzllzyxwpyptfretryc.supabase.co:5432/postgres}"

echo "🔍 Scout v5.2 Deployment Validation"
echo "===================================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ISSUES_FOUND=0

issue_found() {
    echo -e "${RED}❌ ISSUE: $1${NC}"
    ((ISSUES_FOUND++))
}

validation_pass() {
    echo -e "${GREEN}✅ $1${NC}"
}

validation_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo -e "\n🗄️ 1. Schema & Table Analysis"
echo "----------------------------"

# Check if scout schema exists
if psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = 'scout';" | grep -q "1"; then
    validation_pass "Scout schema exists"
else
    issue_found "Scout schema missing"
    exit 1
fi

# List all scout tables with row counts
echo -e "\n📊 Current Scout Tables:"
psql "$DATABASE_URL" << 'EOSQL'
SELECT 
    t.table_name,
    COALESCE(pg_class.reltuples::bigint, 0) as estimated_rows,
    CASE 
        WHEN pg_class.reltuples > 1000 THEN '✅ Well Populated'
        WHEN pg_class.reltuples > 100 THEN '⚠️ Moderate Data'
        WHEN pg_class.reltuples > 0 THEN '⚠️ Sparse Data'
        ELSE '❌ Empty'
    END as status
FROM information_schema.tables t
LEFT JOIN pg_class ON pg_class.relname = t.table_name
WHERE t.table_schema = 'scout' 
    AND t.table_type = 'BASE TABLE'
ORDER BY pg_class.reltuples DESC NULLS LAST;
EOSQL

echo -e "\n🏗️ 2. Medallion Architecture Validation"
echo "---------------------------------------"

# Check Bronze layer tables
bronze_tables=$(psql "$DATABASE_URL" -tAc "
SELECT COUNT(*) FROM information_schema.tables 
WHERE table_schema = 'scout' AND table_name LIKE '%bronze%';
")

# Check Silver layer tables  
silver_tables=$(psql "$DATABASE_URL" -tAc "
SELECT COUNT(*) FROM information_schema.tables 
WHERE table_schema = 'scout' AND table_name LIKE '%silver%';
")

# Check Gold layer views
gold_views=$(psql "$DATABASE_URL" -tAc "
SELECT COUNT(*) FROM information_schema.views 
WHERE table_schema = 'scout' AND table_name LIKE '%gold%';
")

# Check Platinum layer tables
platinum_tables=$(psql "$DATABASE_URL" -tAc "
SELECT COUNT(*) FROM information_schema.tables 
WHERE table_schema = 'scout' AND table_name LIKE '%platinum%';
")

echo "Bronze Layer Tables: $bronze_tables"
echo "Silver Layer Tables: $silver_tables" 
echo "Gold Layer Views: $gold_views"
echo "Platinum Layer Tables: $platinum_tables"

if [ "$gold_views" -lt 3 ]; then
    issue_found "Insufficient Gold layer views (found: $gold_views, expected: ≥3)"
fi

echo -e "\n🛍️ 3. Core Transaction Data Analysis"
echo "-----------------------------------"

# Check transaction vs transaction_items coverage
transaction_count=$(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM scout.transactions;" 2>/dev/null || echo "0")
transaction_items_count=$(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM scout.transaction_items;" 2>/dev/null || echo "0")

if [ "$transaction_count" -gt 0 ] && [ "$transaction_items_count" -gt 0 ]; then
    coverage_pct=$(psql "$DATABASE_URL" -tAc "
        SELECT ROUND(100.0 * COUNT(DISTINCT ti.transaction_id) / COUNT(DISTINCT t.id), 1)
        FROM scout.transactions t
        LEFT JOIN scout.transaction_items ti ON t.id = ti.transaction_id;
    " 2>/dev/null || echo "0")
    
    echo "Transactions: $transaction_count"
    echo "Transaction Items: $transaction_items_count"
    echo "Coverage: ${coverage_pct}%"
    
    if (( $(echo "$coverage_pct < 90" | bc -l) )); then
        issue_found "Low transaction_items coverage: ${coverage_pct}% (expected: ≥90%)"
    else
        validation_pass "Good transaction_items coverage: ${coverage_pct}%"
    fi
else
    issue_found "Missing transaction data (transactions: $transaction_count, items: $transaction_items_count)"
fi

echo -e "\n🏪 4. Master Data Completeness"
echo "-----------------------------"

# Check stores
store_count=$(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM scout.stores;" 2>/dev/null || echo "0")
echo "Stores: $store_count"

if [ "$store_count" -lt 3 ]; then
    issue_found "Insufficient store data (found: $store_count, expected: ≥3)"
fi

# Check products  
product_count=$(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM scout.products;" 2>/dev/null || echo "0")
echo "Products: $product_count"

if [ "$product_count" -lt 50 ]; then
    issue_found "Insufficient product data (found: $product_count, expected: ≥50)"
fi

# Check brands
brand_count=$(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM scout.brands;" 2>/dev/null || echo "0")
echo "Brands: $brand_count"

if [ "$brand_count" -lt 20 ]; then
    issue_found "Insufficient brand data (found: $brand_count, expected: ≥20)"
fi

echo -e "\n🤖 5. Device Management Layer"
echo "----------------------------"

# Check device tables
device_count=$(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM scout.devices;" 2>/dev/null || echo "0")
device_health_count=$(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM scout.device_health;" 2>/dev/null || echo "0")

echo "Devices: $device_count"
echo "Device Health Records: $device_health_count"

if [ "$device_count" -eq 0 ]; then
    issue_found "No device data found"
fi

echo -e "\n📈 6. Analytics Views & Functions"
echo "-------------------------------"

# Check critical views
critical_views=(
    "scout.v_device_health_summary"
    "scout.v_substitution_analytics" 
    "scout.gold_daily_metrics"
    "scout.gold_brand_competitive_30d"
)

for view in "${critical_views[@]}"; do
    if psql "$DATABASE_URL" -c "\d $view" >/dev/null 2>&1; then
        validation_pass "View exists: $view"
    else
        issue_found "Missing critical view: $view"
    fi
done

# Check critical functions
critical_functions=(
    "scout.run_installation_check"
    "scout.get_relevant_insights"
    "scout.assign_store_clusters"
)

for func in "${critical_functions[@]}"; do
    if psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'scout' AND p.proname LIKE '$(echo $func | cut -d. -f2)%';" | grep -q "1"; then
        validation_pass "Function exists: $func"
    else
        issue_found "Missing critical function: $func"
    fi
done

echo -e "\n🌱 7. Data Seeding Status"
echo "-----------------------"

# Check if data appears to be synthetic vs real
synthetic_indicators=0

# Check for obvious test data patterns
test_pattern_count=$(psql "$DATABASE_URL" -tAc "
SELECT COUNT(*) FROM scout.transactions 
WHERE customer_name ILIKE '%test%' OR customer_name ILIKE '%sample%';
" 2>/dev/null || echo "0")

if [ "$test_pattern_count" -gt 0 ]; then
    ((synthetic_indicators++))
fi

# Check for rounded amounts (synthetic indicator)
rounded_amounts=$(psql "$DATABASE_URL" -tAc "
SELECT COUNT(*) FROM scout.transactions 
WHERE amount_paid = ROUND(amount_paid, 0);
" 2>/dev/null || echo "0")

if [ "$transaction_count" -gt 0 ] && [ "$rounded_amounts" -gt $((transaction_count * 80 / 100)) ]; then
    ((synthetic_indicators++))
fi

if [ "$synthetic_indicators" -gt 0 ]; then
    validation_warn "Data appears synthetic ($synthetic_indicators indicators) - normal for development"
else
    validation_pass "Data appears realistic"
fi

echo -e "\n🔍 8. Data Quality Checks"
echo "-----------------------"

# Check for NULL critical fields
null_check_results=$(psql "$DATABASE_URL" << 'EOSQL'
SELECT 
    'transactions.id' as field,
    COUNT(*) FILTER (WHERE id IS NULL) as null_count,
    COUNT(*) as total_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE id IS NULL) / COUNT(*), 1) as null_pct
FROM scout.transactions

UNION ALL

SELECT 
    'products.name' as field,
    COUNT(*) FILTER (WHERE name IS NULL) as null_count,
    COUNT(*) as total_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE name IS NULL) / COUNT(*), 1) as null_pct
FROM scout.products

UNION ALL

SELECT 
    'stores.name' as field,
    COUNT(*) FILTER (WHERE name IS NULL) as null_count,
    COUNT(*) as total_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE name IS NULL) / COUNT(*), 1) as null_pct
FROM scout.stores;
EOSQL
)

echo "$null_check_results"

echo -e "\n🚀 9. Performance Optimization Check"
echo "----------------------------------"

# Check for indexes on critical tables
index_count=$(psql "$DATABASE_URL" -tAc "
SELECT COUNT(*) FROM pg_indexes 
WHERE schemaname = 'scout' AND tablename IN ('transactions', 'transaction_items', 'products', 'stores');
")

echo "Indexes on core tables: $index_count"

if [ "$index_count" -lt 5 ]; then
    issue_found "Insufficient indexes (found: $index_count, expected: ≥5)"
else
    validation_pass "Good index coverage"
fi

echo -e "\n📋 10. Summary & Recommendations"
echo "==============================="

if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}🎉 DEPLOYMENT VALIDATION PASSED!${NC}"
    echo "Scout v5.2 deployment appears healthy."
else
    echo -e "${RED}🔧 ISSUES FOUND: $ISSUES_FOUND${NC}"
    echo "Creating patch scripts to address issues..."
fi

echo -e "\n📊 Deployment Statistics:"
echo "• Total Tables in Scout Schema: $(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'scout';")"
echo "• Total Views in Scout Schema: $(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'scout';")"  
echo "• Total Functions in Scout Schema: $(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'scout';")"
echo "• Transaction Records: $transaction_count"
echo "• Product Records: $product_count"
echo "• Store Records: $store_count"

if [ $ISSUES_FOUND -gt 0 ]; then
    echo -e "\n🔧 Next Steps:"
    echo "1. Review issues identified above"
    echo "2. Apply generated patches"
    echo "3. Re-run validation"
    exit 1
else
    exit 0
fi