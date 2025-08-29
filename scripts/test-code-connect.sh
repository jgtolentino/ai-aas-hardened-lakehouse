#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Code Connect Setup Test"
echo "=========================="
echo ""

# Check if @figma/code-connect is installed
echo "1. Checking @figma/code-connect installation..."
if npm list @figma/code-connect --depth=0 >/dev/null 2>&1; then
  VERSION=$(npm list @figma/code-connect --depth=0 | grep @figma/code-connect | awk '{print $2}')
  echo "   ✅ @figma/code-connect@$VERSION installed"
else
  echo "   ❌ @figma/code-connect not found"
  exit 1
fi
echo ""

# Check figma.config.json
echo "2. Checking figma.config.json..."
if [[ -f "figma.config.json" ]]; then
  echo "   ✅ figma.config.json exists"
  if jq -e '.codeConnect.include' figma.config.json >/dev/null 2>&1; then
    INCLUDE_PATTERN=$(jq -r '.codeConnect.include[0]' figma.config.json)
    echo "   ✅ Include pattern: $INCLUDE_PATTERN"
  else
    echo "   ⚠️  No include pattern found"
  fi
else
  echo "   ❌ figma.config.json not found"
  exit 1
fi
echo ""

# Count Code Connect mapping files
echo "3. Scanning for .figma.tsx files..."
FIGMA_FILES=$(find . -name "*.figma.tsx" -type f | wc -l | tr -d ' ')
if [[ $FIGMA_FILES -gt 0 ]]; then
  echo "   ✅ Found $FIGMA_FILES Code Connect mapping files:"
  find . -name "*.figma.tsx" -type f | sed 's|^\./||' | sed 's|^|     |'
else
  echo "   ⚠️  No .figma.tsx files found"
fi
echo ""

# Test Code Connect parsing
echo "4. Testing Code Connect parsing..."
if pnpm run figma:connect:parse >/dev/null 2>&1; then
  echo "   ✅ Code Connect parsing successful"
else
  echo "   ❌ Code Connect parsing failed"
  echo "   Running with verbose output:"
  pnpm run figma:connect:parse
  exit 1
fi
echo ""

# Check components have corresponding React files
echo "5. Validating component pairs..."
MISSING_COMPONENTS=0
while IFS= read -r figma_file; do
  COMPONENT_DIR=$(dirname "$figma_file")
  COMPONENT_NAME=$(basename "$figma_file" .figma.tsx)
  REACT_FILE="${COMPONENT_DIR}/${COMPONENT_NAME}.tsx"
  
  if [[ -f "$REACT_FILE" ]]; then
    echo "   ✅ $COMPONENT_NAME: Both .tsx and .figma.tsx exist"
  else
    echo "   ❌ $COMPONENT_NAME: Missing $REACT_FILE"
    MISSING_COMPONENTS=$((MISSING_COMPONENTS + 1))
  fi
done < <(find . -name "*.figma.tsx" -type f)

if [[ $MISSING_COMPONENTS -eq 0 ]]; then
  echo "   ✅ All components have matching React files"
else
  echo "   ⚠️  $MISSING_COMPONENTS components missing React files"
fi
echo ""

# Check package.json scripts
echo "6. Checking npm scripts..."
SCRIPTS=("figma:connect:parse" "figma:connect:validate" "figma:connect:publish")
for script in "${SCRIPTS[@]}"; do
  if npm run --silent 2>&1 | grep -q "$script"; then
    echo "   ✅ $script script exists"
  else
    echo "   ❌ $script script missing"
  fi
done
echo ""

# Summary
echo "📊 SUMMARY"
echo "=========="
echo "   Components with Code Connect: $FIGMA_FILES"
echo "   Missing React files: $MISSING_COMPONENTS"
echo "   Configuration: ✅ Complete"
echo "   Parsing: ✅ Working"
echo ""

if [[ $FIGMA_FILES -gt 0 && $MISSING_COMPONENTS -eq 0 ]]; then
  echo "🎉 Code Connect setup is COMPLETE and ready for use!"
  echo ""
  echo "📝 Next steps:"
  echo "   1. Update Figma file keys with real values from your Figma designs"
  echo "   2. Test in Figma Dev Mode to see component props"
  echo "   3. Run 'pnpm run figma:connect:publish --dry-run' to validate publishing"
else
  echo "⚠️  Code Connect setup needs attention"
fi
echo ""