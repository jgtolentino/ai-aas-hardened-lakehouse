#!/usr/bin/env bash
# Deploy agentic analytics: copy assets, run SQL migrations (remote), deploy functions.
# Safe with secrets: no echoes, no set -x, no printing of envs.

set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

# --- 0) Load secrets securely ---
if command -v op >/dev/null 2>&1 && [[ -f .env.op.template ]]; then
  source scripts/load-env-from-1password.sh
elif [[ -f .envrc ]] && command -v direnv >/dev/null 2>&1; then
  # direnv will export on cd; ensure we're allowed
  direnv export bash >/dev/null || true
fi

# As a fallback, source .env **only if it exists**
[[ -f .env ]] && source .env
# Also check home directory for shared env
[[ -f /Users/tbwa/.env ]] && source /Users/tbwa/.env

# Build DB URL from Supabase credentials if not already set
if [[ -z "${SUPABASE_DB_URL:-}" ]] && [[ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  SUPABASE_PROJECT_REF="${SUPABASE_PROJECT_REF:-cxzllzyxwpyptfretryc}"
  SUPABASE_DB_URL="postgresql://postgres.${SUPABASE_PROJECT_REF}:${SUPABASE_SERVICE_ROLE_KEY}@aws-0-us-west-1.pooler.supabase.com:6543/postgres"
fi

# Required vars
: "${SUPABASE_DB_URL:?Missing SUPABASE_DB_URL}"
: "${PGSSLMODE:=require}"

echo "📦 Deploying Agentic Analytics → $(basename "$root")"

# --- 1) Validate tools ---
for t in psql; do
  command -v "$t" >/dev/null 2>&1 || { echo "❌ Missing $t"; exit 1; }
done

# --- 2) Run SQL migrations safely against remote DB ---
echo "🗃  Applying SQL migrations to remote DB (psql)…"
shopt -s nullglob
mapfile -t files < <(ls -1 supabase/migrations/20250823_*.sql 2>/dev/null | sort)
if ((${#files[@]} == 0)); then
  echo "ℹ️  No migrations to run."
else
  for f in "${files[@]}"; do
    # Skip the complete deployment script as it includes all others
    if [[ "$f" == *"complete_agentic_deployment"* ]]; then
      continue
    fi
    echo "➡️   $(basename "$f")"
    PGPASSWORD='' psql "$SUPABASE_DB_URL" \
      --set ON_ERROR_STOP=1 \
      --file "$f" \
      --quiet \
      --output /dev/null 2>&1 || {
        echo "❌ Failed: $(basename "$f")"
        exit 1
      }
    echo "✅   $(basename "$f")"
  done
fi
shopt -u nullglob

# --- 3) Verify deployment ---
echo "🔍 Verifying deployment…"
cat > /tmp/verify_agentic.sql << 'EOF'
-- Check schemas
SELECT 'Schemas' as check_type, COUNT(*) as count
FROM information_schema.schemata 
WHERE schema_name IN ('scout', 'deep_research', 'masterdata', 'staging');

-- Check core tables
SELECT 'Tables' as check_type, COUNT(*) as count
FROM information_schema.tables 
WHERE table_schema IN ('scout', 'deep_research', 'masterdata', 'staging')
  AND table_type = 'BASE TABLE';

-- Check monitors
SELECT 'Monitors' as check_type, COUNT(*) as count 
FROM scout.platinum_monitors;

-- Check brands
SELECT 'Brands' as check_type, COUNT(*) as count 
FROM masterdata.brands;
EOF

PGPASSWORD='' psql "$SUPABASE_DB_URL" \
  --file /tmp/verify_agentic.sql \
  --quiet \
  --tuples-only \
  --no-align | while IFS='|' read -r type count; do
    echo "  $type: $count"
  done

rm -f /tmp/verify_agentic.sql

# --- 4) Deploy edge functions (if present) ---
if [[ -d supabase/functions/agentic-cron ]] && command -v supabase >/dev/null 2>&1; then
  echo "🚀 Deploying edge function: agentic-cron"
  # Ensure project ref if we're using CLI deploys
  if [[ -n "${SUPABASE_PROJECT_REF:-}" ]]; then
    supabase functions deploy agentic-cron --project-ref "$SUPABASE_PROJECT_REF" --no-verify-jwt
  else
    supabase functions deploy agentic-cron --no-verify-jwt
  fi
else
  echo "ℹ️  Edge function deployment skipped (Supabase CLI not found or function missing)"
fi

# --- 5) Show next steps ---
echo ""
echo "🎉 Agentic analytics deploy complete."
echo ""
echo "📋 Next steps:"
echo "1. Import CSV data via Supabase Dashboard:"
echo "   - Go to Table Editor → staging.sku_catalog_upload"
echo "   - Import: /Users/tbwa/Downloads/sku_catalog_with_telco_filled.csv"
echo "   - Run: SELECT * FROM masterdata.import_sku_catalog();"
echo ""
echo "2. Schedule Edge Function (if deployed):"
echo "   supabase functions deploy agentic-cron --schedule '*/15 * * * *'"
echo ""
echo "3. Start Isko worker:"
echo "   deno run -A workers/isko-worker/index.ts"
echo ""
echo "4. Test monitors:"
echo "   psql \"\$SUPABASE_DB_URL\" -c \"SELECT scout.run_monitors();\""