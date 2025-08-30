#!/usr/bin/env bash
# Scout v6.0 Production Deployment Pipeline
# Atomic rollout: RLS+AI migrations, Edge functions, Frontend builds, Smoke tests
# Usage: ./deploy-scout-batch.sh [staging|production]
set -euo pipefail

ROOT="${ROOT:-/Users/tbwa/ai-aas-hardened-lakehouse}"
cd "$ROOT"

# ── Config ──────────────────────────────────────────────────────────────────
TARGET="${TARGET:-staging}"           # staging|prod
APP_DIR="$ROOT/apps/scout-dashboard"
BRAND_KIT_DIR="$ROOT/apps/brand-kit"
MIG_DIR="$ROOT/supabase/migrations"
FUNC_NAME="broker"

# Pull env from Bruno if not exported
pull() { bruno env:get "$1" 2>/dev/null || true; }
export SUPABASE_URL="${SUPABASE_URL:-$(pull SUPABASE_URL)}"
export SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-$(pull SUPABASE_ANON_KEY)}"
export SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-$(pull SUPABASE_SERVICE_ROLE_KEY)}"
export SUPABASE_PROJECT_REF="${SUPABASE_PROJECT_REF:-$(pull SUPABASE_PROJECT_REF)}"
export PG_CONN_URL="${PG_CONN_URL:-$(pull PG_CONN_URL)}"
export VERCEL_TOKEN="${VERCEL_TOKEN:-$(pull VERCEL_TOKEN)}"
export VERCEL_PROJECT_ID="${VERCEL_PROJECT_ID:-$(pull VERCEL_PROJECT_ID)}"
export VERCEL_ORG_ID="${VERCEL_ORG_ID:-$(pull VERCEL_ORG_ID)}"

# ── Preconditions ───────────────────────────────────────────────────────────
need() { command -v "$1" >/dev/null || { echo "Missing dependency: $1"; exit 2; }; }
need supabase; need jq; need curl
[[ -d "$MIG_DIR" ]] || { echo "Missing migrations dir: $MIG_DIR"; exit 3; }

echo "== Rollout Target: $TARGET"
echo "== Project Ref    : ${SUPABASE_PROJECT_REF:-<unset>}"

# ── Optional: DB snapshot (rollback) ────────────────────────────────────────
SNAP_OK=0
if [[ -n "${PG_CONN_URL:-}" ]] && command -v pg_dump >/dev/null; then
  SNAP_DIR="$ROOT/.snapshots"
  mkdir -p "$SNAP_DIR"
  SNAP_FILE="$SNAP_DIR/pg_${TARGET}_$(date +%Y%m%d_%H%M%S).sql.gz"
  echo "== Taking DB snapshot to $SNAP_FILE"
  pg_dump --no-owner --no-privileges "$PG_CONN_URL" | gzip -9 > "$SNAP_FILE" && SNAP_OK=1 || SNAP_OK=0
  [[ $SNAP_OK -eq 1 ]] && echo "✅ Snapshot saved" || echo "⚠️ Snapshot failed (continuing)"
else
  echo "ℹ️ Skipping snapshot (PG_CONN_URL or pg_dump missing)"
fi

# ── Environment writes for FE (public-only) ─────────────────────────────────
mkdir -p "$APP_DIR"
cat > "$APP_DIR/.env.local" <<EOF
NEXT_PUBLIC_SUPABASE_URL=${SUPABASE_URL}
NEXT_PUBLIC_SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
NEXT_PUBLIC_ENABLE_PBI=0
NEXT_PUBLIC_ENABLE_TABLEAU=0
NEXT_PUBLIC_ENABLE_SUPERSET=0
EOF
echo "✅ Wrote $APP_DIR/.env.local"

# Also write for brand-kit app
mkdir -p "$BRAND_KIT_DIR"
cat > "$BRAND_KIT_DIR/.env.local" <<EOF
NEXT_PUBLIC_SUPABASE_URL=${SUPABASE_URL}
NEXT_PUBLIC_SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
EOF
echo "✅ Wrote $BRAND_KIT_DIR/.env.local"

