#!/usr/bin/env bash
set -euo pipefail

# 1) Secret scan (fast-fail)
scripts/security/scan_secrets.sh

# 2) Quick grep for common leaks in tracked files
rg -n --hidden --glob '!node_modules' --glob '!*example*' \
  '(ghp_[A-Za-z0-9]{36}|pk\.[A-Za-z0-9]{60,}|sbp_[A-Za-z0-9]{40,}|Bearer\s+[A-Za-z0-9\-\._~\+\/]+=*)' \
  || true

# 3) Ensure .env not tracked
if git ls-files | rg -q '^\.env'; then
  echo "❌ .env is tracked. Remove from git."
  exit 1
fi

echo "✅ Pre-deploy audit passed."
