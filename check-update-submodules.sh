#!/bin/bash

# Scout Analytics Frontend Submodule Update Check Script
# Usage: ./check-update-submodules.sh

echo "================================================"
echo "   Scout Analytics Frontend Submodule Status   "
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f ".gitmodules" ]; then
    echo -e "${RED}Error: Not in project root. Please run from /Users/tbwa/ai-aas-hardened-lakehouse${NC}"
    exit 1
fi

echo -e "\n${BLUE}1. Current Submodule Status:${NC}"
echo "-------------------------------"
git submodule status

echo -e "\n${BLUE}2. Checking for Remote Updates:${NC}"
echo "-------------------------------"

# Fetch latest from all submodules
echo "Fetching latest from remotes..."
git submodule foreach 'git fetch origin' 2>/dev/null

echo -e "\n${BLUE}3. Detailed Submodule Analysis:${NC}"
echo "-------------------------------"

# Check each submodule
SUBMODULES=(
    "modules/scout-analytics-dashboard"
    "modules/edge-suqi-pie"
    "modules/suqi-ai-db"
)

for submodule in "${SUBMODULES[@]}"; do
    echo -e "\n${YELLOW}📁 $submodule${NC}"
    
    if [ -d "$submodule" ]; then
        cd "$submodule"
        
        # Get current branch
        branch=$(git branch --show-current 2>/dev/null)
        echo "   Branch: $branch"
        
        # Get last commit
        last_commit=$(git log -1 --oneline 2>/dev/null)
        echo "   Last commit: $last_commit"
        
        # Check if up to date
        LOCAL=$(git rev-parse @)
        REMOTE=$(git rev-parse @{u} 2>/dev/null)
        BASE=$(git merge-base @ @{u} 2>/dev/null)
        
        if [ "$LOCAL" = "$REMOTE" ]; then
            echo -e "   Status: ${GREEN}✅ Up to date${NC}"
        elif [ "$LOCAL" = "$BASE" ]; then
            echo -e "   Status: ${YELLOW}⚠️  Behind remote (needs update)${NC}"
            BEHIND=$(git rev-list --count HEAD..@{u})
            echo "   Behind by: $BEHIND commits"
        elif [ "$REMOTE" = "$BASE" ]; then
            echo -e "   Status: ${BLUE}↑ Ahead of remote${NC}"
            AHEAD=$(git rev-list --count @{u}..HEAD)
            echo "   Ahead by: $AHEAD commits"
        else
            echo -e "   Status: ${RED}⚠️  Diverged${NC}"
        fi
        
        # Check for local changes
        if [[ -n $(git status --porcelain) ]]; then
            echo -e "   Local changes: ${YELLOW}Yes (uncommitted)${NC}"
        else
            echo -e "   Local changes: ${GREEN}None${NC}"
        fi
        
        cd - > /dev/null
    else
        echo -e "   Status: ${RED}❌ Not initialized${NC}"
    fi
done

echo -e "\n${BLUE}4. Scout v5.2 Backend Integration Check:${NC}"
echo "-------------------------------"

# Check if DAL service has the latest v5.2 integration
if [ -f "modules/scout-analytics-dashboard/src/services/dalService.ts" ]; then
    echo -e "${GREEN}✅ DAL Service found${NC}"
    
    # Check for v5.2 specific features
    if grep -q "fact_transactions" "modules/scout-analytics-dashboard/src/services/dalService.ts"; then
        echo -e "${GREEN}✅ Using fact_transactions table${NC}"
    else
        echo -e "${YELLOW}⚠️  Not using fact_transactions table${NC}"
    fi
    
    if grep -q "dim_date" "modules/scout-analytics-dashboard/src/services/dalService.ts"; then
        echo -e "${GREEN}✅ Using dim_date dimension${NC}"
    else
        echo -e "${YELLOW}⚠️  Not using dim_date dimension${NC}"
    fi
    
    if grep -q "execute_sql" "modules/scout-analytics-dashboard/src/services/dalService.ts"; then
        echo -e "${GREEN}✅ Using execute_sql RPC function${NC}"
    else
        echo -e "${YELLOW}⚠️  Not using execute_sql RPC function${NC}"
    fi
else
    echo -e "${RED}❌ DAL Service not found${NC}"
fi

echo -e "\n${BLUE}5. Update Actions:${NC}"
echo "-------------------------------"

echo "To update all submodules to latest:"
echo -e "${GREEN}git submodule update --remote --merge${NC}"

echo -e "\nTo update a specific submodule:"
echo -e "${GREEN}git submodule update --remote --merge modules/scout-analytics-dashboard${NC}"

echo -e "\nTo initialize missing submodules:"
echo -e "${GREEN}git submodule update --init --recursive${NC}"

echo -e "\nTo force reset to remote state (CAUTION: loses local changes):"
echo -e "${YELLOW}git submodule foreach 'git reset --hard origin/main'${NC}"

echo -e "\n${BLUE}6. Backend Connection Test:${NC}"
echo "-------------------------------"

# Check if .env file exists in scout-analytics-dashboard
if [ -f "modules/scout-analytics-dashboard/.env" ]; then
    echo -e "${GREEN}✅ .env file exists${NC}"
    
    # Check for Supabase URL
    if grep -q "VITE_SUPABASE_URL" "modules/scout-analytics-dashboard/.env"; then
        SUPABASE_URL=$(grep "VITE_SUPABASE_URL" "modules/scout-analytics-dashboard/.env" | cut -d '=' -f2)
        echo "   Supabase URL: ${SUPABASE_URL:0:40}..."
        
        # Check if it matches the production URL
        if [[ "$SUPABASE_URL" == *"cxzllzyxwpyptfretryc"* ]]; then
            echo -e "   ${GREEN}✅ Connected to Scout v5.2 backend${NC}"
        else
            echo -e "   ${YELLOW}⚠️  Not connected to Scout v5.2 backend${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠️  No .env file found in scout-analytics-dashboard${NC}"
    echo "   Create one from .env.template:"
    echo "   cp modules/scout-analytics-dashboard/.env.template modules/scout-analytics-dashboard/.env"
fi

echo -e "\n================================================"
echo -e "${GREEN}Submodule check complete!${NC}"
echo "================================================"
