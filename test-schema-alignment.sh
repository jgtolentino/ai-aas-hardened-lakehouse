#!/bin/bash

# Scout Analytics & Dataset Publisher - Comprehensive Test Suite
# Tests all major components including transcript processing and dataset publishing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Scout Analytics Test Suite${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# Check for database connection
if [ -z "$POSTGRES_URL" ] && [ -z "$SUPABASE_DB_URL" ]; then
    echo -e "${RED}Error: POSTGRES_URL or SUPABASE_DB_URL must be set${NC}"
    exit 1
fi

DB_URL="${POSTGRES_URL:-$SUPABASE_DB_URL}"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local sql="$2"
    local expected="$3"
    
    echo -e "\n${YELLOW}Test: ${test_name}${NC}"
    
    result=$(psql "$DB_URL" -t -c "$sql" 2>/dev/null | xargs)
    
    if [ "$expected" = "EXISTS" ]; then
        if [ -n "$result" ]; then
            echo -e "${GREEN}  ✓ PASS${NC} - Result: ${result:0:50}..."
            ((TESTS_PASSED++))
            return 0
        fi
    elif [ "$expected" = "GREATER_THAN_ZERO" ]; then
        if [ "$result" -gt 0 ] 2>/dev/null; then
            echo -e "${GREEN}  ✓ PASS${NC} - Count: $result"
            ((TESTS_PASSED++))
            return 0
        fi
    elif [ "$result" = "$expected" ]; then
        echo -e "${GREEN}  ✓ PASS${NC} - Expected: $expected"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}  ✗ FAIL${NC} - Expected: $expected, Got: $result"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo -e "\n${CYAN}═══ Test Suite 1: Schema Verification ═══${NC}"

run_test "Scout schema exists" \
    "SELECT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'scout')" \
    "t"

run_test "Usage Analytics schema exists" \
    "SELECT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'usage_analytics')" \
    "t"

run_test "Versioning schema exists" \
    "SELECT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'versioning')" \
    "t"

echo -e "\n${CYAN}═══ Test Suite 2: Data Integrity ═══${NC}"

run_test "Transactions loaded" \
    "SELECT COUNT(*) FROM scout.fact_transactions" \
    "GREATER_THAN_ZERO"

run_test "Daily aggregates computed" \
    "SELECT COUNT(*) FROM scout.fact_daily_sales" \
    "GREATER_THAN_ZERO"

run_test "Dimensions populated" \
    "SELECT COUNT(*) FROM scout.dim_date" \
    "GREATER_THAN_ZERO"

echo -e "\n${CYAN}═══ Test Suite 3: Transcript Processing ═══${NC}"

# Test transcript processing with Filipino sample
echo -e "\n${YELLOW}Creating test transaction with transcript...${NC}"
psql "$DB_URL" -c "
-- Insert test transaction
INSERT INTO scout.fact_transactions (
    transaction_id, 
    store_id, 
    transaction_date, 
    transaction_time, 
    total_amount, 
    status,
    source_file
) VALUES (
    'TEST-' || to_char(NOW(), 'YYYYMMDDHH24MISS'),
    'STORE-TEST',
    CURRENT_DATE,
    CURRENT_TIME,
    100.00,
    'completed',
    'test-suite'
) ON CONFLICT (transaction_id) DO NOTHING;
" > /dev/null 2>&1

