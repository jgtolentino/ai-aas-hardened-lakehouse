#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_ACCESS_TOKEN:?missing}"; : "${SUPABASE_PROJECT_REF:?missing}"
echo "==> supabase db push (dry-run)"
supabase db push --project-ref "$SUPABASE_PROJECT_REF" --dry-run
echo "==> supabase db push (apply)"
supabase db push --project-ref "$SUPABASE_PROJECT_REF"
