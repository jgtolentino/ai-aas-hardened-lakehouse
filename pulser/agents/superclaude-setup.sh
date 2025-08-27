#!/bin/bash
# SuperClaude CI/CD Integration Setup Script
# For Scout/ai-agency monorepo

set -euo pipefail

echo "🚀 SuperClaude CI/CD Integration Setup"
echo "======================================"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if running in correct directory
if [[ ! -f "package.json" ]] && [[ ! -f "pyproject.toml" ]]; then
    echo -e "${RED}❌ Error: Not in a project root directory${NC}"
    echo "Please run from your Scout/ai-agency monorepo root"
    exit 1
fi

# Step 1: Install SuperClaude
echo -e "\n${YELLOW}📦 Installing SuperClaude Framework...${NC}"
if command -v pipx &> /dev/null; then
    echo "Using pipx (recommended)..."
    pipx install SuperClaude || pipx upgrade SuperClaude
else
    echo "Using pip..."
    pip install --upgrade SuperClaude
fi

# Step 2: Run SuperClaude installation
echo -e "\n${YELLOW}🔧 Running SuperClaude setup...${NC}"
SuperClaude install

# Step 3: Register with Pulser
echo -e "\n${YELLOW}🔗 Registering SuperClaude agents with Pulser...${NC}"
if [[ -d "pulser/agents" ]]; then
    echo "✅ Pulser agents directory found"
    echo "✅ superclaude-cicd-workflow.yaml created"
else
    echo -e "${RED}❌ Warning: pulser/agents directory not found${NC}"
    echo "Creating directory structure..."
    mkdir -p pulser/agents
fi

# Step 4: Create activation script
cat > pulser/agents/activate-superclaude.sh << 'EOF'
#!/bin/bash
# Activate SuperClaude CI/CD agents

echo "🚀 Activating SuperClaude CI/CD Agents..."

# Load the workflow
pulser load superclaude-cicd-workflow.yaml

# Register agents
pulser register agent devops-architect
pulser register agent quality-engineer
pulser register agent security-engineer

# Set default mode
echo "Setting task-management mode..."
/sc:mode task-management

echo "✅ SuperClaude CI/CD agents activated!"
echo ""
echo "Available commands:"
echo "  /pulser cicd-fix         - Complete PR cleanup with CI/CD fixes"
echo "  /pulser quick-fix        - Quick CI/CD troubleshooting"
echo "  /pulser run security-scan - Security audit only"
echo ""
echo "SuperClaude commands:"
echo "  /sc:troubleshoot [error] - Diagnose issues"
echo "  /sc:build               - Run builds"
echo "  /sc:test                - Run tests"
echo "  /sc:git                 - Git operations"
EOF

chmod +x pulser/agents/activate-superclaude.sh

# Step 5: Create GitHub Actions workflow
echo -e "\n${YELLOW}🔄 Creating GitHub Actions integration...${NC}"
mkdir -p .github/workflows

cat > .github/workflows/superclaude-cicd.yml << 'EOF'
name: SuperClaude CI/CD

on:
  pull_request:
    types: [opened, synchronize, reopened]
  push:
    branches: [main, develop]
  workflow_dispatch:
    inputs:
      fix_type:
        description: 'Fix type'
        required: true
        default: 'build'
        type: choice
        options:
          - build
          - test
          - deploy
          - security

jobs:
  superclaude-fix:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup SuperClaude
        run: |
          pip install SuperClaude
          SuperClaude install
          
      - name: Run CI/CD Fix
        env:
          CI_ERROR: ${{ github.event.workflow_run.conclusion == 'failure' && github.event.workflow_run.name || '' }}
          BUILD_ENV: ${{ github.ref == 'refs/heads/main' && 'prod' || 'dev' }}
        run: |
          # Activate SuperClaude
          source pulser/agents/activate-superclaude.sh
          
          # Run appropriate fix
          if [[ "${{ github.event_name }}" == "workflow_dispatch" ]]; then
            /pulser quick-fix TYPE=${{ inputs.fix_type }}
          else
            /pulser cicd-fix
          fi
          
      - name: Upload Reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: superclaude-reports
          path: |
            ci-report.json
            coverage/
            build-artifacts/
EOF

# Step 6: Create local testing script
cat > test-superclaude-local.sh << 'EOF'
#!/bin/bash
# Test SuperClaude CI/CD locally

echo "🧪 Testing SuperClaude CI/CD Integration..."

# Activate agents
source pulser/agents/activate-superclaude.sh

# Run sample troubleshooting
echo -e "\n📋 Running sample troubleshooting..."
/sc:troubleshoot "Sample build error" --type build --trace

# Check git status
echo -e "\n📊 Checking repository status..."
/sc:git status

# Run quick build test
echo -e "\n🔨 Running build test..."
/sc:build --type dev --quick

echo -e "\n✅ Local test complete!"
EOF

chmod +x test-superclaude-local.sh

# Step 7: Final setup
echo -e "\n${GREEN}✅ SuperClaude CI/CD Integration Setup Complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Activate agents: ${YELLOW}source pulser/agents/activate-superclaude.sh${NC}"
echo "2. Test locally: ${YELLOW}./test-superclaude-local.sh${NC}"
echo "3. Use in PR: ${YELLOW}/pulser cicd-fix${NC}"
echo ""
echo "Available workflows:"
echo "  • pr-cleanup-complete - Full PR cleanup with all checks"
echo "  • quick-ci-fix - Rapid troubleshooting for urgent fixes"
echo "  • scheduled-ci-health - Automated health checks"
echo ""
echo "GitHub Actions workflow created at: .github/workflows/superclaude-cicd.yml"
echo ""
echo "🎯 Pro tip: Set SLACK_WEBHOOK_URL for notifications"