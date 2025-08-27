#!/usr/bin/env bash
set -euo pipefail
ports=(3845 3846 3847 3848)
names=("figma" "supabase" "mapbox" "vercel")
ok=0; fail=0
for i in "${!ports[@]}"; do
  p="${ports[$i]}"; n="${names[$i]}"
  if curl -sS -m 2 "http://127.0.0.1:${p}/" >/dev/null; then
    echo "✅ ${n} MCP port ${p} reachable"
    ok=$((ok+1))
  else
    echo "❌ ${n} MCP port ${p} not reachable"
    fail=$((fail+1))
  fi
done
echo "Done. OK=${ok} FAIL=${fail}"
test $fail -eq 0
