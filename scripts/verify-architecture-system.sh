#!/usr/bin/env bash
set -euo pipefail

echo "🔍 Verifying Scout Architecture System Setup"
echo "============================================="

# Check required files exist
echo "📋 Checking documentation files..."
DOCS=(
  "docs/architecture/ARCHITECTURE_GUIDE.md"
  "docs/architecture/SETUP_GUIDE.md" 
  "docs/architecture/README.md"
  "docs/architecture/diagram-manifest.json"
  "docs/architecture/adr/0000-template.md"
  "docs/architecture/MEDALLION_LAKE_ON_S3.md"
)

for doc in "${DOCS[@]}"; do
  if [[ -f "$doc" ]]; then
    echo "  ✅ $doc"
  else
    echo "  ❌ $doc (missing)"
  fi
done

# Check infrastructure files
echo ""
echo "🏗️ Checking infrastructure files..."
INFRA=(
  "infra/data-lake/terraform/versions.tf"
  "infra/data-lake/terraform/variables.tf"
  "infra/data-lake/terraform/main.tf"
  "policies/ingest-policy.json"
  "policies/transform-policy.json"
  "policies/consumer-policy.json" 
  "policies/ml-policy.json"
)

for infra in "${INFRA[@]}"; do
  if [[ -f "$infra" ]]; then
    echo "  ✅ $infra"
  else
    echo "  ❌ $infra (missing)"
  fi
done

# Check scripts
echo ""
echo "🛠️ Checking helper scripts..."
SCRIPTS=(
  "scripts/diagrams/figma-export.mjs"
  "scripts/data-lake/render-policies.sh"
  "scripts/data-lake/bootstrap-prefixes.sh"
)

for script in "${SCRIPTS[@]}"; do
  if [[ -f "$script" ]]; then
    if [[ -x "$script" || "$script" =~ \.mjs$ ]]; then
      echo "  ✅ $script (executable)"
    else
      echo "  ⚠️ $script (not executable)"
    fi
  else
    echo "  ❌ $script (missing)"
  fi
done

# Check GitHub workflow
echo ""
echo "⚙️ Checking GitHub Actions workflow..."
if [[ -f ".github/workflows/diagrams-export.yml" ]]; then
  echo "  ✅ .github/workflows/diagrams-export.yml"
else
  echo "  ❌ .github/workflows/diagrams-export.yml (missing)"
fi

# Check directories
echo ""
echo "📁 Checking directory structure..."
DIRS=(
  "docs/architecture/diagrams"
  "infra/data-lake/terraform"
  "scripts/diagrams"
  "scripts/data-lake"
  "policies"
)

for dir in "${DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    echo "  ✅ $dir/"
  else
    echo "  ❌ $dir/ (missing)"
  fi
done

# Check for Figma setup
echo ""
echo "🎨 Checking Figma integration setup..."
if [[ -n "${FIGMA_TOKEN:-}" ]]; then
  echo "  ✅ FIGMA_TOKEN environment variable set"
else
  echo "  ⚠️ FIGMA_TOKEN not set (needed for export)"
fi

if [[ -n "${FIGMA_FILE_KEY:-}" ]]; then
  echo "  ✅ FIGMA_FILE_KEY environment variable set"
else
  echo "  ⚠️ FIGMA_FILE_KEY not set (needed for export)"
fi

# Check manifest file key
if grep -q "__figma_file_key__" "docs/architecture/diagram-manifest.json" 2>/dev/null; then
  echo "  ⚠️ diagram-manifest.json still has placeholder file key"
else
  echo "  ✅ diagram-manifest.json has real file key"
fi

# Test Node.js/npm for Figma export
echo ""
echo "🟢 Checking Node.js setup..."
if command -v node >/dev/null 2>&1; then
  NODE_VERSION=$(node --version)
  echo "  ✅ Node.js available: $NODE_VERSION"
else
  echo "  ❌ Node.js not found (needed for Figma export)"
fi

# Test AWS CLI if S3 setup intended
echo ""
echo "☁️ Checking AWS CLI setup..."
if command -v aws >/dev/null 2>&1; then
  echo "  ✅ AWS CLI available"
  if aws sts get-caller-identity >/dev/null 2>&1; then
    ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    echo "  ✅ AWS credentials valid (Account: ${ACCOUNT:0:4}****)"
  else
    echo "  ⚠️ AWS credentials not configured"
  fi
else
  echo "  ⚠️ AWS CLI not found (needed for S3 lakehouse)"
fi

# Test Terraform if infrastructure setup intended  
echo ""
echo "🏗️ Checking Terraform setup..."
if command -v terraform >/dev/null 2>&1; then
  TERRAFORM_VERSION=$(terraform --version | head -n1)
  echo "  ✅ Terraform available: $TERRAFORM_VERSION"
else
  echo "  ⚠️ Terraform not found (needed for infrastructure)"
fi

echo ""
echo "📝 Summary & Next Steps"
echo "======================="
echo ""
echo "Your Scout Architecture System has been set up! 🎉"
echo ""
echo "Next steps:"
echo "  1. Follow SETUP_GUIDE.md to configure Figma integration"
echo "  2. Set GitHub secrets: FIGMA_TOKEN and FIGMA_FILE_KEY" 
echo "  3. Test diagram export locally"
echo "  4. Deploy S3 infrastructure if needed"
echo "  5. Start creating architecture diagrams in Figma"
echo ""
echo "For detailed instructions, see:"
echo "  - docs/architecture/SETUP_GUIDE.md"
echo "  - ARCHITECTURE_SYSTEM_README.md"