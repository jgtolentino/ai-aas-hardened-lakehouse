#!/bin/bash
set -euo pipefail

echo "🔒 Testing Security Pipeline Locally"
echo "==================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if docker image exists
check_image() {
    local image=$1
    if docker image inspect "$image" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $image available"
        return 0
    else
        echo -e "${RED}✗${NC} $image not available"
        return 1
    fi
}

# Function to run test and show result
run_test() {
    local name=$1
    local cmd=$2
    echo -e "\n${YELLOW}Running: $name${NC}"
    
    if eval "$cmd"; then
        echo -e "${GREEN}✓ $name passed${NC}"
        return 0
    else
        echo -e "${RED}✗ $name failed${NC}"
        return 1
    fi
}

# Check required Docker images
echo -e "\n${YELLOW}Checking Scanner Images...${NC}"
TRIVY_IMAGE="aquasec/trivy@sha256:7dc2d3f9c63f6e63d0f7b21a0d9d4e9e0d776b7a4b6d3a1b4cb6b2a6f5e37b39"
SEMGREP_IMAGE="returntocorp/semgrep@sha256:3a5608b3b8e0f2b6f2e3a9c7a7b6b3d1bfb8a0a2a45e9f0a9f2db46be8d9ae9a"
TRUFFLEHOG_IMAGE="trufflesecurity/trufflehog@sha256:2f2a1a7c6e38de8e0d4a0fb0b7f7b5d86ebc27b8c3f1d35f8a0a54c953fdfb33"

# Note: Using latest tags for local testing since digest verification is complex locally
check_image "aquasec/trivy:latest" || echo "Run: docker pull aquasec/trivy:latest"
check_image "returntocorp/semgrep:latest" || echo "Run: docker pull returntocorp/semgrep:latest"  
check_image "trufflesecurity/trufflehog:latest" || echo "Run: docker pull trufflesecurity/trufflehog:latest"

# Create cache directory
mkdir -p .cache/trivy

# Test 1: Trivy filesystem scan
run_test "Trivy FS scan" "
docker run --rm \\
  -v \$PWD:/workspace -v \$PWD/.cache/trivy:/root/.cache/trivy \\
  -w /workspace \\
  aquasec/trivy:latest \\
  fs --exit-code 0 --format sarif --output trivy_test.sarif \\
  --ignorefile security/allowlists/.trivyignore \\
  --severity CRITICAL,HIGH,MEDIUM \\
  security/
"

# Test 2: Semgrep SAST scan
run_test "Semgrep SAST scan" "
docker run --rm -v \$PWD:/src returntocorp/semgrep:latest \\
  semgrep --config 'p/owasp-top-ten' \\
          --config 'rules/semgrep' \\
          --exclude 'node_modules' --exclude 'dist' --exclude 'build' \\
          --sarif --output semgrep_test.sarif \\
          --severity WARNING || true
"

# Test 3: TruffleHog secrets scan (filesystem only for testing)
run_test "TruffleHog secrets scan" "
docker run --rm -v \$PWD:/pwd -w /pwd trufflesecurity/trufflehog:latest \\
  filesystem --json --only-verified \\
  security/ | tee trufflehog_test.json || true
"

# Test 4: Policy enforcement
echo -e "\n${YELLOW}Testing Policy Enforcement...${NC}"

# Install dependencies if needed
if ! command -v npx &> /dev/null || ! npx tsx --version &> /dev/null; then
    echo "Installing tsx for policy enforcement..."
    npm install -g tsx
fi

if [ ! -f node_modules/yaml/package.json ]; then
    echo "Installing yaml dependency..."
    npm install yaml
fi

# Test policy enforcement on generated reports
for report in trivy_test.sarif semgrep_test.sarif trufflehog_test.json; do
    if [ -f "$report" ]; then
        run_test "Policy check: $report" "npx tsx security/policy/enforce.ts $report security/policy/policy.yaml"
    else
        echo -e "${YELLOW}⚠ $report not found, skipping policy check${NC}"
    fi
done

# Test 5: Summary generation
if [ -f "trufflehog_test.json" ] && [ -f "trivy_test.sarif" ] && [ -f "semgrep_test.sarif" ]; then
    run_test "Summary generation" "
    node security/policy/summarize.mjs \\
      --truffle trufflehog_test.json \\
      --trivy trivy_test.sarif \\
      --semgrep semgrep_test.sarif \\
      --slack-out slack_test.json
    "
    
    if [ -f "slack_test.json" ]; then
        echo -e "${GREEN}Generated Slack payload:${NC}"
        cat slack_test.json | head -10
    fi
fi

# Cleanup
echo -e "\n${YELLOW}Cleaning up test files...${NC}"
rm -f trivy_test.sarif semgrep_test.sarif trufflehog_test.json slack_test.json

echo -e "\n${GREEN}🎉 Security pipeline test complete!${NC}"
echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Review and adjust policy thresholds in security/policy/policy.yaml"
echo "2. Add more custom Semgrep rules in rules/semgrep/"
echo "3. Set up SLACK_WEBHOOK_URL secret in GitHub repository"
echo "4. Test the workflows by opening a PR"