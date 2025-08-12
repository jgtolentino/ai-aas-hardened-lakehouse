#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
SC_DIR="$ROOT/infra/superclaude"

echo "[SuperClaude] Running validation checks..."

# Check guards
echo -n "Checking execution guard... "
if [ -f "$SC_DIR/guards/exec_guard.ts" ]; then
  echo "✓"
else
  echo "✗ Missing"
  exit 1
fi

echo -n "Checking environment guard... "
if [ -x "$SC_DIR/guards/env_guard.sh" ]; then
  echo "✓"
else
  echo "✗ Missing or not executable"
  exit 1
fi

# Check MCP configuration
echo -n "Checking MCP configuration... "
if grep -q '"mcpServers"' "$SC_DIR/mcp/context7.json" 2>/dev/null; then
  echo "✓"
else
  echo "✗ Invalid or missing"
  exit 1
fi

# Check adapters
echo -n "Checking adapters... "
if [ -f "$SC_DIR/adapters/sc_to_pulser.ts" ] && [ -f "$SC_DIR/adapters/persona_map.yaml" ]; then
  echo "✓"
else
  echo "✗ Missing adapter files"
  exit 1
fi

# Check vendor directory
echo -n "Checking vendor installation... "
if [ -d "$SC_DIR/vendor/SuperClaude_Framework" ]; then
  echo "✓"
else
  echo "✗ Not installed (run sc-install.sh first)"
  exit 1
fi

# Validate TypeScript
echo -n "Checking TypeScript compilation... "
if command -v tsc >/dev/null 2>&1; then
  tsc --noEmit "$SC_DIR/guards/exec_guard.ts" "$SC_DIR/adapters/sc_to_pulser.ts" 2>/dev/null && echo "✓" || {
    echo "✗ TypeScript errors"
    exit 1
  }
else
  echo "⚠ TypeScript not installed, skipping"
fi

# Security check
echo -n "Running security check... "
bash "$SC_DIR/guards/env_guard.sh" >/dev/null 2>&1 && echo "✓" || {
  echo "✗ Security guard failed"
  exit 1
}

echo
echo "[OK] All validation checks passed!"
echo "[INFO] SuperClaude integration is ready to use"