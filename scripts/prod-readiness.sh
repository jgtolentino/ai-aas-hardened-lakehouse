#!/bin/bash

# Scout Analytics Platform - Production Readiness Gate
# Automated GO/NO-GO decision for production deployment

set -e

echo "🚀 Scout Analytics Platform - Production Readiness Gate"
echo "====================================================="
echo "Running comprehensive checks for production deployment..."
echo

# Configuration
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="$REPO_ROOT/prod-gate-reports"
REPORT_FILE="$REPORT_DIR/prod-gate-${TIMESTAMP}.log"

# Database configuration
DB_URL="${SUPABASE_DB_URL:-postgresql://postgres.cxzllzyxwpyptfretryc:YOUR_PASSWORD@aws-0-us-west-1.pooler.supabase.com:6543/postgres}"

# Exit codes
EXIT_SUCCESS=0
EXIT_SECURITY_FAIL=1
EXIT_PERFORMANCE_FAIL=2
EXIT_DATA_QUALITY_FAIL=3
EXIT_RLS_FAIL=4
EXIT_DEPLOYMENT_FAIL=5

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Gate status tracking
GATE_PASSED=true
FAILURES=()

# Create report directory
mkdir -p "$REPORT_DIR"

# Logging function
log() {
    echo -e "$1" | tee -a "$REPORT_FILE"
}

# Gate check function
run_gate_check() {
    local check_name="$1"
    local check_command="$2"
    local success_pattern="$3"
    local failure_exit_code="$4"
    
    log "${BLUE}🔍 Running: $check_name${NC}"
    
    if output=$($check_command 2>&1); then
        if echo "$output" | grep -q "$success_pattern"; then
            log "${GREEN}  ✅ PASSED${NC}"
            echo "$output" >> "$REPORT_FILE"
            return 0
        else
            log "${RED}  ❌ FAILED - Did not meet criteria${NC}"
            echo "$output" >> "$REPORT_FILE"
            GATE_PASSED=false
            FAILURES+=("$check_name")
            return 1
        fi
    else
        log "${RED}  ❌ FAILED - Command error${NC}"
        echo "$output" >> "$REPORT_FILE"
        GATE_PASSED=false
        FAILURES+=("$check_name")
        return 1
    fi
}

# 1. Security Scanning with Trivy
security_scan() {
    log "${YELLOW}🔒 Security Scanning${NC}"
    
    # Check if Trivy is installed
    if ! command -v trivy &> /dev/null; then
        log "${YELLOW}  ⚠️  Trivy not installed, installing...${NC}"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install trivy
        else
            curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
        fi
    fi
    
    # Scan for vulnerabilities
    cd "$REPO_ROOT"
    
    # Scan filesystem
    if trivy fs . --severity CRITICAL,HIGH --exit-code 1 > "$REPORT_DIR/trivy-fs-${TIMESTAMP}.log" 2>&1; then
        log "${GREEN}  ✅ No critical/high vulnerabilities in filesystem${NC}"
    else
        log "${RED}  ❌ Critical/high vulnerabilities found${NC}"
        GATE_PASSED=false
        FAILURES+=("Security: Filesystem vulnerabilities")
    fi
    
    # Scan Docker images if present
    if [ -f "Dockerfile" ]; then
        if trivy config . --severity CRITICAL,HIGH --exit-code 1 > "$REPORT_DIR/trivy-config-${TIMESTAMP}.log" 2>&1; then
            log "${GREEN}  ✅ No critical/high vulnerabilities in config${NC}"
        else
            log "${RED}  ❌ Critical/high vulnerabilities in config${NC}"
            GATE_PASSED=false
            FAILURES+=("Security: Config vulnerabilities")
        fi
    fi
}

