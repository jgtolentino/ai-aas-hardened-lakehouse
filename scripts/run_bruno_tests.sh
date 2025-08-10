#!/bin/bash
# Run complete Bruno test suite for Scout Analytics including choropleth tests

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BRUNO_DIR="platform/scout/bruno"
ENVIRONMENT="${BRUNO_ENV:-staging}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-pretty}"
FAIL_FAST="${FAIL_FAST:-false}"

echo "🧪 Scout Analytics Bruno Test Suite"
echo "==================================="
echo "Environment: $ENVIRONMENT"
echo "Directory: $BRUNO_DIR"
echo ""

# Check if bruno is installed
if ! command -v bruno &> /dev/null; then
    echo -e "${RED}❌ Bruno CLI not found${NC}"
    echo "Install with: npm install -g @usebruno/cli"
    exit 1
fi

# Check if collection exists
if [ ! -f "$BRUNO_DIR/bruno.json" ]; then
    echo -e "${RED}❌ Bruno collection not found at $BRUNO_DIR${NC}"
    exit 1
fi

# Check if environment file exists
if [ ! -f "$BRUNO_DIR/environments/${ENVIRONMENT}.bru" ]; then
    echo -e "${RED}❌ Environment file not found: $BRUNO_DIR/environments/${ENVIRONMENT}.bru${NC}"
    echo "Available environments:"
    ls -1 "$BRUNO_DIR/environments/" 2>/dev/null | sed 's/\.bru$//' || echo "None found"
    exit 1
fi

# Function to run a specific test group
run_test_group() {
    local group_name=$1
    local test_pattern=$2
    
    echo -e "\n${YELLOW}Running $group_name tests...${NC}"
    
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        bruno run "$BRUNO_DIR" \
            --env "$ENVIRONMENT" \
            --only "$test_pattern" \
            --format json \
            --output "/tmp/bruno_${group_name}.json" 2>/dev/null || return 1
    else
        bruno run "$BRUNO_DIR" \
            --env "$ENVIRONMENT" \
            --only "$test_pattern" || return 1
    fi
    
    echo -e "${GREEN}✅ $group_name tests completed${NC}"
}

# Run tests in sequence
echo -e "${BLUE}Test Execution Plan:${NC}"
echo "1. Authentication & Setup (01-02)"
echo "2. Core Data APIs (03-10)"
echo "3. Ingestion Tests (11-14)"
echo "4. Superset Integration (15-18)"
echo "5. Security Tests (19)"
echo "6. Choropleth Tests (20-21)"

FAILED_GROUPS=()

# 1. Authentication Tests
if ! run_test_group "Authentication" "0[12]_*.bru"; then
    FAILED_GROUPS+=("Authentication")
    if [ "$FAIL_FAST" = "true" ]; then
        echo -e "${RED}❌ Authentication failed, cannot continue${NC}"
        exit 1
    fi
fi

# 2. Core Data APIs
if ! run_test_group "Core APIs" "0[3-9]_*.bru|10_*.bru"; then
    FAILED_GROUPS+=("Core APIs")
    [ "$FAIL_FAST" = "true" ] && exit 1
fi

# 3. Ingestion Tests
if ! run_test_group "Ingestion" "1[1-4]_*.bru"; then
    FAILED_GROUPS+=("Ingestion")
    [ "$FAIL_FAST" = "true" ] && exit 1
fi

# 4. Superset Integration
if ! run_test_group "Superset" "1[5-8]_*.bru"; then
    FAILED_GROUPS+=("Superset")
    [ "$FAIL_FAST" = "true" ] && exit 1
fi

# 5. Security Tests
if ! run_test_group "Security" "19_*.bru"; then
    FAILED_GROUPS+=("Security")
    [ "$FAIL_FAST" = "true" ] && exit 1
fi

# 6. Choropleth Tests
if ! run_test_group "Choropleth" "2[01]_*.bru"; then
    FAILED_GROUPS+=("Choropleth")
    [ "$FAIL_FAST" = "true" ] && exit 1
fi

# Performance Analysis (if JSON output)
if [ "$OUTPUT_FORMAT" = "json" ] && [ -f "/tmp/bruno_Core APIs.json" ]; then
    echo -e "\n${BLUE}Performance Analysis:${NC}"
    
    # Parse JSON results for performance metrics
    python3 - <<'EOF' 2>/dev/null || echo "Install jq for detailed analysis"
import json
import glob
import statistics

perf_data = []
for file in glob.glob('/tmp/bruno_*.json'):
    try:
        with open(file) as f:
            data = json.load(f)
            for result in data.get('results', []):
                if result.get('response', {}).get('responseTime'):
                    perf_data.append({
                        'test': result.get('test', {}).get('name', 'Unknown'),
                        'time': result['response']['responseTime'],
                        'status': result['response'].get('status', 0)
                    })
    except:
        pass

if perf_data:
    times = [p['time'] for p in perf_data]
    print(f"  Total tests: {len(perf_data)}")
    print(f"  Avg response time: {statistics.mean(times):.0f}ms")
    print(f"  P95 response time: {sorted(times)[int(len(times)*0.95)]:.0f}ms")
    print(f"  Max response time: {max(times):.0f}ms")
    
    # Show slowest tests
    slow_tests = sorted(perf_data, key=lambda x: x['time'], reverse=True)[:5]
    if slow_tests:
        print("\n  Slowest tests:")
        for test in slow_tests:
            print(f"    - {test['test']}: {test['time']:.0f}ms")
EOF
fi

# Summary
echo -e "\n${BLUE}======================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}======================================${NC}"

TOTAL_GROUPS=6
PASSED_GROUPS=$((TOTAL_GROUPS - ${#FAILED_GROUPS[@]}))

echo -e "Total test groups: $TOTAL_GROUPS"
echo -e "Passed: ${GREEN}$PASSED_GROUPS${NC}"
echo -e "Failed: ${RED}${#FAILED_GROUPS[@]}${NC}"

if [ ${#FAILED_GROUPS[@]} -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed!${NC}"
    
    # Additional checks for production
    if [ "$ENVIRONMENT" = "production" ]; then
        echo -e "\n${YELLOW}Production Readiness Checklist:${NC}"
        echo "✓ Authentication working"
        echo "✓ Core APIs responding"
        echo "✓ Data ingestion functional"
        echo "✓ Superset integrated"
        echo "✓ Security controls active"
        echo "✓ Choropleth visualization ready"
    fi
    
    exit 0
else
    echo -e "\n${RED}❌ Failed test groups:${NC}"
    for group in "${FAILED_GROUPS[@]}"; do
        echo "  - $group"
    done
    
    echo -e "\n${YELLOW}Troubleshooting:${NC}"
    
    if [[ " ${FAILED_GROUPS[@]} " =~ " Authentication " ]]; then
        echo "• Check Supabase credentials in environments/${ENVIRONMENT}.bru"
        echo "• Verify Supabase project is running"
    fi
    
    if [[ " ${FAILED_GROUPS[@]} " =~ " Superset " ]]; then
        echo "• Check Superset is deployed and accessible"
        echo "• Verify Superset credentials are correct"
        echo "• Ensure CSRF token is being properly handled"
    fi
    
    if [[ " ${FAILED_GROUPS[@]} " =~ " Choropleth " ]]; then
        echo "• Verify PostGIS is enabled in database"
        echo "• Check boundary data is loaded"
        echo "• Ensure Mapbox API key is configured"
    fi
    
    exit 1
fi