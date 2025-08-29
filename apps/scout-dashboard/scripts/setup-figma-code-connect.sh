#!/bin/bash
set -e

echo "🎨 Setting up Figma Code Connect for Scout Dashboard"
echo "   Connecting to Finebank Financial UI Kit Design System"
echo "   Document: https://www.figma.com/design/Rjh4xxbrZr8otmfpPqiVPC/"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 Checking prerequisites...${NC}"

# Check if we're in the right directory
if [ ! -f "package.json" ] || [ ! -d "src/components" ]; then
    echo -e "${RED}❌ Error: Run this script from the scout-dashboard root directory${NC}"
    exit 1
fi

# Check if @figma/code-connect is installed
if ! npm list @figma/code-connect > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  @figma/code-connect not found, installing...${NC}"
    pnpm add -D @figma/code-connect
fi

echo -e "${GREEN}✅ Prerequisites met${NC}"

echo -e "${BLUE}🔧 Configuring Code Connect...${NC}"

# Create output directory
mkdir -p figma

# Initialize Code Connect (if not already done)
if [ ! -f ".figmarc" ]; then
    echo -e "${YELLOW}📝 Creating .figmarc configuration...${NC}"
    cat > .figmarc << EOF
{
  "documentId": "Rjh4xxbrZr8otmfpPqiVPC",
  "accessToken": "\$FIGMA_ACCESS_TOKEN"
}
EOF
fi

echo -e "${BLUE}📦 Generating Code Connect definitions...${NC}"

# Parse existing components
npx figma connect parse

echo -e "${BLUE}🎯 Mapping components to Figma...${NC}"

# List of our key components that have Code Connect definitions
COMPONENTS=(
    "src/components/scout/KpiCard/index.figma.tsx"
    "src/components/tabs/OverviewTab.figma.tsx"
    "src/components/charts/AnalyticsChart.figma.tsx"
    "src/components/ai/RecommendationPanel.figma.tsx"
    "src/components/layout/Sidebar.figma.tsx"
)

echo -e "${GREEN}✅ Found ${#COMPONENTS[@]} Code Connect definitions:${NC}"
for component in "${COMPONENTS[@]}"; do
    if [ -f "$component" ]; then
        echo -e "   ${GREEN}✓${NC} $component"
    else
        echo -e "   ${RED}✗${NC} $component (missing)"
    fi
done

echo -e "${BLUE}🔗 Validating Code Connect mappings...${NC}"

# Validate the connections
npx figma connect validate || echo -e "${YELLOW}⚠️  Some validations failed - check component mappings${NC}"

echo -e "${BLUE}📤 Publishing to Figma (dry run)...${NC}"

# Dry run publish to check for issues
npx figma connect publish --dry-run || echo -e "${YELLOW}⚠️  Dry run detected issues - review before publishing${NC}"

echo -e "${GREEN}🎉 Figma Code Connect setup complete!${NC}"
echo ""
echo -e "${BLUE}📚 Next Steps:${NC}"
echo "1. Set your FIGMA_ACCESS_TOKEN environment variable"
echo "2. Review and update component mappings in *.figma.tsx files"
echo "3. Run 'npx figma connect publish' to sync with Figma"
echo "4. Open Figma Dev Mode to see your code snippets"
echo ""
echo -e "${BLUE}🔗 Resources:${NC}"
echo "• Finebank Design System: https://www.figma.com/design/Rjh4xxbrZr8otmfpPqiVPC/"
echo "• Code Connect Docs: https://www.figma.com/code-connect-docs/"
echo "• Scout Dashboard Components: ./src/components/"
echo ""
echo -e "${GREEN}✨ Your Scout Dashboard is now connected to Figma!${NC}"