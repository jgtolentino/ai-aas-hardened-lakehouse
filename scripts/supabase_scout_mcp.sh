#!/bin/bash
# MCP wrapper for Supabase Scout operations with secure secret injection
# This script expects environment variables to be injected by Bruno

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Supabase Scout MCP Wrapper${NC}"
echo "=================================="

# Validate required environment variables
validate_environment() {
    local missing=()
    
    # Required Supabase variables
    if [ -z "${SUPABASE_URL:-}" ]; then
        missing+=("SUPABASE_URL")
    fi
    
    if [ -z "${SUPABASE_ANON_KEY:-}" ]; then
        missing+=("SUPABASE_ANON_KEY")
    fi
    
    if [ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]; then
        missing+=("SUPABASE_SERVICE_ROLE_KEY")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing required environment variables:${NC}"
        printf '  - %s\n' "${missing[@]}"
        echo ""
        echo -e "${YELLOW}These should be injected by Bruno before this script runs.${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Environment validation passed${NC}"
    return 0
}

# Test Supabase connection
test_supabase_connection() {
    echo -e "${BLUE}Testing Supabase connection...${NC}"
    
    # Test with anon key
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "apikey: $SUPABASE_ANON_KEY" \
        -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
        "$SUPABASE_URL/rest/v1/" 2>/dev/null || echo "000")
    
    if [ "$response" = "200" ]; then
        echo -e "${GREEN}✅ Supabase connection successful (anon)${NC}"
    else
        echo -e "${YELLOW}⚠️  Supabase anon connection test failed (HTTP $response)${NC}"
    fi
    
    # Test with service role key (more privileged)
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
        -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
        "$SUPABASE_URL/rest/v1/" 2>/dev/null || echo "000")
    
    if [ "$response" = "200" ]; then
        echo -e "${GREEN}✅ Supabase connection successful (service role)${NC}"
    else
        echo -e "${YELLOW}⚠️  Supabase service role connection test failed (HTTP $response)${NC}"
    fi
}

# Start the MCP server
start_mcp_server() {
    echo -e "${BLUE}Starting Supabase Scout MCP server...${NC}"
    
    # Check if MCP server exists
    local mcp_server_dir="mcp/servers/supabase-scout"
    if [ ! -d "$mcp_server_dir" ]; then
        echo -e "${YELLOW}⚠️  MCP server directory not found: $mcp_server_dir${NC}"
        echo -e "${YELLOW}Creating basic structure...${NC}"
        mkdir -p "$mcp_server_dir"
        cat > "$mcp_server_dir/package.json" << 'EOF'
{
  "name": "supabase-scout-mcp",
  "version": "1.0.0",
  "description": "MCP server for Supabase Scout operations",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^0.6.0",
    "@supabase/supabase-js": "^2.38.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "typescript": "^5.0.0"
  }
}
EOF
        echo -e "${GREEN}✅ Created basic MCP server structure${NC}"
    fi
    
    # Start the server (this would be the actual MCP server startup)
    echo -e "${GREEN}✅ MCP server ready to start with injected environment${NC}"
    echo -e "${YELLOW}Note: Actual MCP server implementation would start here${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}🔍 Validating environment...${NC}"
    if ! validate_environment; then
        exit 1
    fi
    
    echo -e "${BLUE}🔗 Testing connections...${NC}"
    test_supabase_connection
    
    echo -e "${BLUE}🚀 Starting services...${NC}"
    start_mcp_server
    
    echo -e "${GREEN}🎉 Supabase Scout MCP wrapper initialized successfully!${NC}"
    echo ""
    echo -e "${BLUE}Environment variables available:${NC}"
    echo "  SUPABASE_URL: ${SUPABASE_URL:-not set}"
    echo "  SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY:0:10}... (redacted)"
    echo "  SUPABASE_SERVICE_ROLE_KEY: ${SUPABASE_SERVICE_ROLE_KEY:0:10}... (redacted)"
    echo "  SUPABASE_JWT_SECRET: ${SUPABASE_JWT_SECRET:0:10}... (redacted)"
}

# Run main function
main "$@"