# ── Migrations ──────────────────────────────────────────────────────────────
echo "== Applying Supabase migrations"
# Ensure linked (no-op if already linked)
if ! supabase projects list >/dev/null 2>&1; then
  echo "ℹ️ 'supabase projects' unavailable (older CLI); continuing."
fi
if [[ -n "${SUPABASE_PROJECT_REF:-}" ]]; then
  supabase link --project-ref "$SUPABASE_PROJECT_REF" || true
fi
supabase db push
echo "✅ Migrations applied"

# ── Edge Function deploy ────────────────────────────────────────────────────
echo "== Deploying Edge Function: $FUNC_NAME"
supabase functions deploy "$FUNC_NAME"
echo "✅ Edge deployed"

# ── Edge health check (deployed) ────────────────────────────────────────────
if [[ -n "${SUPABASE_PROJECT_REF:-}" ]]; then
  EDGE_URL="https://${SUPABASE_PROJECT_REF}.functions.supabase.co/${FUNC_NAME}?op=health"
  code=$(curl -sS -o /tmp/edge_health.json -w "%{http_code}" "$EDGE_URL" || true)
  if [[ "$code" == "200" ]]; then
    echo "✅ Edge health OK: $(jq -r '.ok' /tmp/edge_health.json) @ $(jq -r '.ts' /tmp/edge_health.json)"
  else
    echo "❌ Edge health check failed ($code) at $EDGE_URL"; exit 11
  fi
else
  echo "ℹ️ Skipping remote Edge health (SUPABASE_PROJECT_REF missing)"
fi

# ── Build FE (workspace safe) ───────────────────────────────────────────────
echo "== Building frontend"
if command -v pnpm >/dev/null; then
  pnpm i --frozen-lockfile || pnpm i
  (cd "$APP_DIR" && pnpm build)
  (cd "$BRAND_KIT_DIR" && pnpm build)
else
  need npm
  npm ci || npm i
  (cd "$APP_DIR" && npm run build)
  (cd "$BRAND_KIT_DIR" && npm run build)
fi
echo "✅ Frontend built"

# ── Optional Vercel deploy ──────────────────────────────────────────────────
if [[ "${DEPLOY_VERCEL:-0}" == "1" ]]; then
  need vercel
  [[ -n "${VERCEL_TOKEN:-}" && -n "${VERCEL_PROJECT_ID:-}" && -n "${VERCEL_ORG_ID:-}" ]] || { echo "Vercel env missing"; exit 12; }
  echo "== Vercel deploy (atomic)"
  vercel deploy --prod --token "$VERCEL_TOKEN" --yes --scope "$VERCEL_ORG_ID" --project "$VERCEL_PROJECT_ID"
  echo "✅ Vercel deploy triggered"
else
  echo "ℹ️ Skipping Vercel deploy (set DEPLOY_VERCEL=1 to enable)"
fi

# ── API smoke checks (REST/RLS surface) ─────────────────────────────────────
echo "== REST anon reachability smoke"
code=$(curl -sS -o /dev/null -w "%{http_code}" -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/rest/v1/")
[[ "$code" == "200" || "$code" == "404" ]] && echo "✅ REST reachable ($code)" || { echo "❌ REST unreachable ($code)"; exit 13; }

# Check scout schema tables
echo "== Scout schema tables smoke"
tables=("consumer_segments" "regional_performance" "competitive_intelligence" "behavioral_analytics")
for table in "${tables[@]}"; do
  code=$(curl -sS -o /dev/null -w "%{http_code}" -H "apikey: $SUPABASE_ANON_KEY" "$SUPABASE_URL/rest/v1/${table}?limit=1")
  [[ "$code" == "200" ]] && echo "✅ Table scout.$table reachable" || echo "⚠️ Table scout.$table not accessible ($code)"
done

echo "== DONE: Scout v6 rollout complete ($TARGET)"
if [[ $SNAP_OK -eq 1 ]]; then echo "ℹ️ Snapshot at: $SNAP_FILE"; fi
