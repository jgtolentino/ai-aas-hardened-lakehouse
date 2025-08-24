#!/bin/bash
# GitHub Secrets Setup Script for AI-as-a-Service Hardened Lakehouse
# Run this script to configure all required GitHub secrets for Supabase sync

set -e

echo "🔐 Setting up GitHub Secrets for AI-as-a-Service Hardened Lakehouse"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed. Please install it first:${NC}"
    echo "   brew install gh"
    echo "   or visit: https://cli.github.com/"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not authenticated with GitHub. Please run:${NC}"
    echo "   gh auth login"
    exit 1
fi

echo -e "${BLUE}📋 Current Supabase Configuration:${NC}"
echo "   Project Ref: cxzllzyxwpyptfretryc"
echo "   Alternate Ref: texxwmlroefdisgxpszc"
echo ""

# Primary Supabase Project Settings
SUPABASE_PROJECT_REF="cxzllzyxwpyptfretryc"
SUPABASE_PROJECT_ID="cxzllzyxwpyptfretryc"
SUPABASE_URL="https://cxzllzyxwpyptfretryc.supabase.co"

# Prompt for required secrets
echo -e "${YELLOW}🔑 Please provide the following secrets:${NC}"
echo ""

read -s -p "Enter your Supabase Access Token (PAT): " SUPABASE_ACCESS_TOKEN
echo ""
read -s -p "Enter your Supabase Service Role Key: " SUPABASE_SERVICE_ROLE_KEY
echo ""
read -s -p "Enter your Supabase Anon Key: " SUPABASE_ANON_KEY
echo ""
read -s -p "Enter your Supabase Database Password: " SUPABASE_DB_PASSWORD
echo ""

# Construct database URL
SUPABASE_DB_URL="postgresql://postgres:${SUPABASE_DB_PASSWORD}@db.${SUPABASE_PROJECT_REF}.supabase.co:5432/postgres"

echo -e "${BLUE}📤 Setting GitHub secrets...${NC}"

# Core Supabase secrets
gh secret set SUPABASE_ACCESS_TOKEN --body "$SUPABASE_ACCESS_TOKEN"
gh secret set SUPABASE_PROJECT_REF --body "$SUPABASE_PROJECT_REF"
gh secret set SUPABASE_PROJECT_ID --body "$SUPABASE_PROJECT_ID"
gh secret set SUPABASE_URL --body "$SUPABASE_URL"
gh secret set SUPABASE_SERVICE_ROLE_KEY --body "$SUPABASE_SERVICE_ROLE_KEY"
gh secret set SUPABASE_ANON_KEY --body "$SUPABASE_ANON_KEY"
gh secret set SUPABASE_DB_URL --body "$SUPABASE_DB_URL"

# Database connection details for legacy workflows
gh secret set PGURI --body "$SUPABASE_DB_URL"
gh secret set SB_HOST --body "db.${SUPABASE_PROJECT_REF}.supabase.co"
gh secret set SB_PORT --body "5432"
gh secret set SB_DB --body "postgres"
gh secret set SB_USER --body "postgres"
gh secret set SB_PASS --body "$SUPABASE_DB_PASSWORD"

echo -e "${GREEN}✅ Core secrets set successfully!${NC}"

# Optional: Set up alternate project secrets
echo ""
read -p "Set up alternate Supabase project secrets? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    SUPABASE_ALTERNATE_REF="texxwmlroefdisgxpszc"
    gh secret set SUPABASE_ALTERNATE_PROJECT_REF --body "$SUPABASE_ALTERNATE_REF"
    gh secret set SUPABASE_ALTERNATE_URL --body "https://${SUPABASE_ALTERNATE_REF}.supabase.co"
    echo -e "${GREEN}✅ Alternate project secrets set!${NC}"
fi

# Optional: Set up additional services
echo ""
read -p "Set up additional service secrets (Mapbox, Slack, etc.)? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    read -s -p "Enter your Mapbox token (optional): " MAPBOX_TOKEN
    echo ""
    if [ ! -z "$MAPBOX_TOKEN" ]; then
        gh secret set MAPBOX_TOKEN --body "$MAPBOX_TOKEN"
        echo -e "${GREEN}✅ Mapbox token set!${NC}"
    fi
    
    read -s -p "Enter your Slack webhook URL (optional): " SLACK_WEBHOOK_URL
    echo ""
    if [ ! -z "$SLACK_WEBHOOK_URL" ]; then
        gh secret set SLACK_WEBHOOK_URL --body "$SLACK_WEBHOOK_URL"
        echo -e "${GREEN}✅ Slack webhook set!${NC}"
    fi
fi

# Set up environments
echo ""
echo -e "${BLUE}🏗️  Setting up GitHub environments...${NC}"
gh api repos/:owner/:repo/environments/production -X PUT || true
gh api repos/:owner/:repo/environments/staging -X PUT || true
echo -e "${GREEN}✅ Environments created!${NC}"

# Verify secrets
echo ""
echo -e "${BLUE}🔍 Verifying secrets...${NC}"
secret_count=$(gh secret list | wc -l)
echo -e "${GREEN}✅ Total secrets configured: $secret_count${NC}"

# List configured secrets (names only)
echo ""
echo -e "${BLUE}📋 Configured secrets:${NC}"
gh secret list

echo ""
echo -e "${GREEN}🎉 GitHub Secrets Setup Complete!${NC}"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "1. Trigger a workflow run to test the configuration:"
echo "   gh workflow run supabase-sync.yml"
echo ""
echo "2. Monitor the workflow execution:"
echo "   gh run list --workflow=supabase-sync.yml"
echo ""
echo "3. Check deployment status in your Supabase project dashboard"
echo ""
echo -e "${BLUE}🔗 Useful Commands:${NC}"
echo "   gh workflow run supabase-sync.yml --ref main"
echo "   gh run list --limit 5"
echo "   gh run view [RUN_ID] --log"
echo ""
echo -e "${GREEN}✅ Your repository is now configured for automatic Supabase sync!${NC}"