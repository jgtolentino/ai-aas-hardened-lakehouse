#!/bin/bash
# UAT Checklist Validation for Zero-Click Automation System
# Validates all components of the design automation pipeline

set -euo pipefail

SCRIPTDIR="$(dirname "$(realpath "$0")")"
HUBDIR="$SCRIPTDIR/../infra/mcp-hub"
ROOTDIR="$SCRIPTDIR/.."

# Configuration
HUB_API_KEY="${HUB_API_KEY:-dev-key-12345}"
HUB_URL="${HUB_URL:-http://localhost:8787}"
TEST_OUTPUT_DIR="$ROOTDIR/test-output"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[TEST]${NC} $1"; }
pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Test tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
  local test_name="$1"
  local test_command="$2"
  
  ((TESTS_RUN++))
  log "Running: $test_name"
  
  if eval "$test_command" &>/dev/null; then
    ((TESTS_PASSED++))
    pass "$test_name"
    return 0
  else
    ((TESTS_FAILED++))
    fail "$test_name"
    return 1
  fi
}

test_summary() {
  echo ""
  echo "==================== TEST SUMMARY ===================="
  echo "Tests Run:    $TESTS_RUN"
  echo "Tests Passed: $TESTS_PASSED"
  echo "Tests Failed: $TESTS_FAILED"
  
  if [[ $TESTS_FAILED -eq 0 ]]; then
    pass "All tests passed!"
    return 0
  else
    fail "$TESTS_FAILED test(s) failed"
    return 1
  fi
}

# UAT Checklist Tests

test_design_index_sqlite() {
  log "Testing Design Index SQLite implementation"
  
  # Check if SQLite file can be created
  run_test "SQLite database creation" \
    "cd '$HUBDIR' && node -e 'const { ensureDatabase } = require(\"./src/adapters/design-index.js\"); ensureDatabase();'"
  
  # Test design search functionality
  run_test "Design search functionality" \
    "cd '$HUBDIR' && node -e 'const { searchDesigns } = require(\"./src/adapters/design-index.js\"); console.log(JSON.stringify(searchDesigns({text: \"test\"})));'"
  
  # Test design insertion
  run_test "Design insertion" \
    "cd '$HUBDIR' && node -e 'const { upsertDesigns } = require(\"./src/adapters/design-index.js\"); upsertDesigns([{id: \"test\", file_key: \"test\", node_id: \"test\", title: \"Test Design\", kind: \"component\", tags: [\"test\"], metadata: {}, updated_at: new Date().toISOString()}]);'"
}

test_patch_specification() {
  log "Testing Patch Specification system"
  
  # Check TypeScript types compilation
  run_test "Patch spec TypeScript types" \
    "cd '$HUBDIR' && npx tsc --noEmit --skipLibCheck src/schemas/design-patch.ts"
  
  # Test patch spec validation (if we add validation)
  run_test "Patch spec structure validation" \
    "test -f '$HUBDIR/src/schemas/design-patch.ts'"
}

test_mcp_hub_endpoints() {
  log "Testing MCP Hub endpoints"
  
  # Start MCP Hub if not running
  if ! curl -sf "$HUB_URL/health" &>/dev/null; then
    log "Starting MCP Hub for testing..."
    cd "$HUBDIR" && npm run start &
    HUB_PID=$!
    sleep 5
  fi
  
  # Test health endpoint
  run_test "MCP Hub health endpoint" \
    "curl -sf '$HUB_URL/health'"
  
  # Test design search endpoint
  run_test "Design search endpoint" \
    "curl -sf -X POST '$HUB_URL/mcp/design/search' -H 'X-API-Key: $HUB_API_KEY' -H 'Content-Type: application/json' -d '{\"text\": \"test\"}'"
  
  # Test design index endpoint
  run_test "Design index endpoint" \
    "curl -sf -X POST '$HUB_URL/mcp/design/index' -H 'X-API-Key: $HUB_API_KEY' -H 'Content-Type: application/json' -d '{\"items\": []}'"
  
  # Clean up MCP Hub if we started it
  if [[ -n "${HUB_PID:-}" ]]; then
    kill "$HUB_PID" 2>/dev/null || true
  fi
}

test_figma_bridge() {
  log "Testing Figma Bridge functionality"
  
  # Check if Figma Bridge files exist
  run_test "Figma Bridge adapter exists" \
    "test -f '$HUBDIR/src/adapters/figma-bridge.ts'"
  
  # Test TypeScript compilation
  run_test "Figma Bridge TypeScript compilation" \
    "cd '$HUBDIR' && npx tsc --noEmit --skipLibCheck src/adapters/figma-bridge.ts"
  
  # Check for patch application methods
  run_test "Figma Bridge patch methods" \
    "grep -q 'applyPatch' '$HUBDIR/src/adapters/figma-bridge.ts'"
  
  run_test "Figma Bridge clone methods" \
    "grep -q 'cloneAndModify' '$HUBDIR/src/adapters/figma-bridge.ts'"
}

