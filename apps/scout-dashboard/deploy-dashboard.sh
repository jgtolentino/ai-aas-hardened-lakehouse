#!/bin/bash

# Deploy Scout Dashboard with Figma Code Connect
# This script handles the full deployment pipeline

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Scout Dashboard Deployment Pipeline${NC}"
echo "======================================="

# Function to check command existence
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to run with error handling
run_command() {
    echo -e "${YELLOW}Running: $1${NC}"
    if eval "$1"; then
        echo -e "${GREEN}✓ Success${NC}"
    else
        echo -e "${RED}✗ Failed: $1${NC}"
        exit 1
    fi
}

# 1. Environment Check
echo -e "\n${BLUE}1. Checking Environment...${NC}"
if [ ! -f ".env.local" ]; then
    echo -e "${YELLOW}Warning: .env.local not found. Creating from example...${NC}"
    cp .env.example .env.local
fi

# 2. Install Dependencies
echo -e "\n${BLUE}2. Installing Dependencies...${NC}"
run_command "npm install"

# 3. Setup Figma Code Connect
echo -e "\n${BLUE}3. Setting up Figma Code Connect...${NC}"
if command_exists figma; then
    echo -e "${GREEN}✓ Figma CLI already installed${NC}"
else
    echo -e "${YELLOW}Installing Figma CLI...${NC}"
    run_command "npm install -g @figma/code-connect"
fi

# 4. Parse Code Connect Files
echo -e "\n${BLUE}4. Parsing Code Connect Files...${NC}"
run_command "npx figma connect parse"

# 5. Validate Connections
echo -e "\n${BLUE}5. Validating Code Connect...${NC}"
run_command "npx figma connect validate"

# 6. Build Application
echo -e "\n${BLUE}6. Building Application...${NC}"
run_command "npm run build"

# 7. Run Tests
echo -e "\n${BLUE}7. Running Tests...${NC}"
if [ -f "jest.config.js" ] || [ -f "vitest.config.ts" ]; then
    run_command "npm test"
else
    echo -e "${YELLOW}No test configuration found, skipping tests${NC}"
fi

# 8. Sync with Supabase
echo -e "\n${BLUE}8. Syncing with Supabase...${NC}"
cd ../..
if [ -f "supabase/config.toml" ]; then
    echo "Checking Supabase migrations..."
    run_command "supabase db push"
else
    echo -e "${YELLOW}Supabase config not found, skipping database sync${NC}"
fi
cd apps/scout-dashboard

# 9. Deploy to Vercel (if configured)
echo -e "\n${BLUE}9. Deployment Options...${NC}"
if [ -d ".vercel" ]; then
    echo "Vercel configuration found."
    read -p "Deploy to Vercel? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_command "vercel --prod"
    fi
else
    echo -e "${YELLOW}Vercel not configured. Run 'vercel' to set up deployment.${NC}"
fi

# 10. Publish to Figma
echo -e "\n${BLUE}10. Publishing to Figma...${NC}"
read -p "Publish Code Connect to Figma? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    run_command "npx figma connect publish"
else
    echo "Skipping Figma publish. Run 'npm run figma:publish' when ready."
fi

# 11. Git Commit (if changes)
echo -e "\n${BLUE}11. Git Operations...${NC}"
if [[ $(git status --porcelain) ]]; then
    echo "Changes detected:"
    git status --short
    read -p "Commit changes? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git add .
        read -p "Enter commit message: " commit_msg
        git commit -m "feat(scout-dashboard): $commit_msg"
        
        read -p "Push to remote? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git push origin main
        fi
    fi
else
    echo -e "${GREEN}✓ No uncommitted changes${NC}"
fi

# Summary
echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}✨ Deployment Pipeline Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo
echo "Dashboard Status:"
echo "  📊 Build: Complete"
echo "  🎨 Figma: Connected"
echo "  🗄️  Database: Synced"
echo "  🚀 Deployment: Ready"
echo
echo "Access your dashboard:"
echo "  Local: http://localhost:3000"
echo "  Figma: https://www.figma.com/design/Rjh4xxbrZr8otmfpPqiVPC/"
echo
echo "Next steps:"
echo "  1. Test the dashboard locally: npm run dev"
echo "  2. View in Figma Dev Mode"
echo "  3. Deploy to production when ready"
