#!/usr/bin/env bash
set -euo pipefail

fail(){ echo "❌ $*"; exit 1; }
ok(){ echo "✅ $*"; }

# Check required environment variables
required=(SUPABASE_URL SUPABASE_ANON PGURI SUPERSET_BASE SUPERSET_USER SUPERSET_PASSWORD DASHBOARD_UUID)
for v in "${required[@]}"; do
  [[ -n "${!v:-}" ]] || fail "Missing env: $v"
done

# Optional K8s validation
NAMESPACE="${CLUSTER_NAMESPACE:-aaas}"
SUPABASE_PROJECT_REF="${SUPABASE_PROJECT_REF:-cxzllzyxwpyptfretryc}"

echo "═══════════════════════════════════════════════════"
echo "Scout Analytics Platform - Enhanced Validation"
echo "═══════════════════════════════════════════════════"
echo ""

# 1) RLS negative (anon should NOT read silver)
echo -n "Testing RLS (anon blocked from silver)... "
code=$(curl -sS "${SUPABASE_URL}/rest/v1/scout.silver_transactions?select=id&limit=1" \
  -H "apikey: ${SUPABASE_ANON}" -H "Authorization: Bearer ${SUPABASE_ANON}" \
  -o /dev/null -w "%{http_code}")
[[ "$code" =~ ^(401|403)$ ]] || fail "RLS: anon unexpectedly can read silver (HTTP $code)"
ok "RLS negative passed"

# 2) Gold freshness (audited in last 10 min)
echo -n "Checking Gold MV freshness... "
fresh=$(psql "${PGURI}" -tAc "select coalesce(now() - max(refreshed_at) < interval '10 min', false) from scout.gold_refresh_audit;")
[[ "$fresh" == "t" ]] || fail "Gold not fresh in 10 min window"
ok "Gold MVs fresh"

# 3) Superset auth + guest token
echo -n "Testing Superset authentication... "
TOKEN=$(curl -sS "${SUPERSET_BASE}/api/v1/security/login" -H 'Content-Type: application/json' \
  -d "{\"username\":\"${SUPERSET_USER}\",\"password\":\"${SUPERSET_PASSWORD}\",\"provider\":\"db\",\"refresh\":true}" | jq -r .access_token)
[[ -n "$TOKEN" && "$TOKEN" != "null" ]] || fail "Superset login failed"
ok "Superset auth OK"

echo -n "Getting CSRF token... "
CSRF=$(curl -sS "${SUPERSET_BASE}/api/v1/security/csrf_token/" -H "Authorization: Bearer $TOKEN" | jq -r .result.csrf_token)
[[ -n "$CSRF" && "$CSRF" != "null" ]] || fail "Superset CSRF failed"
ok "CSRF token OK"

echo -n "Testing guest token generation... "
gt=$(curl -sS "${SUPERSET_BASE}/api/v1/security/guest_token/" \
  -H "Authorization: Bearer $TOKEN" -H "X-CSRFToken: $CSRF" -H "Referer: ${SUPERSET_BASE}" \
  -H "Content-Type: application/json" \
  -d "{\"resources\":[{\"type\":\"dashboard\",\"id\":\"${DASHBOARD_UUID}\"}]}" | jq -r .token)
[[ -n "$gt" && "$gt" != "null" ]] || fail "Superset guest token failed"
ok "Superset guest token OK"

# 4) Edge function health check
echo -n "Checking Edge Functions deployment... "
for func in ingest-transaction embed-batch genie-query ingest-doc; do
    response=$(curl -s -o /dev/null -w "%{http_code}" "${SUPABASE_URL}/functions/v1/${func}" \
        -H "Authorization: Bearer ${SUPABASE_ANON}" \
        -H "Content-Type: application/json")
    
    if [[ ! "$response" =~ ^(200|400|401|403)$ ]]; then
        fail "Edge function $func not deployed (HTTP $response)"
    fi
done
ok "All Edge Functions deployed"

# 5) Data quality check
echo -n "Checking recent transaction ingestion... "
recent_count=$(psql "${PGURI}" -tAc "SELECT COUNT(*) FROM scout.silver_transactions WHERE ts > NOW() - INTERVAL '24 hours';" 2>/dev/null || echo "0")
if [[ "$recent_count" -gt 0 ]]; then
    ok "$recent_count recent transactions"
else
    echo "⚠️  No recent transactions (non-fatal)"
fi

# 6) Kubernetes checks (if kubectl available)
if command -v kubectl >/dev/null 2>&1; then
    echo -e "\nKubernetes Infrastructure:"
    
    # Check namespace
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        ok "Namespace $NAMESPACE exists"
    else
        echo "⚠️  Namespace $NAMESPACE not found"
    fi
    
    # Check pods
    for app in minio nessie trino; do
        if kubectl -n "$NAMESPACE" get pods -l app="$app" -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then
            ok "$app is running"
        else
            echo "⚠️  $app not running"
        fi
    done
    
    # Check Gatekeeper
    if kubectl get crd constrainttemplates.templates.gatekeeper.sh >/dev/null 2>&1; then
        ok "Gatekeeper CRDs installed"
        
        # Check our constraints
        for constraint in k8scontainerprobes k8simagenolatest; do
            if kubectl get constrainttemplate "$constraint" >/dev/null 2>&1; then
                ok "Gatekeeper constraint: $constraint"
            else
                echo "⚠️  Missing constraint: $constraint"
            fi
        done
    else
        echo "⚠️  Gatekeeper not installed"
    fi
fi

echo -e "\n🎉 All critical checks passed!"
echo "The Scout Analytics Platform is hardened and ready for production."