#!/usr/bin/env bash
set -euo pipefail
: "${LAKE_BUCKET:?set LAKE_BUCKET=<bucket>}"
for src in policies/*-policy.json; do
  dst="infra/data-lake/terraform/$(basename "$src")"
  sed "s/\${bucket_name}/$LAKE_BUCKET/g" "$src" > "$dst"
  echo "→ rendered $(basename "$dst")"
done
echo "Now create IAM policies/roles and attach these JSONs."