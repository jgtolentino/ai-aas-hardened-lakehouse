#!/bin/bash

# Local Test Runner for Dataset Publisher
# Simplified script for running tests during development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_RESULTS_DIR="$PROJECT_ROOT/test-results"

echo -e "${BLUE}🧪 Scout Analytics - Dataset Publisher Test Runner${NC}"
echo "=================================================="

# Parse arguments
TEST_SUITE="all"
VERBOSE=false
CLEANUP=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --suite|-s)
            TEST_SUITE="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --no-cleanup)
            CLEANUP=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -s, --suite SUITE     Test suite to run (all|schema|ingestion|storage|etl|performance|security)"
            echo "  -v, --verbose         Verbose output"
            echo "  --no-cleanup          Don't cleanup test data after run"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    # Run all tests"
            echo "  $0 -s schema          # Run only schema tests"  
            echo "  $0 -v --no-cleanup    # Verbose mode, keep test data"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}🔍 Checking prerequisites...${NC}"
    
    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        echo -e "${RED}❌ Node.js not found. Please install Node.js 18 or later.${NC}"
        exit 1
    fi
    
    # Check Node version
    NODE_VERSION=$(node --version | cut -d'v' -f2)
    REQUIRED_VERSION="18.0.0"
    if ! printf '%s\n%s\n' "$REQUIRED_VERSION" "$NODE_VERSION" | sort -V -C; then
        echo -e "${YELLOW}⚠️  Node.js version $NODE_VERSION detected. Recommend 18+ for best compatibility.${NC}"
    fi
    
    # Check environment variables
    if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_SERVICE_KEY" ]]; then
        echo -e "${RED}❌ Missing required environment variables:${NC}"
        echo "   SUPABASE_URL and SUPABASE_SERVICE_KEY must be set"
        echo ""
        echo "   Example:"
        echo "   export SUPABASE_URL=https://your-project.supabase.co"
        echo "   export SUPABASE_SERVICE_KEY=your-service-role-key"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites check passed${NC}"
}

# Setup test environment
setup_environment() {
    echo -e "${BLUE}⚙️  Setting up test environment...${NC}"
    
    # Create test directories
    mkdir -p "$TEST_RESULTS_DIR"
    mkdir -p "$PROJECT_ROOT/test-data"
    mkdir -p "$PROJECT_ROOT/test-temp"
    
    # Install dependencies if needed
    if [[ ! -d "$PROJECT_ROOT/node_modules" ]]; then
        echo -e "${YELLOW}📦 Installing dependencies...${NC}"
        cd "$PROJECT_ROOT" && npm install --silent
    fi
    
    echo -e "${GREEN}✅ Environment setup complete${NC}"
}

# Run the tests
run_tests() {
    echo -e "${BLUE}🚀 Running tests...${NC}"
    echo "Test suite: $TEST_SUITE"
    echo "Verbose: $VERBOSE"
    echo ""
    
    cd "$PROJECT_ROOT"
    
    # Set test environment
    export TEST_SUITE="$TEST_SUITE"
    export TEST_VERBOSE="$VERBOSE"
    
    # Run the test script
    if [[ "$VERBOSE" == "true" ]]; then
        node tests/dataset-publisher.test.js
    else
        node tests/dataset-publisher.test.js 2>/dev/null || {
            echo -e "${RED}❌ Tests failed. Run with -v for detailed output.${NC}"
            exit 1
        }
    fi
}

