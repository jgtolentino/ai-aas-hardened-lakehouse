#!/bin/bash

# IMMEDIATE FIX SCRIPT
# Run this in your terminal to fix all 3 issues

echo "🔧 Fixing Scout System Issues..."

# 1. FIX SUPABASE MCP
echo "1️⃣ Fixing Supabase MCP Server..."
# Add keys to macOS Keychain
security add-generic-password -a $USER -s SUPABASE_SERVICE_KEY -w "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU" 2>/dev/null
security add-generic-password -a $USER -s SUPABASE_ANON_KEY -w "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" 2>/dev/null

# 2. FIX MEMORY BRIDGE
echo "2️⃣ Fixing Memory Bridge Server..."
cd /Users/tbwa/ai-aas-hardened-lakehouse/session-history
npm init -y 2>/dev/null
npm install @modelcontextprotocol/server-memory --save
chmod +x memory_bridge.sh

# 3. RUN SCOUT MIGRATION
echo "3️⃣ Running Scout Schema Migration..."
cd /Users/tbwa/ai-aas-hardened-lakehouse
npx supabase db push --db-url "postgresql://postgres:postgres@localhost:54322/postgres"

echo "✅ All fixes applied!"
echo ""
echo "📝 Next Steps:"
echo "1. Restart Claude Desktop"
echo "2. Check that MCP servers show as connected (green)"
echo "3. For PRs, run: git checkout main && git pull"
