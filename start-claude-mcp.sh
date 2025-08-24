#!/bin/bash
# Start Claude Code with MCP support for this project

# Set environment variables
export SUPABASE_ACCESS_TOKEN="sbp_05fcd9a214adbb2721dd54f2f39478e5efcbeffa"
export SUPABASE_PROJECT_REF="cxzllzyxwpyptfretryc"

# Optional: Add to current session
echo "Setting up MCP environment variables..."
echo "SUPABASE_ACCESS_TOKEN is set"
echo "SUPABASE_PROJECT_REF=$SUPABASE_PROJECT_REF"

# Start Claude Code with MCP
echo "Starting Claude Code with MCP support..."
claude --mcp

# Alternative: If you just want to export for current session
# Run: source start-claude-mcp.sh