# Process a sample transcript
TEST_ID="TEST-$(date +%Y%m%d%H%M%S)"
echo -e "\n${YELLOW}Processing Filipino transcript...${NC}"
TRANSCRIPT_RESULT=$(psql "$DB_URL" -t -c "
SELECT scout.process_transcript(
    '$TEST_ID'::VARCHAR,
    'Ate, pahingi po ng Lucky Me pancit canton at Coke. May Marlboro din ba kayo?'
)::jsonb->>'brands_found';
" 2>/dev/null | xargs)

if [ "$TRANSCRIPT_RESULT" = "t" ] || [ "$TRANSCRIPT_RESULT" = "true" ]; then
    echo -e "${GREEN}  ✓ Brands detected from transcript${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}  ✗ Failed to detect brands${NC}"
    ((TESTS_FAILED++))
fi

# Test gender detection
echo -e "\n${YELLOW}Testing demographic inference...${NC}"
GENDER_RESULT=$(psql "$DB_URL" -t -c "
SELECT scout.process_transcript(
    'TEST-GENDER',
    'Kuya, may yosi ba kayo?'
)::jsonb->>'gender';
" 2>/dev/null | xargs)

if [ "$GENDER_RESULT" = "male" ]; then
    echo -e "${GREEN}  ✓ Gender correctly detected as male (from 'Kuya')${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}  ✗ Gender detection failed${NC}"
    ((TESTS_FAILED++))
fi

echo -e "\n${CYAN}═══ Test Suite 4: Dataset Publishing ═══${NC}"

# Test dataset publishing
echo -e "\n${YELLOW}Publishing test dataset...${NC}"
PUBLISH_RESULT=$(psql "$DB_URL" -t -c "
SELECT public.publish_scout_dataset(
    'test/scout/daily_' || to_char(NOW(), 'YYYYMMDD'),
    'test',
    '/test/path.parquet',
    1024000,
    100,
    '1.0.0'
)::jsonb->>'success';
" 2>/dev/null | xargs)

if [ "$PUBLISH_RESULT" = "true" ]; then
    echo -e "${GREEN}  ✓ Dataset published successfully${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}  ✗ Dataset publishing failed${NC}"
    ((TESTS_FAILED++))
fi

echo -e "\n${CYAN}═══ Test Suite 5: Integration Tests ═══${NC}"

# Test cross-system integration
run_test "Integration function exists" \
    "SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'complete_system_integration')" \
    "t"

echo -e "\n${YELLOW}Testing system integration status...${NC}"
INTEGRATION_STATUS=$(psql "$DB_URL" -t -c "
SELECT public.complete_system_integration()::jsonb->>'integration_ready';
" 2>/dev/null | xargs)

if [ "$INTEGRATION_STATUS" = "true" ]; then
    echo -e "${GREEN}  ✓ System integration verified${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}  ✗ System integration check failed${NC}"
    ((TESTS_FAILED++))
fi

echo -e "\n${CYAN}═══ Test Suite 6: Performance Tests ═══${NC}"

# Test query performance
echo -e "\n${YELLOW}Testing query performance...${NC}"
START_TIME=$(date +%s%N)
psql "$DB_URL" -c "
SELECT COUNT(*) FROM scout.v_gold_transactions_flat;
" > /dev/null 2>&1
END_TIME=$(date +%s%N)
ELAPSED=$((($END_TIME - $START_TIME) / 1000000))

if [ $ELAPSED -lt 1500 ]; then
    echo -e "${GREEN}  ✓ Query completed in ${ELAPSED}ms (< 1500ms SLA)${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}  ⚠ Query took ${ELAPSED}ms (> 1500ms SLA)${NC}"
    ((TESTS_FAILED++))
fi

echo -e "\n${CYAN}═══ Test Suite 7: View Accessibility ═══${NC}"

# Test key views
VIEWS=("v_gold_transactions_flat" "v_migration_summary" "v_dataset_health_dashboard")
for view in "${VIEWS[@]}"; do
    run_test "View $view accessible" \
        "SELECT EXISTS (SELECT 1 FROM scout.$view LIMIT 1)" \
        "t"
done

echo -e "\n${CYAN}═══ Test Suite 8: Brand Detection Functions ═══${NC}"

# Test fuzzy brand matching
echo -e "\n${YELLOW}Testing fuzzy brand matching...${NC}"
FUZZY_RESULT=$(psql "$DB_URL" -t -c "
SELECT COUNT(*) FROM scout.fuzzy_brand_match('I want some Lucky Me noodles and Coca Cola');
" 2>/dev/null | xargs)

if [ "$FUZZY_RESULT" -gt 0 ]; then
    echo -e "${GREEN}  ✓ Fuzzy brand matching works (found $FUZZY_RESULT brands)${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}  ✗ Fuzzy brand matching failed${NC}"
    ((TESTS_FAILED++))
fi

# Cleanup test data
echo -e "\n${YELLOW}Cleaning up test data...${NC}"
psql "$DB_URL" -c "
DELETE FROM scout.fact_transactions WHERE source_file = 'test-suite';
DELETE FROM usage_analytics.dataset_metadata WHERE category = 'test';
" > /dev/null 2>&1

# Final Report
echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Test Results Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
PASS_RATE=$((TESTS_PASSED * 100 / TOTAL_TESTS))

echo -e "\nTotal Tests: ${TOTAL_TESTS}"
echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
echo -e "Pass Rate: ${PASS_RATE}%"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ ALL TESTS PASSED! System is fully operational.${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed. Please review the output above.${NC}"
    exit 1
fi
