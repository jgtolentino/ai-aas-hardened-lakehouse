#!/usr/bin/env bash
set -euo pipefail
miss=0
need=(
  ".github/workflows/ci.yml"
  "platform/scout/bruno"
  "platform/superset/assets"
  "platform/scout/migrations"
  "platform/scout/functions"
  "platform/lakehouse/dbt"
  "platform/security"
  "great_expectations"
  "tools"
  "scripts/verify_deployment.sh"
  "scripts/validate_bindings.py"
)
for p in "${need[@]}"; do
  [[ -e "$p" ]] || { echo "MISSING: $p"; miss=1; }
done
exit $miss