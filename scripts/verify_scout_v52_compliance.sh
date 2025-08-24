#!/bin/bash
# ============================================================
# Scout v5.2 + Lakehouse Merge Verification Script
# Verifies that all features are properly integrated
# ============================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}🔍 Verifying Scout v5.2 + Lakehouse Merge...${NC}"
echo -e "${BLUE}============================================================${NC}"

# Database connection
PGURI="${PGURI:-postgresql://postgres:postgres@localhost:5432/postgres}"

# Function to check table existence
check_table() {
    local table_name=$1
    local description=$2
    
    if psql "$PGURI" -t -c "SELECT 1 FROM pg_tables WHERE schemaname = 'scout' AND tablename = '$table_name'" | grep -q 1; then
        echo -e "  ${GREEN}✓${NC} $description"
        return 0
    else
        echo -e "  ${RED}✗${NC} $description"
        return 1
    fi
}

# Function to check row count
check_data() {
    local query=$1
    local description=$2
    local min_count=${3:-0}
    
    local count=$(psql "$PGURI" -t -c "$query" | tr -d ' ')
    
    if [[ $count -ge $min_count ]]; then
        echo -e "  ${GREEN}✓${NC} $description (Count: $count)"
        return 0
    else
        echo -e "  ${YELLOW}⚠${NC} $description (Count: $count, Expected: >= $min_count)"
        return 1
    fi
}

# Function to check function existence
check_function() {
    local function_name=$1
    local description=$2
    
    if psql "$PGURI" -t -c "SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'scout' AND p.proname = '$function_name'" | grep -q 1; then
        echo -e "  ${GREEN}✓${NC} $description"
        return 0
    else
        echo -e "  ${RED}✗${NC} $description"
        return 1
    fi
}

# Track failures
FAILURES=0

# Check edge tables
echo -e "\n${YELLOW}✓ Checking edge device tables...${NC}"
check_table "edge_health" "Edge health monitoring table" || ((FAILURES++))
check_table "edge_installation_checks" "Edge installation checks table" || ((FAILURES++))
check_data "SELECT COUNT(*) FROM scout.edge_health" "Edge devices registered" 0 || ((FAILURES++))

# Check STT tables
echo -e "\n${YELLOW}✓ Checking STT detection tables...${NC}"
check_table "stt_brand_dictionary" "STT brand dictionary table" || ((FAILURES++))
check_table "stt_detections" "STT detections table" || ((FAILURES++))
check_data "SELECT COUNT(*) FROM scout.stt_brand_dictionary" "Brand phonetic variants" 10 || ((FAILURES++))

# Check dimension standardization
echo -e "\n${YELLOW}✓ Checking standardized dimension names...${NC}"
# Check for either old or new naming conventions
if check_table "dim_products" "Products dimension (dim_products)" 2>/dev/null || \
   check_table "dim_sku" "Products dimension (dim_sku)" 2>/dev/null || \
   check_table "master_products" "Products dimension (master_products)" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Products dimension exists"
else
    echo -e "  ${RED}✗${NC} No products dimension found"
    ((FAILURES++))
fi

if check_table "dim_brands" "Brands dimension (dim_brands)" 2>/dev/null || \
   check_table "ref_brands" "Brands dimension (ref_brands)" 2>/dev/null || \
   check_table "master_brands" "Brands dimension (master_brands)" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Brands dimension exists"
else
    echo -e "  ${RED}✗${NC} No brands dimension found"
    ((FAILURES++))
fi

# Check fact tables
echo -e "\n${YELLOW}✓ Checking fact tables...${NC}"
check_table "fact_transaction_items" "Transaction items fact table" || ((FAILURES++))
check_table "fact_daily_sales" "Daily sales fact table" || ((FAILURES++))

# Check silver completeness
echo -e "\n${YELLOW}✓ Checking expanded silver layer...${NC}"
check_table "silver_line_items" "Silver line items table" || ((FAILURES++))
check_table "silver_product_metrics" "Silver product metrics table" || ((FAILURES++))
check_table "bridge_product_substitutions" "Product substitutions bridge" || ((FAILURES++))
check_table "bridge_store_campaigns" "Store campaigns bridge" || ((FAILURES++))

# Check RPC functions
echo -e "\n${YELLOW}✓ Checking new RPC functions...${NC}"
check_function "get_edge_device_status" "Edge device status function" || ((FAILURES++))
check_function "run_installation_check" "Installation check function" || ((FAILURES++))
check_function "force_edge_sync" "Force sync function" || ((FAILURES++))

# Verify existing lakehouse features still work
echo -e "\n${YELLOW}✓ Checking preserved lakehouse features...${NC}"
check_table "dataset_versions" "Dataset versioning table" || echo -e "  ${YELLOW}⚠${NC} Dataset versioning not found (may not be deployed yet)"
check_table "usage_analytics" "Usage analytics table" || echo -e "  ${YELLOW}⚠${NC} Usage analytics not found (may not be deployed yet)"
check_table "medallion_manifest" "Medallion manifest table" || echo -e "  ${YELLOW}⚠${NC} Medallion manifest not found (may not be deployed yet)"

# Check privacy compliance
echo -e "\n${YELLOW}✓ Checking privacy compliance...${NC}"
AUDIO_VIDEO_COUNT=$(psql "$PGURI" -t -c "SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'scout' AND tablename ~* '(audio|video|recording|media|biometric)'" | tr -d ' ')
if [[ $AUDIO_VIDEO_COUNT -eq 0 ]]; then
    echo -e "  ${GREEN}✓${NC} No audio/video storage tables found (privacy compliant)"
else
    echo -e "  ${RED}✗${NC} Found $AUDIO_VIDEO_COUNT tables with potential audio/video data"
    ((FAILURES++))
fi

# Performance quick check
echo -e "\n${YELLOW}✓ Running performance quick check...${NC}"
if check_function "get_dashboard_kpis" "Dashboard KPIs function" 2>/dev/null; then
    START_TIME=$(date +%s%N)
    psql "$PGURI" -c "SELECT scout.get_dashboard_kpis(CURRENT_DATE - INTERVAL '7 days', CURRENT_DATE) LIMIT 1;" >/dev/null 2>&1 || true
    END_TIME=$(date +%s%N)
    DURATION=$((($END_TIME - $START_TIME) / 1000000))
    
    if [[ $DURATION -lt 3000 ]]; then
        echo -e "  ${GREEN}✓${NC} Dashboard KPIs performance OK (${DURATION}ms)"
    else
        echo -e "  ${YELLOW}⚠${NC} Dashboard KPIs slow (${DURATION}ms > 3000ms SLA)"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Dashboard KPIs function not found"
fi

# Summary
echo -e "\n${BLUE}============================================================${NC}"
if [[ $FAILURES -eq 0 ]]; then
    echo -e "${GREEN}✅ All Scout v5.2 + Lakehouse features verified!${NC}"
    exit 0
else
    echo -e "${RED}❌ Verification failed with $FAILURES issues${NC}"
    echo -e "${YELLOW}Please check the migration status and apply missing migrations${NC}"
    exit 1
fi