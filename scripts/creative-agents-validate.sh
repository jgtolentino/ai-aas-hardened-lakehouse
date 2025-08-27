#!/bin/bash
# Creative Studio Agents Validator
# Validates all creative/studio agents against Anthropic-first standards
# Version: 1.0.0

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CREATIVE_REGISTRY="$ROOT/creative-studio/registry/creative-agents.yaml"
CREATIVE_AGENTS_DIR="$ROOT/creative-studio/agents"
MIN_CREATIVE_AGENTS=20
errors=0
warnings=0

# ANSI colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🎨 Creative Studio Agents Validator v1.0.0${NC}"
echo "======================================================="
echo

# Check if creative registry exists
if [[ ! -f "$CREATIVE_REGISTRY" ]]; then
  echo -e "${RED}✗ Creative registry not found: $CREATIVE_REGISTRY${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Creative registry found${NC}"

# Parse creative registry for agent count
if command -v yq >/dev/null 2>&1; then
  registry_count=$(yq eval '.creative_generators, .design_agents, .intelligence_agents, .studio_ops_agents, .marketing_agents, .engineering_agents, .testing_agents | length' "$CREATIVE_REGISTRY" 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
else
  # Fallback count using grep
  registry_count=$(grep -E '^\s*-\s*codename:' "$CREATIVE_REGISTRY" | wc -l | tr -d ' ')
fi

echo "Registry contains: $registry_count creative agents"

if [[ $registry_count -lt $MIN_CREATIVE_AGENTS ]]; then
  echo -e "${RED}✗ Insufficient creative agents: $registry_count < $MIN_CREATIVE_AGENTS${NC}"
  errors=$((errors+1))
else
  echo -e "${GREEN}✓ Creative agent count meets minimum requirement${NC}"
fi

# Find all creative agent files
echo
echo "Discovering creative agent files..."

CREATIVE_FILES=$(mktemp)
{
  find "$ROOT/creative-studio" -type f \( -iname '*.yml' -o -iname '*.yaml' \) 2>/dev/null || true
  find "$ROOT/CreativeOps" -type f \( -iname '*.yml' -o -iname '*.yaml' \) 2>/dev/null || true
  find "$ROOT" -path "*/contains-studio-agents/*" -type f \( -iname '*.yml' -o -iname '*.yaml' \) 2>/dev/null || true
  find "$ROOT" -path "*/creative-expert/*" -type f \( -iname '*.yml' -o -iname '*.yaml' \) 2>/dev/null || true
  find "$ROOT" -path "*/creative-intelligence*" -type f \( -iname '*.yml' -o -iname '*.yaml' \) 2>/dev/null || true
} | grep -v '/node_modules/' | grep -v '/.git/' | sort -u > "$CREATIVE_FILES"

file_count=$(wc -l < "$CREATIVE_FILES")

echo "Found $file_count creative agent files"
echo

# Validate each creative agent file
while IFS= read -r file; do
  echo "Validating: ${file#$ROOT/}"
  
  # Check if file is readable
  if [[ ! -r "$file" ]]; then
    echo -e "${RED}✗ File not readable: $file${NC}"
    errors=$((errors+1))
    continue
  fi
  
  # Parse YAML (basic check)
  if ! python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
    echo -e "${RED}✗ Invalid YAML syntax: $file${NC}"
    errors=$((errors+1))
    continue
  fi
  
  # Extract key fields using Python
  python_output=$(python3 -c "
import yaml
import sys
try:
    with open('$file', 'r') as f:
        data = yaml.safe_load(f)
    
    metadata = data.get('metadata', {})
    print('ID=' + str(metadata.get('id', metadata.get('codename', 'unknown'))))
    print('CODENAME=' + str(metadata.get('codename', metadata.get('id', 'unknown'))))
    print('VERSION=' + str(metadata.get('version', '0.0.0')))
    print('TYPE=' + str(metadata.get('type', 'unknown')))
    print('OWNER=' + str(metadata.get('owner', '')))
    
    # Check for tools section
    has_tools = 'tools' in data or 'capabilities' in data or ('metadata' in data and 'capabilities' in data['metadata'])
    print('HAS_TOOLS=' + str(has_tools))
    
    # Check for probable secrets
    content_str = str(data).lower()
    has_secrets = any(secret in content_str for secret in ['sk-', 'api_key', 'secret_key', 'password', 'token'])
    print('HAS_SECRETS=' + str(has_secrets))
    
    # Check for creative-specific fields
    is_creative = any(term in content_str for term in ['creative', 'design', 'studio', 'brand', 'campaign', 'visual', 'content'])
    print('IS_CREATIVE=' + str(is_creative))
    
except Exception as e:
    print('ERROR=' + str(e))
    sys.exit(1)
" 2>/dev/null)

  if [[ $? -ne 0 ]]; then
    echo -e "${RED}✗ Failed to parse YAML: $file${NC}"
    errors=$((errors+1))
    continue
  fi
  
  # Parse the output
  eval "$python_output"
  
  # Validate Anthropic-first standards for creative agents
  
  # 1. Check codename pattern (for new agents)
  if [[ "$CODENAME" != "unknown" ]] && [[ ! "$CODENAME" =~ ^[a-z0-9][a-z0-9-]*-v[0-9]+$ ]]; then
    echo -e "${YELLOW}⚠ Codename pattern violation: $CODENAME (file: ${file#$ROOT/})${NC}"
    warnings=$((warnings+1))
  fi
  
  # 2. Check semver version
  if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}✗ Version not semver: $VERSION (${file#$ROOT/})${NC}"
    errors=$((errors+1))
  fi
  
  # 3. Check for owner field
  if [[ -z "$OWNER" ]]; then
    echo -e "${YELLOW}⚠ Owner missing (${file#$ROOT/})${NC}"
    warnings=$((warnings+1))
  fi
  
  # 4. Check for tools/capabilities section
  if [[ "$HAS_TOOLS" != "True" ]]; then
    echo -e "${YELLOW}⚠ Tools/capabilities section missing (${file#$ROOT/})${NC}"
    warnings=$((warnings+1))
  fi
  
  # 5. Check for embedded secrets
  if [[ "$HAS_SECRETS" == "True" ]]; then
    echo -e "${RED}✗ Probable secret embedded (${file#$ROOT/})${NC}"
    errors=$((errors+1))
  fi
  
  # 6. Verify creative context
  if [[ "$IS_CREATIVE" != "True" ]]; then
    echo -e "${YELLOW}⚠ Missing creative/studio context (${file#$ROOT/})${NC}"
    warnings=$((warnings+1))
  fi
  
  # 7. Check type enum for creative agents
  valid_types=("generator" "analyzer" "orchestrator" "specialist" "guardian" "optimizer" "tracker")
  if [[ "$TYPE" != "unknown" ]] && [[ ! " ${valid_types[@]} " =~ " $TYPE " ]]; then
    echo -e "${YELLOW}⚠ Invalid type: $TYPE (${file#$ROOT/})${NC}"
    warnings=$((warnings+1))
  fi
done < "$CREATIVE_FILES"

# Clean up temp file
rm -f "$CREATIVE_FILES"

echo
echo "Validation Summary:"
echo "==================="

if [[ $errors -eq 0 ]]; then
  echo -e "${GREEN}✅ Creative agents validation passed${NC}"
  if [[ $warnings -gt 0 ]]; then
    echo -e "${YELLOW}⚠ $warnings warnings found${NC}"
  fi
  echo "✓ Creative agents OK ($file_count) and registry available."
  exit 0
else
  echo -e "${RED}❌ Creative agents validation failed${NC}"
  echo -e "${RED}✗ $errors errors found${NC}"
  if [[ $warnings -gt 0 ]]; then
    echo -e "${YELLOW}⚠ $warnings warnings found${NC}"
  fi
  echo
  echo "Next steps:"
  echo "1. Fix validation errors in agent files"
  echo "2. Ensure creative agents follow naming conventions"
  echo "3. Add missing metadata fields"
  echo "4. Remove any embedded secrets"
  echo "5. Run scripts/creative-agents-create.sh for new agents"
  exit 1
fi