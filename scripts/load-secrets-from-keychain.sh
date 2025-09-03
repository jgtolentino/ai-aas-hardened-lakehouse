#!/bin/bash
# Load secrets from macOS Keychain for Scout Analytics
# This script should be sourced before running MCP wrappers

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 Loading secrets from macOS Keychain...${NC}"

load_keychain_secret() {
    local service_name=$1
    local account_name=$2
    local env_var_name=$3
    
    local secret_value
    if secret_value=$(security find-generic-password -a "$account_name" -s "$service_name" -w 2>/dev/null); then
        export "$env_var_name=$secret_value"
        echo -e "${GREEN}✅ Loaded $env_var_name from Keychain${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Failed to load $env_var_name from Keychain${NC}"
        echo -e "${YELLOW}   Add with: security add-generic-password -a \"$account_name\" -s \"$service_name\" -w \"your_token_here\"${NC}"
        return 1
    fi
}

# Load Supabase PAT
load_keychain_secret "supabase-pat" "supabase" "SUPABASE_ACCESS_TOKEN"

# Load other secrets if they exist (optional)
load_keychain_secret "github-token" "github" "GH_TOKEN" || true
load_keychain_secret "vercel-token" "vercel" "VERCEL_TOKEN" || true
load_keychain_secret "openai-api-key" "openai" "OPENAI_API_KEY" || true
load_keychain_secret "anthropic-api-key" "anthropic" "ANTHROPIC_API_KEY" || true

echo -e "${GREEN}🎉 Secrets loaded successfully from Keychain!${NC}"
echo ""
echo -e "${BLUE}📋 Loaded Environment Variables:${NC}"

# Show loaded variables (redacted)
for var in SUPABASE_ACCESS_TOKEN GH_TOKEN VERCEL_TOKEN OPENAI_API_KEY ANTHROPIC_API_KEY; do
    if eval "[ -n \"\${${var}:-}\" ]"; then
        eval "value=\"\$${var}\""
        echo "  $var: ${value:0:10}... (redacted)"
    fi
done

echo ""
echo -e "${YELLOW}💡 Usage: source this script before running MCP wrappers${NC}"
echo "Example:"
echo "  source scripts/load-secrets-from-keychain.sh"
echo "  ./scripts/supabase_scout_mcp.sh"
echo ""
echo -e "${BLUE}ℹ️  To add more secrets:${NC}"
echo "  security add-generic-password -a \"account\" -s \"service\" -w \"token\""