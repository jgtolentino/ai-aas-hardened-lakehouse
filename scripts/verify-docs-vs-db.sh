#!/usr/bin/env bash
set -euo pipefail

# Load environment
[[ -f .env ]] && source .env
[[ -f /Users/tbwa/.env ]] && source /Users/tbwa/.env

# Build DB URL if needed
if [[ -z "${SUPABASE_DB_URL:-}" ]] && [[ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  SUPABASE_PROJECT_REF="${SUPABASE_PROJECT_REF:-cxzllzyxwpyptfretryc}"
  SUPABASE_DB_URL="postgresql://postgres.${SUPABASE_PROJECT_REF}:${SUPABASE_SERVICE_ROLE_KEY}@aws-0-us-west-1.pooler.supabase.com:6543/postgres"
fi

DB_DSN="${SCOUT_READONLY_DSN:-$SUPABASE_DB_URL}"
: "${DB_DSN:?Database connection not set}"

DBML="docs-site/static/dbml/scout-schema-v3-complete.dbml"

echo "▶️ Counting DB objects…"
DB_TABLES=$(psql "$DB_DSN" -Atc "
  SELECT COUNT(*) 
  FROM information_schema.tables 
  WHERE table_schema IN ('scout', 'bronze', 'silver', 'gold', 'master_data', 'masterdata', 'deep_research')
    AND table_type = 'BASE TABLE';")

DB_VIEWS=$(psql "$DB_DSN" -Atc "
  SELECT COUNT(*) 
  FROM information_schema.tables 
  WHERE table_schema IN ('scout', 'bronze', 'silver', 'gold', 'analytics')
    AND table_type = 'VIEW';")

echo "DB tables=$DB_TABLES views=$DB_VIEWS"

echo "▶️ Validating DBML with @dbml/cli…"
command -v dbml2sql >/dev/null || { echo "Installing @dbml/cli…"; npm i -g @dbml/cli >/dev/null; }
dbml2sql "$DBML" --postgres -o /tmp/_scout_v3.sql >/dev/null 2>&1 || {
  echo "❌ DBML validation failed"
  exit 1
}

# Extract table names from the generated SQL (robust vs regex over DBML)
DBML_TABLES=$(grep -Eo '^CREATE TABLE [^ (]+' /tmp/_scout_v3.sql | awk '{print $3}' | wc -l | tr -d ' ')

echo "DBML tables=$DBML_TABLES"

# Threshold checks
EXP_TABLES=81
TOLERANCE=5

if [[ "$DBML_TABLES" -lt $((EXP_TABLES-TOLERANCE)) ]]; then
  echo "❌ DBML table count low (got $DBML_TABLES, expected around $EXP_TABLES)."
  exit 2
fi

if [[ "$DB_TABLES" -lt $((EXP_TABLES-TOLERANCE)) ]]; then
  echo "⚠️  DB table count is $DB_TABLES (expected around $EXP_TABLES)"
  echo "    This may be OK if migrations are pending"
fi

# Name parity sample: ensure canonical dim tables exist
echo "▶️ Checking canonical dimension tables…"
for t in dim_stores dim_products dim_customers dim_campaigns; do
  # Check in DB
  DB_EXISTS=$(psql "$DB_DSN" -Atc "
    SELECT EXISTS(
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema='scout' AND table_name='$t'
    );")
  
  if [[ "$DB_EXISTS" != "t" ]]; then
    echo "⚠️  Missing $t in DB (may need migration)"
  fi
  
  # Check in DBML SQL
  if ! grep -q "scout\.$t" /tmp/_scout_v3.sql 2>/dev/null; then
    echo "❌ Missing $t in DBML SQL"
    exit 3
  fi
done

# Check for v3 specific features
echo "▶️ Checking v3 features…"
V3_FEATURES=$(psql "$DB_DSN" -Atc "
  SELECT 
    EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'stt_brand_requests') as has_stt,
    EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'scraping_queue') as has_scraping,
    EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema IN ('master_data', 'masterdata') AND table_name = 'brands') as has_brands,
    EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'scout' AND table_name = 'psgc_regions') as has_psgc;")

echo "V3 features in DB: $V3_FEATURES"

# Clean up
rm -f /tmp/_scout_v3.sql

echo "✅ Docs ↔ DB parity check complete"
echo ""
echo "Summary:"
echo "- DBML declares: $DBML_TABLES tables"
echo "- Database has: $DB_TABLES tables, $DB_VIEWS views"
echo "- Expected: ~$EXP_TABLES tables"

exit 0