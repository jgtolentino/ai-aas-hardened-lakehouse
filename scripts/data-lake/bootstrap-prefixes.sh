#!/usr/bin/env bash
set -euo pipefail
: "${LAKE_BUCKET:?set LAKE_BUCKET=<bucket>}"
: "${AWS_REGION:?set AWS_REGION}"
echo "Creating canonical prefixes + placeholders…"
for p in bronze silver gold platinum; do
  aws s3api put-object --bucket "$LAKE_BUCKET" --key "$p/" >/dev/null
done
# Example partition placeholders
aws s3api put-object --bucket "$LAKE_BUCKET" --key "bronze/source=pos/dt=2025-09-03/_SUCCESS" >/dev/null
aws s3api put-object --bucket "$LAKE_BUCKET" --key "silver/source=pos/dt=2025-09-03/_SUCCESS" >/dev/null
echo "Done."