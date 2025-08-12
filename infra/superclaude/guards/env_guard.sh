#!/usr/bin/env bash
set -euo pipefail

# Block SC from overriding Anthropic routing or credentials
for var in ANTHROPIC_API_KEY ANTHROPIC_BASE_URL ANTHROPIC_MODEL; do
  if grep -R --exclude-dir=vendor -nE "$var\s*=" infra/superclaude/vendor >/dev/null; then
    echo "[BLOCK] SuperClaude tries to set $var. Remove it or patch vendor." >&2
    exit 42
  fi
done

echo "[OK] Environment variables are protected"