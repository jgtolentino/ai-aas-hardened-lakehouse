#!/usr/bin/env bash
set -euo pipefail
BASE="${SUPERSET_BASE}"
TOKEN=$(curl -sX POST "$BASE/api/v1/security/login" -H 'Content-Type: application/json' \
  -d "{\"username\":\"$SUPERSET_USER\",\"password\":\"$SUPERSET_PASSWORD\",\"provider\":\"db\",\"refresh\":true}" | jq -r .access_token)
mkdir -p /tmp/ss && cd /tmp/ss
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/api/v1/assets/export" -o export.zip
unzip -q export.zip
find . -type f -name "*.yaml" -print0 | sort -z | xargs -0 sha256sum > /tmp/ss/export.sha
# Compare with committed checksum (update it intentionally when you change assets)
git -C "$GITHUB_WORKSPACE" ls-files platform/superset/assets '**/*.yaml' >/dev/null 2>&1 || true
( cd "$GITHUB_WORKSPACE/platform/superset/assets" && find . -type f -name "*.yaml" -print0 | sort -z | xargs -0 sha256sum ) > /tmp/ss/git.sha || true
diff -u /tmp/ss/git.sha /tmp/ss/export.sha && echo "✓ No drift" || { echo "✖ Superset asset drift detected"; exit 1; }