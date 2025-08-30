#!/bin/bash

# Make all scripts executable
chmod +x /Users/tbwa/ai-aas-hardened-lakehouse/commit-code-connect.sh
chmod +x /Users/tbwa/ai-aas-hardened-lakehouse/apps/scout-dashboard/deploy-dashboard.sh
chmod +x /Users/tbwa/ai-aas-hardened-lakehouse/apps/scout-dashboard/scripts/setup-code-connect.sh

echo "✅ Scripts are now executable"
echo ""
echo "To implement Code Connect, run:"
echo "  ./commit-code-connect.sh"
echo ""
echo "For full deployment:"
echo "  cd apps/scout-dashboard && ./deploy-dashboard.sh"