# 2. Performance Testing with k6
performance_test() {
    log "${YELLOW}⚡ Performance Testing${NC}"
    
    # Check if k6 is installed
    if ! command -v k6 &> /dev/null; then
        log "${YELLOW}  ⚠️  k6 not installed, installing...${NC}"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install k6
        else
            curl -s https://dl.k6.io/key.gpg | apt-key add -
            echo "deb https://dl.k6.io/deb stable main" | tee /etc/apt/sources.list.d/k6.list
            apt-get update && apt-get install k6
        fi
    fi
    
    # Run performance tests
    if [ -f "$REPO_ROOT/scripts/k6/api-readiness.js" ]; then
        cd "$REPO_ROOT"
        if k6 run scripts/k6/api-readiness.js --out json="$REPORT_DIR/k6-results-${TIMESTAMP}.json" 2>&1 | tee "$REPORT_DIR/k6-output-${TIMESTAMP}.log"; then
            log "${GREEN}  ✅ Performance tests passed${NC}"
        else
            log "${RED}  ❌ Performance tests failed${NC}"
            GATE_PASSED=false
            FAILURES+=("Performance: k6 tests failed")
        fi
    else
        log "${YELLOW}  ⚠️  No k6 tests found, skipping${NC}"
    fi
}

# 3. Data Quality Checks
data_quality_check() {
    log "${YELLOW}📊 Data Quality Checks${NC}"
    
    # Run DQ SQL script
    if [ -f "$REPO_ROOT/scripts/sql/dq_gate.sql" ]; then
        if output=$(psql "$DB_URL" -f "$REPO_ROOT/scripts/sql/dq_gate.sql" 2>&1); then
            echo "$output" > "$REPORT_DIR/dq-results-${TIMESTAMP}.log"
            
            # Check if all DQ checks passed
            if echo "$output" | grep -q "FAIL"; then
                log "${RED}  ❌ Data quality checks failed${NC}"
                echo "$output" | grep "FAIL" | head -5
                GATE_PASSED=false
                FAILURES+=("Data Quality: Failed checks")
            else
                log "${GREEN}  ✅ All data quality checks passed${NC}"
            fi
        else
            log "${RED}  ❌ Error running data quality checks${NC}"
            GATE_PASSED=false
            FAILURES+=("Data Quality: Script error")
        fi
    else
        log "${YELLOW}  ⚠️  No DQ checks found, skipping${NC}"
    fi
}

# 4. RLS Security Checks
rls_check() {
    log "${YELLOW}🔐 Row Level Security Checks${NC}"
    
    # Run RLS SQL script
    if [ -f "$REPO_ROOT/scripts/sql/rls_check.sql" ]; then
        if output=$(psql "$DB_URL" -f "$REPO_ROOT/scripts/sql/rls_check.sql" 2>&1); then
            echo "$output" > "$REPORT_DIR/rls-results-${TIMESTAMP}.log"
            
            # Check if all RLS checks passed
            if echo "$output" | grep -q "FAIL - Critical security issues"; then
                log "${RED}  ❌ Critical RLS security issues found${NC}"
                echo "$output" | grep "CRITICAL" | head -5
                GATE_PASSED=false
                FAILURES+=("RLS: Critical security issues")
            elif echo "$output" | grep -q "FAIL - Security issues"; then
                log "${YELLOW}  ⚠️  Non-critical RLS issues found${NC}"
                echo "$output" | grep "FAIL" | head -5
            else
                log "${GREEN}  ✅ All RLS checks passed${NC}"
            fi
        else
            log "${RED}  ❌ Error running RLS checks${NC}"
            GATE_PASSED=false
            FAILURES+=("RLS: Script error")
        fi
    else
        log "${YELLOW}  ⚠️  No RLS checks found, skipping${NC}"
    fi
}

