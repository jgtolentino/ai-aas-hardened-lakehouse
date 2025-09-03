#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Finalizing Scout MCP Setup"
echo "=============================="
echo ""

# Make script executable
chmod +x /Users/tbwa/ai-aas-hardened-lakehouse/scripts/finalize-scout-mcp.sh

# Run the finalization
bash /Users/tbwa/ai-aas-hardened-lakehouse/scripts/finalize-scout-mcp.sh

echo ""
echo "✅ Setup complete!"
echo ""
echo "🔐 Now add your DATABASE_URL to Keychain:"
echo ""
echo "1. Get your connection string from Supabase:"
echo "   - Go to: https://supabase.com/dashboard/project/vmdyznckaqmdjzxnfitl/settings/database"
echo "   - Copy the 'Connection pooling' URI (Session mode)"
echo ""
echo "2. Store it in Keychain:"
echo "   DATABASE_URL='postgresql://postgres.vmdyznckaqmdjzxnfitl:[YOUR-PASSWORD]@aws-0-us-west-1.pooler.supabase.com:6543/postgres?sslmode=require' \\"
echo "   KC_SERVICE=ai-aas-hardened-lakehouse.supabase \\"
echo "   ~/.local/bin/kc-set-supabase.sh"
echo ""
echo "3. Update Claude Desktop config:"
echo "   - Open Claude Desktop Settings → Developer → Edit Config"
echo "   - Update the scout-mcp entry to:"
echo '   "supabase_scout_mcp": {'
echo '     "command": "/Users/tbwa/.local/bin/supabase-mcp-secure.sh",'
echo '     "args": []'
echo '   }'
echo ""
echo "4. Restart Claude Desktop"
