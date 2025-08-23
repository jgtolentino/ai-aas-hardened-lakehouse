#!/usr/bin/env bash
# Test database connection without exposing credentials

set -euo pipefail

# Load environment
[[ -f .env ]] && source .env
[[ -f /Users/tbwa/.env ]] && source /Users/tbwa/.env

# Build DB URL if needed
if [[ -z "${SUPABASE_DB_URL:-}" ]] && [[ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  SUPABASE_PROJECT_REF="${SUPABASE_PROJECT_REF:-cxzllzyxwpyptfretryc}"
  SUPABASE_DB_URL="postgresql://postgres.${SUPABASE_PROJECT_REF}:${SUPABASE_SERVICE_ROLE_KEY}@aws-0-us-west-1.pooler.supabase.com:6543/postgres"
fi

: "${SUPABASE_DB_URL:?Missing SUPABASE_DB_URL}"
: "${PGSSLMODE:=require}"

echo "🔌 Testing database connection..."
PGPASSWORD='' psql "$SUPABASE_DB_URL" -c "SELECT version();" -t -A | head -1
echo "✅ Connection successful"