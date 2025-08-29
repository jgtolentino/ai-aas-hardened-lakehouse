#!/bin/bash

# Migration script to clean up obsolete tokens from MCP Hub configuration
# This reflects the new architecture where Claude Desktop handles MCP authentication

echo "🔄 MCP Hub Token Cleanup Migration Script"
echo "========================================="
echo ""
echo "This script will help you migrate to the new MCP architecture where:"
echo "- Figma auth is handled by Figma Desktop MCP"
echo "- GitHub auth is handled by Claude Desktop MCP"
echo "- MCP Hub only routes requests (no tokens needed)"
echo ""

# Check if we're in the right directory
if [[ ! -f ".env.example" ]]; then
    echo "❌ Error: Please run this script from the mcp-hub directory"
    echo "   cd /Users/tbwa/ai-aas-hardened-lakehouse/infra/mcp-hub"
    exit 1
fi

# Backup existing .env if it exists
if [[ -f ".env" ]]; then
    echo "📦 Backing up existing .env to .env.backup.$(date +%Y%m%d_%H%M%S)"
    cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
fi

# Remove obsolete tokens from .env file
if [[ -f ".env" ]]; then
    echo "🧹 Cleaning up .env file..."
    
    # Create temp file without the obsolete tokens
    grep -v "^FIGMA_TOKEN=" .env | \
    grep -v "^FIGMA_FILE_KEY=" | \
    grep -v "^GITHUB_TOKEN=" > .env.tmp || true
    
    # Add migration notice if tokens were found
    if grep -q "FIGMA_TOKEN\|GITHUB_TOKEN" .env 2>/dev/null; then
        echo "" >> .env.tmp
        echo "# Tokens removed during migration - now handled by Claude Desktop MCPs" >> .env.tmp
        echo "# Migration date: $(date)" >> .env.tmp
        echo "✅ Removed obsolete token configurations"
    fi
    
    mv .env.tmp .env
    echo "✅ .env file cleaned"
fi

# Update any docker-compose files
if [[ -f "docker-compose.yml" ]]; then
    echo "🐳 Checking docker-compose.yml..."
    if grep -q "FIGMA_TOKEN\|GITHUB_TOKEN" docker-compose.yml; then
        echo "⚠️  Found token references in docker-compose.yml"
        echo "   Please manually remove FIGMA_TOKEN and GITHUB_TOKEN environment variables"
    fi
fi

# Check for GitHub Actions secrets (informational only)
echo ""
echo "📋 GitHub Secrets Cleanup Checklist:"
echo "======================================"
echo ""
echo "If you have these secrets in GitHub Actions, they can be removed:"
echo "  ❌ FIGMA_TOKEN - no longer needed"
echo "  ❌ FIGMA_FILE_KEY - no longer needed"
echo "  ❌ GITHUB_TOKEN - use default GITHUB_TOKEN from Actions"
echo ""
echo "Keep these secrets if you have them:"
echo "  ✅ HUB_API_KEY - still required"
echo "  ✅ SUPABASE_* - still required for data operations"
echo "  ✅ MAPBOX_TOKEN - still required if using maps"
echo ""

# Check for any remaining references in source files
echo "🔍 Checking for token references in source code..."
FOUND_REFS=false

if grep -r "FIGMA_TOKEN" src/ 2>/dev/null | grep -v "no longer needed" | grep -v "obsolete"; then
    echo "⚠️  Found FIGMA_TOKEN references in source files"
    FOUND_REFS=true
fi

if grep -r "process.env.GITHUB_TOKEN" src/ 2>/dev/null | grep -v "no longer needed" | grep -v "obsolete"; then
    echo "⚠️  Found GITHUB_TOKEN references in source files"
    FOUND_REFS=true
fi

if [[ "$FOUND_REFS" == false ]]; then
    echo "✅ No obsolete token references found in source code"
fi

# Provide next steps
echo ""
echo "📌 Next Steps:"
echo "=============="
echo ""
echo "1. Ensure Claude Desktop has MCPs configured:"
echo "   - Figma MCP: Enable in Figma Desktop → Preferences → Advanced"
echo "   - GitHub MCP: Configure in Claude Desktop config with PAT"
echo ""
echo "2. Verify your .env has only these configurations:"
echo "   - HUB_API_KEY (required)"
echo "   - SUPABASE_* settings (if using)"
echo "   - MAPBOX_TOKEN (if using)"
echo "   - GITHUB_REPO (target repository)"
echo ""
echo "3. Test the new setup:"
echo "   npm start"
echo "   curl http://localhost:8787/health"
echo ""
echo "4. Update production environment variables:"
echo "   Remove FIGMA_TOKEN and GITHUB_TOKEN from your hosting platform"
echo ""
echo "✨ Migration preparation complete!"
echo "   Your MCP Hub is ready for the new token-free architecture."