# Parse test results
parse_results() {
    echo -e "${BLUE}📊 Analyzing results...${NC}"
    
    # Find the latest test results file
    LATEST_RESULT=$(ls -t "$TEST_RESULTS_DIR"/dataset-publisher-*.json 2>/dev/null | head -1)
    
    if [[ -f "$LATEST_RESULT" ]]; then
        echo "📁 Results file: $LATEST_RESULT"
        
        # Parse results using Node.js
        node -e "
        const fs = require('fs');
        const results = JSON.parse(fs.readFileSync('$LATEST_RESULT', 'utf8'));
        
        console.log('');
        console.log('📋 TEST SUMMARY');
        console.log('===============');
        console.log(\`✅ Passed:  \${results.summary.passed}\`);
        console.log(\`❌ Failed:  \${results.summary.failed}\`);
        console.log(\`⏭️  Skipped: \${results.summary.skipped}\`);
        console.log(\`🎯 Success: \${results.summary.successRate}%\`);
        
        if (results.errors.length > 0) {
            console.log('');
            console.log('❌ FAILURES:');
            results.errors.forEach(err => {
                console.log(\`   \${err.test}: \${err.error}\`);
            });
        }
        
        // Return exit code based on results
        process.exit(results.summary.failed > 0 ? 1 : 0);
        "
        
        EXIT_CODE=$?
    else
        echo -e "${RED}❌ No test results found${NC}"
        EXIT_CODE=1
    fi
    
    return $EXIT_CODE
}

# Cleanup test data
cleanup_test_data() {
    if [[ "$CLEANUP" == "true" ]]; then
        echo -e "${BLUE}🧹 Cleaning up test data...${NC}"
        
        # Remove temporary files
        rm -rf "$PROJECT_ROOT/test-temp" 2>/dev/null || true
        
        # Clean up test database records (if possible)
        # Note: This would require additional SQL cleanup commands
        
        echo -e "${GREEN}✅ Cleanup complete${NC}"
    else
        echo -e "${YELLOW}⏭️  Skipping cleanup (--no-cleanup flag)${NC}"
    fi
}

# Health check
health_check() {
    echo -e "${BLUE}🏥 Running health check...${NC}"
    
    # Test database connection
    response=$(curl -s -w "\n%{http_code}" "$SUPABASE_URL/rest/v1/health" \
        -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
        -H "apikey: $SUPABASE_SERVICE_KEY") || {
        echo -e "${RED}❌ Failed to connect to Supabase${NC}"
        return 1
    }
    
    http_code=$(echo "$response" | tail -n1)
    
    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
        echo -e "${GREEN}✅ Supabase connection healthy${NC}"
    else
        echo -e "${RED}❌ Supabase connection failed (HTTP $http_code)${NC}"
        return 1
    fi
    
    # Test storage access
    response=$(curl -s -w "\n%{http_code}" "$SUPABASE_URL/storage/v1/bucket/scout-ingest" \
        -H "Authorization: Bearer $SUPABASE_SERVICE_KEY") || {
        echo -e "${YELLOW}⚠️  Storage bucket test skipped (connection failed)${NC}"
        return 0
    }
    
    http_code=$(echo "$response" | tail -n1)
    
    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
        echo -e "${GREEN}✅ Storage buckets accessible${NC}"
    else
        echo -e "${YELLOW}⚠️  Storage bucket access issues (HTTP $http_code)${NC}"
    fi
}

# Main execution
main() {
    local start_time=$(date +%s)
    
    # Run all steps
    check_prerequisites
    setup_environment
    health_check || {
        echo -e "${RED}❌ Health check failed. Aborting tests.${NC}"
        exit 1
    }
    
    run_tests
    local test_exit_code=$?
    
    parse_results
    local parse_exit_code=$?
    
    cleanup_test_data
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo -e "${BLUE}⏱️  Test execution completed in ${duration}s${NC}"
    
    # Final status
    if [[ $test_exit_code -eq 0 && $parse_exit_code -eq 0 ]]; then
        echo -e "${GREEN}🎉 All tests passed successfully!${NC}"
        exit 0
    else
        echo -e "${RED}💥 Some tests failed. Check the output above for details.${NC}"
        exit 1
    fi
}

# Trap signals for cleanup
trap 'cleanup_test_data' EXIT

# Run main function
main "$@"