#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_ACCESS_TOKEN:?missing}"; : "${SUPABASE_PROJECT_REF:?missing}"; : "${SUPABASE_DB_URL:?missing}"

STAMP="$(date -u +'%Y%m%d%H%M%S')"
OUT="supabase/migrations/${STAMP}_auto.diff.sql"
echo "==> supabase db diff -> ${OUT}"
# Generate diff. If no changes, CLI exits 0 and writes an empty file/stdout.
# Use -f to write; if nothing to diff, file may be empty or small header only—filter later.
supabase db diff -f "${OUT}" --project-ref "$SUPABASE_PROJECT_REF" --db-url "$SUPABASE_DB_URL" || true

# If file is empty or only comments/whitespace, remove and exit cleanly.
if [[ ! -s "${OUT}" ]] || ! grep -qE '[A-Za-z0-9]' "${OUT}"; then
  echo "==> no schema changes; cleaning up"
  rm -f "${OUT}"
  exit 0
fi

echo "==> captured schema diff at ${OUT}"
git add "${OUT}"
git status --porcelain
