#!/bin/bash
set -euo pipefail

# Setup GitHub Secrets for AI-AAS-Hardened-Lakehouse
# This script configures all required secrets for GitHub Actions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔐 Setting up GitHub Secrets for AI-AAS-Hardened-Lakehouse${NC}"
echo "================================================="

# Check if gh CLI is available and authenticated
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) not found. Install it first:${NC}"
    echo "   brew install gh"
    exit 1
fi

if ! gh auth status &>/dev/null; then
    echo -e "${YELLOW}⚠️  GitHub CLI not authenticated. Running gh auth login...${NC}"
    gh auth login
fi

# Load environment variables
if [ ! -f ".env.local" ]; then
    echo -e "${RED}❌ .env.local not found${NC}"
    exit 1
fi

source .env.local

# Set the repository for gh commands
REPO="jgtolentino/ai-aas-hardened-lakehouse"

# Required secrets for GitHub Actions
echo -e "${BLUE}📋 Setting up required secrets for ${REPO}...${NC}"

# 1. SUPABASE_ACCESS_TOKEN (Personal Access Token)
echo -e "${BLUE}   Setting SUPABASE_ACCESS_TOKEN...${NC}"
echo "$SUPABASE_ACCESS_TOKEN" | gh secret set SUPABASE_ACCESS_TOKEN -R "$REPO" || echo -e "${YELLOW}   ⚠️  Failed to set SUPABASE_ACCESS_TOKEN${NC}"

# 2. SUPABASE_PROJECT_ID (same as PROJECT_REF)
echo -e "${BLUE}   Setting SUPABASE_PROJECT_ID...${NC}"
echo "$SUPABASE_PROJECT_REF" | gh secret set SUPABASE_PROJECT_ID -R "$REPO" || echo -e "${YELLOW}   ⚠️  Failed to set SUPABASE_PROJECT_ID${NC}"

# 3. SUPABASE_SERVICE_ROLE_KEY
echo -e "${BLUE}   Setting SUPABASE_SERVICE_ROLE_KEY...${NC}"
echo "$SUPABASE_SERVICE_ROLE_KEY" | gh secret set SUPABASE_SERVICE_ROLE_KEY -R "$REPO" || echo -e "${YELLOW}   ⚠️  Failed to set SUPABASE_SERVICE_ROLE_KEY${NC}"

# 4. SUPABASE_DB_URL (Database connection string)
echo -e "${BLUE}   Setting SUPABASE_DB_URL...${NC}"
if [ -n "${DATABASE_URL:-}" ]; then
    echo "$DATABASE_URL" | gh secret set SUPABASE_DB_URL -R "$REPO" || echo -e "${YELLOW}   ⚠️  Failed to set SUPABASE_DB_URL${NC}"
else
    echo -e "${YELLOW}   ⚠️  DATABASE_URL not found in .env.local${NC}"
fi

# 5. Additional common secrets
echo -e "${BLUE}   Setting additional secrets...${NC}"

# SUPABASE_ANON_KEY (for API access)
echo -e "${BLUE}   Setting SUPABASE_ANON_KEY...${NC}"
echo "$SUPABASE_ANON_KEY" | gh secret set SUPABASE_ANON_KEY -R "$REPO" || echo -e "${YELLOW}   ⚠️  Failed to set SUPABASE_ANON_KEY${NC}"

# NEXT_PUBLIC_SUPABASE_URL (for frontend builds)
echo "$SUPABASE_URL" | gh secret set NEXT_PUBLIC_SUPABASE_URL -R "$REPO" || echo -e "${YELLOW}   ⚠️  Failed to set NEXT_PUBLIC_SUPABASE_URL${NC}"

# NEXT_PUBLIC_SUPABASE_ANON_KEY (for frontend builds)
echo "$SUPABASE_ANON_KEY" | gh secret set NEXT_PUBLIC_SUPABASE_ANON_KEY -R "$REPO" || echo -e "${YELLOW}   ⚠️  Failed to set NEXT_PUBLIC_SUPABASE_ANON_KEY${NC}"

echo ""
echo -e "${BLUE}📊 Verifying secrets...${NC}"
echo -e "${BLUE}   Current secrets in repository:${NC}"
gh secret list -R "$REPO"

echo ""
echo -e "${GREEN}🎉 GitHub Secrets Setup Complete!${NC}"
echo "================================================="
echo -e "${BLUE}✅ What was configured:${NC}"
echo "   • SUPABASE_ACCESS_TOKEN - For Supabase CLI operations"
echo "   • SUPABASE_PROJECT_ID - Project reference ID"
echo "   • SUPABASE_SERVICE_ROLE_KEY - Backend authentication"
echo "   • SUPABASE_DB_URL - Direct database access"
echo "   • NEXT_PUBLIC_SUPABASE_URL - Frontend API URL"
echo "   • NEXT_PUBLIC_SUPABASE_ANON_KEY - Frontend public key"

echo ""
echo -e "${BLUE}🔍 GitHub Actions will now:${NC}"
echo "   • Run Edge Function tests on push to main"
echo "   • Execute dictionary refresh workflows"
echo "   • Deploy to production with proper credentials"
echo "   • Run security scans with database access"

echo ""
echo -e "${GREEN}Your GitHub Actions are ready to run! 🚀${NC}"

exit 0