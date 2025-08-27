#!/bin/bash
set -euo pipefail

echo "🚀 Figma → GitHub Sync Setup Script"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to prompt for input with default
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    echo -n "$prompt [$default]: "
    read -r input
    if [ -z "$input" ]; then
        eval "$var_name='$default'"
    else
        eval "$var_name='$input'"
    fi
}

# Function to prompt for secure input
prompt_secure() {
    local prompt="$1"
    local var_name="$2"
    
    echo -n "$prompt: "
    read -s input
    echo
    eval "$var_name='$input'"
}

echo
echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js is not installed. Please install Node.js 18+ first.${NC}"
    exit 1
fi

NODE_VERSION=$(node --version | cut -d. -f1 | cut -dv -f2)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo -e "${RED}❌ Node.js version 18+ required. Current: $(node --version)${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Node.js $(node --version) is installed${NC}"

# Check if we're in the right directory
if [ ! -f "package.json" ] || [ ! -f "src/server.js" ]; then
    echo -e "${RED}❌ Please run this script from the mcp-hub directory${NC}"
    echo "Expected: /Users/tbwa/ai-aas-hardened-lakehouse/infra/mcp-hub"
    exit 1
fi

echo -e "${GREEN}✅ Running from correct directory${NC}"

echo
echo -e "${YELLOW}Step 2: Collecting configuration...${NC}"

# Check if .env exists, create from example if not
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✅ Created .env from .env.example${NC}"
    else
        echo -e "${RED}❌ No .env.example found${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ .env file exists${NC}"
fi

# Read current .env values
if [ -f ".env" ]; then
    source .env 2>/dev/null || true
fi

# Collect required configuration
echo
echo "Please provide the following configuration:"

# Figma Token
if [ -z "${FIGMA_TOKEN:-}" ]; then
    echo
    echo -e "${YELLOW}Figma Personal Access Token needed:${NC}"
    echo "1. Go to: https://www.figma.com/developers/api#access-tokens"
    echo "2. Click 'Create a new personal access token'"
    echo "3. Name it 'MCP Hub Integration'"
    echo "4. Copy the token (starts with 'figd_')"
    prompt_secure "Enter your Figma token" FIGMA_TOKEN
    
    if [[ ! "$FIGMA_TOKEN" =~ ^figd_ ]]; then
        echo -e "${RED}❌ Invalid Figma token format. Should start with 'figd_'${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Figma token already configured${NC}"
fi

# GitHub Token
if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo
    echo -e "${YELLOW}GitHub Personal Access Token needed:${NC}"
    echo "1. Go to: https://github.com/settings/tokens"
    echo "2. Click 'Generate new token (classic)'"
    echo "3. Select 'repo' scope"
    echo "4. Copy the token (starts with 'ghp_')"
    prompt_secure "Enter your GitHub token" GITHUB_TOKEN
    
    if [[ ! "$GITHUB_TOKEN" =~ ^ghp_ ]]; then
        echo -e "${RED}❌ Invalid GitHub token format. Should start with 'ghp_'${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ GitHub token already configured${NC}"
fi

# GitHub Repository
if [ -z "${GITHUB_REPO:-}" ]; then
    echo
    echo -e "${YELLOW}GitHub Repository (format: owner/repo-name):${NC}"
    prompt_with_default "Enter your GitHub repository" "$(whoami)/ai-aas-hardened-lakehouse" GITHUB_REPO
else
    echo -e "${GREEN}✅ GitHub repo already configured: $GITHUB_REPO${NC}"
fi

# Hub API Key
if [ -z "${HUB_API_KEY:-}" ]; then
    echo
    HUB_API_KEY=$(openssl rand -hex 16)
    echo -e "${GREEN}✅ Generated new Hub API key${NC}"
else
    echo -e "${GREEN}✅ Hub API key already configured${NC}"
fi

# Optional Figma File Key
prompt_with_default "Default Figma File Key (optional)" "" FIGMA_FILE_KEY

echo
echo -e "${YELLOW}Step 3: Updating .env file...${NC}"

# Create new .env content
cat > .env << EOF
# MCP Hub Configuration
PORT=8787
HUB_API_KEY=$HUB_API_KEY

# Existing Supabase/Mapbox (if configured)
SUPABASE_URL=${SUPABASE_URL:-}
SUPABASE_SERVICE_ROLE=${SUPABASE_SERVICE_ROLE:-}
SUPABASE_RLS_ROLE=${SUPABASE_RLS_ROLE:-anon}
MAPBOX_TOKEN=${MAPBOX_TOKEN:-}

# NEW: Figma Integration
FIGMA_TOKEN=$FIGMA_TOKEN
FIGMA_FILE_KEY=$FIGMA_FILE_KEY

# NEW: GitHub Integration
GITHUB_TOKEN=$GITHUB_TOKEN
GITHUB_REPO=$GITHUB_REPO
EOF

echo -e "${GREEN}✅ .env file updated${NC}"

echo
echo -e "${YELLOW}Step 4: Installing dependencies...${NC}"

npm install
echo -e "${GREEN}✅ Dependencies installed${NC}"

echo
echo -e "${YELLOW}Step 5: Testing configuration...${NC}"

# Start server in background for testing
npm start &
SERVER_PID=$!

# Wait for server to start
sleep 3

# Test health endpoint
if curl -s http://localhost:8787/health | grep -q "ok"; then
    echo -e "${GREEN}✅ Server health check passed${NC}"
else
    echo -e "${RED}❌ Server health check failed${NC}"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Test OpenAPI schema
if curl -s http://localhost:8787/openapi.json | grep -q "figma"; then
    echo -e "${GREEN}✅ Figma adapter is registered${NC}"
else
    echo -e "${RED}❌ Figma adapter not found in schema${NC}"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Stop test server
kill $SERVER_PID 2>/dev/null || true
sleep 1

echo
echo -e "${GREEN}🎉 Setup completed successfully!${NC}"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test the integration:"
echo "   ./test-figma-github-sync.sh YOUR_FIGMA_FILE_KEY http://localhost:8787"
echo
echo "2. Deploy to production (choose one):"
echo "   - Vercel: 'vercel --prod'"
echo "   - Railway: 'railway up'"
echo "   - Render: Connect to Git and deploy"
echo
echo "3. Use the API:"
echo "   curl -H \"X-API-Key: $HUB_API_KEY\" \\"
echo "        -H \"Content-Type: application/json\" \\"
echo "        -d '{\"server\":\"sync\",\"tool\":\"sync.figmaFileToRepo\",\"args\":{\"fileKey\":\"YOUR_FILE_KEY\"}}' \\"
echo "        https://your-domain.com/mcp/run"
echo
echo -e "${YELLOW}Security reminder:${NC}"
echo "- Keep your .env file secure and never commit it to Git"
echo "- Rotate tokens regularly (GitHub: 90 days recommended)"
echo "- Use environment variables in production, not .env files"