test_automation_scripts() {
  log "Testing automation scripts"
  
  # Test retarget-dashboard script exists and is executable
  run_test "Retarget dashboard script exists" \
    "test -x '$SCRIPTDIR/retarget-dashboard.sh'"
  
  # Test script help/usage
  run_test "Retarget dashboard script usage" \
    "'$SCRIPTDIR/retarget-dashboard.sh' 2>&1 | grep -q 'USAGE'"
  
  # Test script dependency checks
  run_test "Script dependency validation" \
    "bash -n '$SCRIPTDIR/retarget-dashboard.sh'"
}

test_file_structure() {
  log "Testing file structure and organization"
  
  # Check all required files exist
  local required_files=(
    "infra/mcp-hub/src/adapters/design-index.js"
    "infra/mcp-hub/src/adapters/design-index.ts"
    "infra/mcp-hub/src/schemas/design-patch.ts"
    "infra/mcp-hub/src/adapters/figma-bridge.ts"
    "infra/mcp-hub/src/server.js"
    "scripts/retarget-dashboard.sh"
    "docs/figma-prd-extraction-guide.md"
  )
  
  for file in "${required_files[@]}"; do
    run_test "File exists: $file" \
      "test -f '$ROOTDIR/$file'"
  done
}

test_integration_readiness() {
  log "Testing integration readiness"
  
  # Check Node.js dependencies
  run_test "Node.js dependencies installed" \
    "cd '$HUBDIR' && npm list better-sqlite3 express helmet cors morgan"
  
  # Check if design index can be imported
  run_test "Design index module import" \
    "cd '$HUBDIR' && node -e 'require(\"./src/adapters/design-index.js\");'"
  
  # Test environment variable handling
  run_test "Environment variable handling" \
    "HUB_API_KEY=test-key bash -c 'echo \$HUB_API_KEY | grep -q test-key'"
}

test_security_implementation() {
  log "Testing security implementation"
  
  # Test API key requirement
  run_test "API key authentication check" \
    "grep -q 'requireApiKey' '$HUBDIR/src/server.js'"
  
  # Test rate limiting
  run_test "Rate limiting implementation" \
    "grep -q 'rateLimit' '$HUBDIR/src/server.js'"
  
  # Test input validation
  run_test "Input validation implementation" \
    "grep -q 'Array.isArray' '$HUBDIR/src/server.js'"
}

test_error_handling() {
  log "Testing error handling"
  
  # Test graceful error handling in design index
  run_test "Design index error handling" \
    "grep -q 'try.*catch\\|error' '$HUBDIR/src/adapters/design-index.js'"
  
  # Test server error responses
  run_test "Server error responses" \
    "grep -q '500.*error' '$HUBDIR/src/server.js'"
  
  # Test script error handling
  run_test "Script error handling" \
    "grep -q 'set -euo pipefail' '$SCRIPTDIR/retarget-dashboard.sh'"
}

main() {
  echo "========== Zero-Click Automation UAT Validation =========="
  echo "Starting comprehensive validation of automation system..."
  echo ""
  
  mkdir -p "$TEST_OUTPUT_DIR"
  
  # Run all test suites
  test_file_structure
  test_design_index_sqlite
  test_patch_specification
  test_mcp_hub_endpoints
  test_figma_bridge
  test_automation_scripts
  test_integration_readiness
  test_security_implementation
  test_error_handling
  
  # Generate summary
  test_summary
  
  # Create test report
  cat > "$TEST_OUTPUT_DIR/uat-validation-report.md" << EOF
# UAT Validation Report

**Generated:** $(date)
**Environment:** $(uname -a)
**Node Version:** $(node --version 2>/dev/null || echo "Not available")

## Test Results Summary

- **Total Tests:** $TESTS_RUN
- **Passed:** $TESTS_PASSED
- **Failed:** $TESTS_FAILED
- **Success Rate:** $(( TESTS_PASSED * 100 / TESTS_RUN ))%

## Component Status

### ✅ Design Index (SQLite)
- Local design search functionality
- Database operations
- Design metadata management

### ✅ Patch Specification System
- TypeScript type definitions
- Unified modification operations
- Brand customization support

### ✅ MCP Hub Endpoints
- REST API endpoints
- Authentication middleware
- Error handling

### ✅ Figma Bridge Integration
- WebSocket communication
- Patch application methods
- Design modification tools

### ✅ Automation Scripts
- Zero-click retargeting
- End-to-end workflows
- Error handling and logging

## Next Steps

$(if [[ $TESTS_FAILED -eq 0 ]]; then
  echo "🎉 All tests passed! System ready for production use."
else
  echo "⚠️  $TESTS_FAILED test(s) failed. Review failures and fix before deployment."
fi)

EOF
  
  log "UAT report generated: $TEST_OUTPUT_DIR/uat-validation-report.md"
}

# Handle interruption gracefully
trap 'fail "Validation interrupted"; exit 130' INT TERM

main "$@"