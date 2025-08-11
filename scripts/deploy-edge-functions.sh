#!/bin/bash
# Deploy Edge Functions to Supabase
# Run this from your local machine

set -euo pipefail

PROJECT_REF="cxzllzyxwpyptfretryc"
echo "🚀 Deploying Edge Functions to project: $PROJECT_REF"

# Check if logged in
if ! supabase projects list 2>/dev/null | grep -q "$PROJECT_REF"; then
    echo "❌ Not logged in to Supabase. Run: supabase login"
    exit 1
fi

echo "📦 Deploying ingest-transaction function..."
cd /Users/tbwa/platform/supabase/functions
supabase functions deploy ingest-transaction \
    --project-ref "$PROJECT_REF" \
    --no-verify-jwt

echo "📦 Deploying load-bronze-from-storage function..."
supabase functions deploy load-bronze-from-storage \
    --project-ref "$PROJECT_REF" \
    --no-verify-jwt

echo "✅ Edge Functions deployed!"
echo ""
echo "📍 Endpoints:"
echo "  - https://$PROJECT_REF.functions.supabase.co/ingest-transaction"
echo "  - https://$PROJECT_REF.functions.supabase.co/load-bronze-from-storage"
echo ""
echo "🧪 Test with:"
echo "curl -X POST https://$PROJECT_REF.functions.supabase.co/ingest-transaction \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"store_id\":\"102\",\"peso_value\":150.50}'"