# 5. Deployment Readiness Checks
deployment_check() {
    log "${YELLOW}🚀 Deployment Readiness${NC}"
    
    # Check for required files
    required_files=(
        "package.json"
        ".env.example"
        "README.md"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$REPO_ROOT/$file" ]; then
            log "${GREEN}  ✅ Required file exists: $file${NC}"
        else
            log "${RED}  ❌ Missing required file: $file${NC}"
            GATE_PASSED=false
            FAILURES+=("Deployment: Missing $file")
        fi
    done
    
    # Check Node.js build
    if [ -f "$REPO_ROOT/package.json" ]; then
        cd "$REPO_ROOT"
        
        # Install dependencies
        if npm ci --production=false > "$REPORT_DIR/npm-install-${TIMESTAMP}.log" 2>&1; then
            log "${GREEN}  ✅ Dependencies installed successfully${NC}"
        else
            log "${RED}  ❌ Failed to install dependencies${NC}"
            GATE_PASSED=false
            FAILURES+=("Deployment: npm install failed")
        fi
        
        # Run build
        if npm run build > "$REPORT_DIR/npm-build-${TIMESTAMP}.log" 2>&1; then
            log "${GREEN}  ✅ Build completed successfully${NC}"
        else
            log "${RED}  ❌ Build failed${NC}"
            GATE_PASSED=false
            FAILURES+=("Deployment: npm build failed")
        fi
        
        # Run tests if available
        if npm run test > "$REPORT_DIR/npm-test-${TIMESTAMP}.log" 2>&1; then
            log "${GREEN}  ✅ Tests passed${NC}"
        else
            log "${YELLOW}  ⚠️  Tests failed or not configured${NC}"
        fi
    fi
}

# 6. Kubernetes Readiness (if applicable)
k8s_check() {
    log "${YELLOW}☸️  Kubernetes Readiness${NC}"
    
    # Check for k8s manifests
    if [ -d "$REPO_ROOT/k8s" ] || [ -d "$REPO_ROOT/.k8s" ]; then
        # Validate manifests
        for manifest in $(find "$REPO_ROOT" -name "*.yaml" -o -name "*.yml" | grep -E "(k8s|kubernetes|deploy)"); do
            if kubectl apply --dry-run=client -f "$manifest" > /dev/null 2>&1; then
                log "${GREEN}  ✅ Valid manifest: $(basename $manifest)${NC}"
            else
                log "${RED}  ❌ Invalid manifest: $(basename $manifest)${NC}"
                GATE_PASSED=false
                FAILURES+=("K8s: Invalid manifest $(basename $manifest)")
            fi
        done
    else
        log "${BLUE}  ℹ️  No Kubernetes manifests found${NC}"
    fi
}

# Generate Summary Report
generate_report() {
    log ""
    log "${YELLOW}📋 Production Readiness Gate Summary${NC}"
    log "===================================="
    log "Timestamp: $(date)"
    log "Repository: $REPO_ROOT"
    log ""
    
    if [ "$GATE_PASSED" = true ]; then
        log "${GREEN}🎉 GATE STATUS: PASSED${NC}"
        log "All production readiness checks passed!"
        exit_code=$EXIT_SUCCESS
    else
        log "${RED}❌ GATE STATUS: FAILED${NC}"
        log ""
        log "Failed checks:"
        for failure in "${FAILURES[@]}"; do
            log "  - $failure"
        done
        
        # Determine exit code based on failures
        if [[ " ${FAILURES[@]} " =~ " Security: " ]]; then
            exit_code=$EXIT_SECURITY_FAIL
        elif [[ " ${FAILURES[@]} " =~ " Performance: " ]]; then
            exit_code=$EXIT_PERFORMANCE_FAIL
        elif [[ " ${FAILURES[@]} " =~ " Data Quality: " ]]; then
            exit_code=$EXIT_DATA_QUALITY_FAIL
        elif [[ " ${FAILURES[@]} " =~ " RLS: " ]]; then
            exit_code=$EXIT_RLS_FAIL
        else
            exit_code=$EXIT_DEPLOYMENT_FAIL
        fi
    fi
    
    log ""
    log "Full report saved to: $REPORT_FILE"
    log ""
    
    # Create summary JSON
    cat > "$REPORT_DIR/prod-gate-summary-${TIMESTAMP}.json" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "gate_passed": $GATE_PASSED,
  "total_checks": 6,
  "failed_checks": ${#FAILURES[@]},
  "failures": $(printf '%s\n' "${FAILURES[@]}" | jq -R . | jq -s .),
  "report_file": "$REPORT_FILE",
  "exit_code": $exit_code
}
EOF
    
    return $exit_code
}

# Main execution
main() {
    log "Starting production readiness gate checks..."
    log ""
    
    # Run all checks
    security_scan
    performance_test
    data_quality_check
    rls_check
    deployment_check
    k8s_check
    
    # Generate report and exit
    generate_report
    exit $?
}

# Run main
main