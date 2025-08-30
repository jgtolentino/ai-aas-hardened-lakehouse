#!/usr/bin/env bash
# scripts/deploy/smoke.sh — quick endpoint checks (run locally or in CI)
set -euo pipefail
pull(){ bruno env:get "$1" 2>/dev/null || true; }
SUPABASE_URL="${SUPABASE_URL:-$(pull SUPABASE_URL)}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-$(pull SUPABASE_ANON_KEY)}"
SUPABASE_PROJECT_REF="${SUPABASE_PROJECT_REF:-$(pull SUPABASE_PROJECT_REF)}"

fail=0
check(){ [[ "$1" == "0" ]] || fail=1; }

echo "== REST root"
code=$(curl -sS -o /dev/null -w "%{http_code}" -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/rest/v1/")
[[ "$code" == "200" || "$code" == "404" ]]; check $?

echo "== Edge function /broker"
if [[ -n "$SUPABASE_PROJECT_REF" ]]; then
  code=$(curl -sS -o /dev/null -w "%{http_code}" "https://${SUPABASE_PROJECT_REF}.functions.supabase.co/broker?op=health")
  [[ "$code" == "200" ]]; check $?
else
  echo "ℹ️ Skipping broker check (no project ref)"
fi

echo "== Scout schema tables"
tables=("consumer_segments" "regional_performance" "competitive_intelligence" "behavioral_analytics")
for table in "${tables[@]}"; do
  code=$(curl -sS -o /dev/null -w "%{http_code}" -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/rest/v1/${table}?limit=1")
  [[ "$code" == "200" ]]; check $?
  echo "  ✓ scout.$table reachable"
done

echo "== Scout functions"
functions=("get_consumer_segments" "get_regional_metrics" "get_competitive_analysis" "get_behavioral_metrics" "get_finebank_kpis")
for func in "${functions[@]}"; do
  code=$(curl -sS -o /dev/null -w "%{http_code}" -H "apikey: $SUPABASE_ANON_KEY" -H "Content-Type: application/json" \
    -d '{}' "$SUPABASE_URL/rest/v1/rpc/${func}")
  [[ "$code" == "200" ]]; check $?
  echo "  ✓ scout.$func() callable"
done

[[ $fail -eq 0 ]] && echo "✅ Smoke OK" || { echo "❌ Smoke failed"; exit 1; }
