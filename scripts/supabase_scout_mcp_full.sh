#!/bin/bash
# Supabase Scout MCP Wrapper - Loads secrets from keychain and starts MCP server

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🔧 Supabase Scout MCP Server${NC}"
echo "=================================="

# Load secrets from keychain
echo -e "${BLUE}🔐 Loading secrets from macOS Keychain...${NC}"
source "$SCRIPT_DIR/load-secrets-from-keychain.sh"

# Load Supabase project configuration
if [ -f "$PROJECT_ROOT/supabase/.env.local" ]; then
    echo -e "${BLUE}📋 Loading Supabase project configuration...${NC}"
    export $(cat "$PROJECT_ROOT/supabase/.env.local" | grep -v '^#' | xargs)
    echo -e "${GREEN}✅ Loaded project configuration${NC}"
fi

# Validate required environment variables
validate_environment() {
    local missing=()
    
    if [ -z "${SUPABASE_URL:-}" ]; then
        missing+=("SUPABASE_URL")
    fi
    
    if [ -z "${SUPABASE_ANON_KEY:-}" ] && [ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]; then
        missing+=("SUPABASE_ANON_KEY or SUPABASE_SERVICE_ROLE_KEY")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing required environment variables:${NC}"
        printf '  - %s\n' "${missing[@]}"
        echo ""
        echo -e "${YELLOW}Please ensure these are set in supabase/.env.local${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Environment validation passed${NC}"
    return 0
}

# Build the MCP server if needed
build_mcp_server() {
    local mcp_dir="$PROJECT_ROOT/mcp/servers/supabase-scout"
    
    if [ ! -d "$mcp_dir/dist" ]; then
        echo -e "${YELLOW}📦 Building MCP server...${NC}"
        cd "$mcp_dir"
        
        # Install dependencies
        if [ ! -d "node_modules" ]; then
            echo -e "${BLUE}Installing dependencies...${NC}"
            npm install
        fi
        
        # Build TypeScript
        echo -e "${BLUE}Compiling TypeScript...${NC}"
        npm run build
        
        echo -e "${GREEN}✅ MCP server built successfully${NC}"
    else
        echo -e "${GREEN}✅ MCP server already built${NC}"
    fi
}

# Start the MCP server
start_mcp_server() {
    local mcp_dir="$PROJECT_ROOT/mcp/servers/supabase-scout"
    
    echo -e "${BLUE}🚀 Starting Supabase Scout MCP server...${NC}"
    
    # Export environment variables for the MCP server
    export SUPABASE_URL="${SUPABASE_URL}"
    export SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"
    export SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"
    export SUPABASE_JWT_SECRET="${SUPABASE_JWT_SECRET:-}"
    
    # Change to MCP directory
    cd "$mcp_dir"
    
    # Start the server
    if [ -f "dist/index.js" ]; then
        echo -e "${GREEN}✅ Starting MCP server...${NC}"
        node dist/index.js
    else
        echo -e "${YELLOW}⚠️  Using development mode (tsx)...${NC}"
        npx tsx src/index.ts
    fi
}

# Main execution
main() {
    echo -e "${BLUE}🔍 Validating environment...${NC}"
    if ! validate_environment; then
        exit 1
    fi
    
    echo -e "${BLUE}🏗️  Preparing MCP server...${NC}"
    build_mcp_server
    
    echo -e "${BLUE}🚀 Launching server...${NC}"
    start_mcp_server
}

# Handle interrupts gracefully
trap 'echo -e "\n${YELLOW}⚠️  MCP server stopped${NC}"; exit 0' INT TERM

# Run main function
main "$@"
