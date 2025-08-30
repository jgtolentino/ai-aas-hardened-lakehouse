#!/bin/bash

# Setup Figma Code Connect for Scout Dashboard
# This script configures and validates Code Connect integration

set -e

echo "🎨 Setting up Figma Code Connect for Scout Dashboard..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo -e "${RED}Error: package.json not found. Please run this script from the scout-dashboard directory.${NC}"
    exit 1
fi

# Check if @figma/code-connect is installed
if ! npm ls @figma/code-connect &>/dev/null; then
    echo -e "${YELLOW}Installing @figma/code-connect...${NC}"
    npm install --save-dev @figma/code-connect@latest
fi

# Check for Figma CLI
if ! command -v figma &> /dev/null; then
    echo -e "${YELLOW}Installing Figma CLI globally...${NC}"
    npm install -g @figma/code-connect
fi

# Validate configuration
echo "📋 Validating Figma configuration..."
if [ -f "figma.config.json" ]; then
    echo -e "${GREEN}✓ figma.config.json found${NC}"
else
    echo -e "${YELLOW}Creating figma.config.json...${NC}"
    cat > figma.config.json << 'EOF'
{
  "codeConnect": {
    "parser": "react",
    "include": ["src/components/**/*.figma.tsx"],
    "exclude": ["src/components/**/*.{test,spec,stories}.{tsx,ts}"],
    "importMappings": {
      "@/": "./src/"
    }
  },
  "documentId": "Rjh4xxbrZr8otmfpPqiVPC",
  "outputDir": "./figma"
}
EOF
fi

# Create Code Connect files directory structure
echo "📁 Creating Code Connect file structure..."
mkdir -p src/components/{layout,charts,ai,executive,geographic,tabs,scout}/figma

# Parse Code Connect files
echo "🔍 Parsing Code Connect files..."
npx figma connect parse

# Validate connections
echo "✅ Validating Code Connect connections..."
npx figma connect validate

echo -e "${GREEN}✨ Figma Code Connect setup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Create .figma.tsx files for your components"
echo "2. Run 'npm run figma:parse' to parse connections"
echo "3. Run 'npm run figma:publish' to publish to Figma"
echo ""
echo "Available commands:"
echo "  npm run figma:parse     - Parse Code Connect files"
echo "  npm run figma:validate  - Validate connections"
echo "  npm run figma:publish   - Publish to Figma"
echo "  npm run figma:publish:dry - Dry run publish"
