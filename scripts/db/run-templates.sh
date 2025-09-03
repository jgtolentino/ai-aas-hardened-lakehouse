#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Run all Supabase SQL templates (ordered), optionally seed & tests.

Usage: $0 [--dry-run] [--only PATTERN] [--with-seed] [--with-tests]

Options:
  --dry-run        Show what would be run without executing
  --only PATTERN   Only run files matching PATTERN
  --with-seed      Include seed data (dev only)
  --with-tests     Run tests after migration
  -h, --help       Show this help message

Required environment variables:
  SUPABASE_PAT - Supabase Personal Access Token (or from keychain)
  
USAGE
}

DRY=0; ONLY=""; WITH_SEED=0; WITH_TESTS=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=1;;
    --only) ONLY="${2:?missing pattern}"; shift;;
    --with-seed) WITH_SEED=1;;
    --with-tests) WITH_TESTS=1;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac; shift
done

# Get Supabase PAT from keychain if not set
if [[ -z "${SUPABASE_PAT:-}" ]]; then
  echo "🔐 Loading Supabase PAT from keychain..."
  SUPABASE_PAT=$(security find-generic-password -a "supabase" -s "supabase-pat" -w 2>/dev/null || echo "")
  if [[ -z "$SUPABASE_PAT" ]]; then
    echo "❌ No SUPABASE_PAT found in environment or keychain"
    exit 1
  fi
fi

# Use postgres_local MCP to execute SQL
ROOT="$HOME/ai-aas-hardened-lakehouse"
cd "$ROOT"

# Find SQL files to run
if [[ -d supabase/templates ]]; then
  mapfile -t FILES < <(find supabase/templates -name "*.sql" | sort)
else
  echo "❌ No supabase/templates directory found"
  exit 1
fi

if [[ -n "$ONLY" ]]; then
  FILES=( $(printf "%s\n" "${FILES[@]}" | grep -E "$ONLY") )
fi

echo "📜 Will apply:"
printf "  - %s\n" "${FILES[@]}"

if [[ "$DRY" -eq 1 ]]; then
  echo "🧪 DRY RUN: Not executing."
  exit 0
fi

# Execute each template file
for f in "${FILES[@]}"; do
  echo "🚀 Applying $(basename "$f")"
  
  # Read the SQL file content
  SQL_CONTENT=$(<"$f")
  
  # Execute via postgres_local MCP (using the query function)
  echo "$SQL_CONTENT" | node /Users/tbwa/ai-aas-hardened-lakehouse/extensions/mcp-scout/postgres.js execute_sql
done

if [[ "$WITH_SEED" -eq 1 && -f supabase/seed/000_seed_dev.sql ]]; then
  echo "🌱 Applying DEV seed (do not run in prod)"
  SQL_CONTENT=$(<supabase/seed/000_seed_dev.sql)
  echo "$SQL_CONTENT" | node /Users/tbwa/ai-aas-hardened-lakehouse/extensions/mcp-scout/postgres.js execute_sql
fi

if [[ "$WITH_TESTS" -eq 1 && -f supabase/tests/001_basic_pgtap.sql ]]; then
  echo "🧪 Running pgTAP tests (local only; requires pgTAP)"
  SQL_CONTENT=$(<supabase/tests/001_basic_pgtap.sql)
  echo "$SQL_CONTENT" | node /Users/tbwa/ai-aas-hardened-lakehouse/extensions/mcp-scout/postgres.js execute_sql || true
fi

echo "🔎 Verifying schema"
SQL_CONTENT=$(<scripts/db/verify_scout.sql)
echo "$SQL_CONTENT" | node /Users/tbwa/ai-aas-hardened-lakehouse/extensions/mcp-scout/postgres.js execute_sql
