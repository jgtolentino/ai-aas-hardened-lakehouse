#!/bin/bash

# Install Scout MCP Extension
cd /Users/tbwa/ai-aas-hardened-lakehouse/extensions/mcp-scout

echo "📦 Installing dependencies for Scout MCP..."
npm install

echo "✅ Scout MCP extension installed successfully!"
echo ""
echo "To use the Scout MCP server, restart Claude Desktop."
echo ""
echo "Available commands:"
echo "  - execute_sql: Run any SQL query"
echo "  - list_scout_tables: List all scout_ tables"
echo "  - describe_table: Show table structure"
echo "  - run_migration: Execute migration files"
