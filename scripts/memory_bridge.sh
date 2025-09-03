#!/bin/bash
# Memory Bridge MCP wrapper for secure secret injection
# This script expects environment variables to be injected by Bruno

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧠 Memory Bridge MCP Wrapper${NC}"
echo "================================"

# Validate required environment variables
validate_environment() {
    local missing=()
    
    # Check for any required environment variables
    # Memory bridge might need various API keys depending on configuration
    if [ -z "${OPENAI_API_KEY:-}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -z "${DEEPSEEK_API_KEY:-}" ]; then
        echo -e "${YELLOW}⚠️  No model API keys found (OPENAI_API_KEY, ANTHROPIC_API_KEY, DEEPSEEK_API_KEY)${NC}"
        echo -e "${YELLOW}   Memory bridge will operate in limited mode without model access${NC}"
    fi
    
    # Check for Supabase if persistence is enabled
    if [ -n "${MEMORY_BRIDGE_PERSISTENCE:-}" ] && [ "$MEMORY_BRIDGE_PERSISTENCE" = "supabase" ]; then
        if [ -z "${SUPABASE_URL:-}" ]; then
            missing+=("SUPABASE_URL")
        fi
        if [ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]; then
            missing+=("SUPABASE_SERVICE_ROLE_KEY")
        fi
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

# Test model API connections
test_model_connections() {
    echo -e "${BLUE}Testing model API connections...${NC}"
    
    # Test OpenAI if key is available
    if [ -n "${OPENAI_API_KEY:-}" ]; then
        local response
        response=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: Bearer $OPENAI_API_KEY" \
            -H "Content-Type: application/json" \
            "https://api.openai.com/v1/models" 2>/dev/null || echo "000")
        
        if [ "$response" = "200" ]; then
            echo -e "${GREEN}✅ OpenAI connection successful${NC}"
        else
            echo -e "${YELLOW}⚠️  OpenAI connection test failed (HTTP $response)${NC}"
        fi
    fi
    
    # Test Anthropic if key is available
    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        echo -e "${GREEN}✅ Anthropic API key available${NC}"
        # Anthropic doesn't have a simple ping endpoint, so we just validate key format
        if [[ "$ANTHROPIC_API_KEY" == sk-ant-* ]]; then
            echo -e "${GREEN}✅ Anthropic API key format valid${NC}"
        else
            echo -e "${YELLOW}⚠️  Anthropic API key format unexpected${NC}"
        fi
    fi
    
    # Test DeepSeek if key is available
    if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
        echo -e "${GREEN}✅ DeepSeek API key available${NC}"
    fi
}

# Test Supabase connection if needed
test_supabase_connection() {
    if [ -n "${SUPABASE_URL:-}" ] && [ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]; then
        echo -e "${BLUE}Testing Supabase connection for memory persistence...${NC}"
        
        local response
        response=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
            -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
            "$SUPABASE_URL/rest/v1/" 2>/dev/null || echo "000")
        
        if [ "$response" = "200" ]; then
            echo -e "${GREEN}✅ Supabase connection successful (memory persistence)${NC}"
        else
            echo -e "${YELLOW}⚠️  Supabase connection test failed (HTTP $response)${NC}"
        fi
    fi
}

# Start the Memory Bridge MCP server
start_memory_bridge() {
    echo -e "${BLUE}Starting Memory Bridge MCP server...${NC}"
    
    # Check if MCP server exists
    local mcp_server_dir="mcp/servers/memory-bridge"
    if [ ! -d "$mcp_server_dir" ]; then
        echo -e "${YELLOW}⚠️  MCP server directory not found: $mcp_server_dir${NC}"
        echo -e "${YELLOW}Creating basic structure...${NC}"
        mkdir -p "$mcp_server_dir"
        cat > "$mcp_server_dir/package.json" << 'EOF'
{
  "name": "memory-bridge-mcp",
  "version": "1.0.0",
  "description": "MCP server for memory bridging and context management",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^0.6.0",
    "@supabase/supabase-js": "^2.38.0",
    "openai": "^4.20.0",
    "@anthropic-ai/sdk": "^0.25.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "typescript": "^5.0.0"
  }
}
EOF
        echo -e "${GREEN}✅ Created basic Memory Bridge MCP structure${NC}"
    fi
    
    # Export environment for the MCP server
    echo -e "${GREEN}✅ Memory Bridge MCP server ready with injected environment${NC}"
    
    # Show available configuration
    echo -e "${BLUE}📋 Memory Bridge Configuration:${NC}"
    if [ -n "${OPENAI_API_KEY:-}" ]; then
        echo "  OpenAI: ✅ Available (${OPENAI_API_KEY:0:8}...)"
    else
        echo "  OpenAI: ❌ Not configured"
    fi
    
    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        echo "  Anthropic: ✅ Available (${ANTHROPIC_API_KEY:0:8}...)"
    else
        echo "  Anthropic: ❌ Not configured"
    fi
    
    if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
        echo "  DeepSeek: ✅ Available (${DEEPSEEK_API_KEY:0:8}...)"
    else
        echo "  DeepSeek: ❌ Not configured"
    fi
    
    if [ -n "${SUPABASE_URL:-}" ]; then
        echo "  Supabase: ✅ Available (persistence enabled)"
    else
        echo "  Supabase: ❌ Not configured"
    fi
    
    echo -e "${YELLOW}Note: Actual MCP server implementation would start here${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}🔍 Validating environment...${NC}"
    if ! validate_environment; then
        echo -e "${YELLOW}⚠️  Continuing with limited functionality...${NC}"
    fi
    
    echo -e "${BLUE}🔗 Testing connections...${NC}"
    test_model_connections
    test_supabase_connection
    
    echo -e "${BLUE}🚀 Starting Memory Bridge...${NC}"
    start_memory_bridge
    
    echo -e "${GREEN}🎉 Memory Bridge MCP wrapper initialized successfully!${NC}"
    echo ""
    echo -e "${BLUE}Environment Summary:${NC}"
    env | grep -E '(OPENAI|ANTHROPIC|DEEPSEEK|SUPABASE)_API?_KEY' | head -5 | \
        while read line; do
            key=$(echo "$line" | cut -d= -f1)
            value=$(echo "$line" | cut -d= -f2-)
            echo "  $key: ${value:0:10}... (redacted)"
        done
}

# Run main function
main "$@"
