#!/bin/bash
# Load secrets from 1Password for Scout Analytics
# This script should be sourced before running MCP wrappers

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 Loading secrets from 1Password...${NC}"

# Check if 1Password CLI is installed
if ! command -v op &> /dev/null; then
    echo -e "${RED}❌ 1Password CLI (op) not found${NC}"
    echo "Install with: brew install --cask 1password/tap/1password-cli"
    return 1 2>/dev/null || exit 1
fi

# Check if signed in to 1Password
if ! op whoami &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not signed in to 1Password${NC}"
    echo "Sign in with: op signin --account your-domain.1password.com"
    return 1 2>/dev/null || exit 1
fi

load_secret() {
    local item_name=$1
    local field_name=$2
    local env_var_name=$3
    
    local secret_value
    if secret_value=$(op item get "$item_name" --field "$field_name" 2>/dev/null); then
        export "$env_var_name=$secret_value"
        echo -e "${GREEN}✅ Loaded $env_var_name from 1Password${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Failed to load $env_var_name from 1Password${NC}"
        return 1
    fi
}

# Load GitHub token
load_secret "GitHub Token - Scout Analytics" "token" "GH_TOKEN"

# Load Supabase secrets
load_secret "Supabase Credentials - Scout Analytics" "SUPABASE_ANON_KEY" "SUPABASE_ANON_KEY"
load_secret "Supabase Credentials - Scout Analytics" "SUPABASE_SERVICE_ROLE_KEY" "SUPABASE_SERVICE_ROLE_KEY"
load_secret "Supabase Credentials - Scout Analytics" "SUPABASE_ACCESS_TOKEN" "SUPABASE_ACCESS_TOKEN"
load_secret "Supabase Credentials - Scout Analytics" "SUPABASE_JWT_SECRET" "SUPABASE_JWT_SECRET"

# Load Vercel tokens
load_secret "Vercel Tokens - Scout Analytics" "VERCEL_TOKEN" "VERCEL_TOKEN"
load_secret "Vercel Tokens - Scout Analytics" "VERCEL_ORG_ID" "VERCEL_ORG_ID"
load_secret "Vercel Tokens - Scout Analytics" "VERCEL_PROJECT_ID_DASHBOARD" "VERCEL_PROJECT_ID_DASHBOARD"
load_secret "Vercel Tokens - Scout Analytics" "VERCEL_PROJECT_ID_DOCS" "VERCEL_PROJECT_ID_DOCS"

# Load model API keys (optional)
load_secret "AI Model Keys - Scout Analytics" "OPENAI_API_KEY" "OPENAI_API_KEY"
load_secret "AI Model Keys - Scout Analytics" "ANTHROPIC_API_KEY" "ANTHROPIC_API_KEY"
load_secret "AI Model Keys - Scout Analytics" "DEEPSEEK_API_KEY" "DEEPSEEK_API_KEY"

# Set Supabase URL from project ref (if not already set)
if [ -n "${SUPABASE_PROJECT_REF:-}" ] && [ -z "${SUPABASE_URL:-}" ]; then
    export SUPABASE_URL="https://${SUPABASE_PROJECT_REF}.supabase.co"
    echo -e "${GREEN}✅ Set SUPABASE_URL from SUPABASE_PROJECT_REF${NC}"
fi

echo -e "${GREEN}🎉 Secrets loaded successfully from 1Password!${NC}"
echo ""
echo -e "${BLUE}📋 Loaded Environment Variables:${NC}"

# Show loaded variables (redacted)
for var in GH_TOKEN SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY SUPABASE_ACCESS_TOKEN \
           VERCEL_TOKEN OPENAI_API_KEY ANTHROPIC_API_KEY; do
    if [ -n "${!var:-}" ]; then
        value="${!var}"
        echo "  $var: ${value:0:10}... (redacted)"
    fi
done

echo ""
echo -e "${YELLOW}💡 Usage: source this script before running MCP wrappers${NC}"
echo "Example:"
echo "  source scripts/load-secrets-from-1password.sh"
echo "  ./scripts/supabase_scout_mcp.sh"
echo "  ./scripts/memory_bridge.sh"
