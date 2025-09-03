#!/usr/bin/env bash
set -euo pipefail

# Quick setup script for Scout MCP
ROOT="$HOME/ai-aas-hardened-lakehouse"
cd "$ROOT"

echo "🚀 Scout MCP Quick Setup"
echo "========================"

# Make all scripts executable
chmod +x scripts/db/*.sh scripts/*.sh 2>/dev/null || true

# Step 1: Create templates
echo ""
echo "Step 1: Creating SQL templates..."
bash scripts/db/scaffold-scout-templates.sh

# Step 2: Setup MCP server
echo ""
echo "Step 2: Setting up MCP server..."
bash scripts/setup-scout-mcp.sh

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 To apply the schema to your database:"
echo "   bash scripts/db/run-templates.sh --with-seed"
echo ""
echo "Then restart Claude Desktop to use the Scout MCP server."
