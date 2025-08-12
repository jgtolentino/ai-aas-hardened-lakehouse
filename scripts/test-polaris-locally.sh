#!/bin/bash
# scripts/test-polaris-locally.sh
set -euo pipefail
ROOT="${1:-platform}"
OUT="${2:-/tmp/polaris.json}"

echo "[*] Polaris version: $(polaris version)"
echo "[*] Auditing ${ROOT}"

polaris audit \
  --audit-path "${ROOT}" \
  --format=pretty \
  --only-show-failed-tests true \
  --set-exit-code-on-danger \
  --set-exit-code-below-score 90 | tee /tmp/polaris-pretty.txt

polaris audit \
  --audit-path "${ROOT}" \
  --format=json \
  --only-show-failed-tests true > "${OUT}"

echo "[*] JSON saved to ${OUT}"