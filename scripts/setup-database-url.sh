#!/usr/bin/env bash
set -euo pipefail

echo "🔐 Setting up DATABASE_URL in Keychain"
echo ""

# Get existing PAT from keychain
PAT=$(security find-generic-password -a "supabase" -s "supabase-pat" -w 2>/dev/null || echo "")

if [[ -z "$PAT" ]]; then
    echo "❌ No Supabase PAT found in keychain"
    echo "Please run: source /Users/tbwa/ai-aas-hardened-lakehouse/scripts/load-secrets-from-keychain.sh"
    exit 1
fi

# Construct DATABASE_URL using the PAT as password
DATABASE_URL="postgresql://postgres.vmdyznckaqmdjzxnfitl:${PAT}@aws-0-us-west-1.pooler.supabase.com:6543/postgres?sslmode=require"

# Store in keychain
security add-generic-password -U -s "ai-aas-hardened-lakehouse.supabase" -a "DATABASE_URL" -w "$DATABASE_URL" >/dev/null

echo "✅ DATABASE_URL stored in Keychain!"
echo ""
echo "Testing connection..."

# Test the connection
if DATABASE_URL="$DATABASE_URL" node -e "
const { Client } = require('pg');
const client = new Client({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});
client.connect()
  .then(() => {
    console.log('✅ Database connection successful!');
    return client.end();
  })
  .catch(err => {
    console.error('❌ Connection failed:', err.message);
    process.exit(1);
  });
" 2>/dev/null; then
    echo ""
    echo "🎉 Scout MCP is ready to use!"
    echo ""
    echo "Restart Claude Desktop to activate the Scout MCP server."
else
    echo ""
    echo "⚠️ Connection test failed. Please check your PAT."
fi
