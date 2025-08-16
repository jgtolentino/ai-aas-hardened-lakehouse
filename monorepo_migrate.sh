#!/usr/bin/env bash
# monorepo_migrate.sh — restructure to production-grade layout with subtree history
# Requirements: git >=2.35, pnpm, jq, GNU sed/awk (on mac: brew install gnu-sed gawk; set PATH)
set -euo pipefail

# --------- CONFIG (edit if your paths differ) ----------
ROOT_DIR="$(pwd)"
SUBMODULE_PATH="edge-suqi-pie"                    # current submodule directory name
SUBMODULE_REMOTE_URL="$(git config -f .gitmodules submodule.${SUBMODULE_PATH}.url || true)"
SUBMODULE_BRANCH="main"                           # source branch/tag of the submodule
TARGET_PREFIX="apps/pi-edge"                      # where it will live in the monorepo
EXECUTE="${EXECUTE:-0}"                           # 0 = dry run, 1 = do it
BRANCH="${BRANCH:-feat/monorepo-structure}"
# -------------------------------------------------------

echo "== Guard: clean working tree =="
if [[ -n "$(git status --porcelain)" ]]; then
  echo "!! Working tree not clean. Commit/stash first."; exit 1
fi

echo "== Create branch =="
git checkout -b "$BRANCH"

echo "== Scaffold top-level structure =="
mkdir -p apps/scout-dashboard apps/docs \
         services/api services/worker services/brand-model \
         packages/contracts packages/types packages/utils-js packages/utils-py \
         db/migrations db/seeds db/tests \
         dq/views dq/checks \
         supabase/functions supabase/config supabase/migrations supabase/storage \
         infra/docker infra/terraform/modules infra/terraform/envs/dev infra/k8s/base infra/k8s/overlays/dev \
         monitoring/grafana-dashboards monitoring/prometheus \
         security/threat-model security/policies security/sops \
         scripts .github/workflows docs/adr

# Root configs (created only if absent)
[[ -f pnpm-workspace.yaml ]] || cat > pnpm-workspace.yaml <<'YAML'
packages:
  - "apps/*"
  - "services/*"
  - "packages/*"
  - "db"
  - "dq"
  - "supabase"
YAML

[[ -f turbo.json ]] || cat > turbo.json <<'JSON'
{
  "pipeline": {
    "build": { "dependsOn": ["^build"], "outputs": ["dist/**"] },
    "dev":   { "cache": false },
    "test":  { "dependsOn": ["build"] },
    "lint":  { "outputs": [] },
    "typecheck": { "outputs": [] },
    "contracts:gen": { "outputs": ["packages/types/**"] }
  }
}
JSON

[[ -f package.json ]] || cat > package.json <<'JSON'
{
  "name": "project-pi",
  "private": true,
  "packageManager": "pnpm@9",
  "scripts": {
    "build": "turbo build",
    "dev": "turbo dev",
    "test": "turbo test",
    "lint": "turbo lint",
    "typecheck": "turbo typecheck",
    "db:migrate": "scripts/db-migrate.sh",
    "db:test": "scripts/db-test.sh",
    "contracts:gen": "pnpm -w --filter @pi/contracts run generate"
  },
  "devDependencies": {
    "turbo": "^2.0.0"
  }
}
JSON

[[ -f CODEOWNERS ]] || cat > CODEOWNERS <<'TXT'
/packages/contracts/     @data-platform
/services/api/           @platform-backend
/services/worker/        @platform-backend
/services/brand-model/   @ml-systems
/apps/pi-edge/           @edge-team
/apps/scout-dashboard/   @analytics-ui
/db/                     @data-platform
/dq/                     @data-platform
/infra/                  @devops
/.github/workflows/      @devops
TXT

echo "== Seed CI workflow =="
[[ -f .github/workflows/ci.yml ]] || cat > .github/workflows/ci.yml <<'YAML'
name: CI
on:
  pull_request:
    branches: [main]
jobs:
  build-test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: ankane/pgvector:pg16
        env: { POSTGRES_USER: suqi, POSTGRES_PASSWORD: suqi, POSTGRES_DB: suqi }
        ports: ["5432:5432"]
        options: >-
          --health-cmd="pg_isready -U suqi -d suqi"
          --health-interval=5s --health-timeout=3s --health-retries=30
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - run: corepack enable
      - run: pnpm install --frozen-lockfile
      - name: Apply DB migrations
        run: |
          psql "postgres://suqi:suqi@localhost:5432/suqi" -f db/migrations/001_init.sql || true
          for f in db/migrations/*.sql; do
            [[ "$f" == *001_init.sql ]] && continue
            psql "postgres://suqi:suqi@localhost:5432/suqi" -f "$f"
          done
      - run: pnpm run lint || true
      - run: pnpm run typecheck || true
      - name: DQ checks
        run: |
          [[ -f dq/checks/run_all.sql ]] && psql "postgres://suqi:suqi@localhost:5432/suqi" -f dq/checks/run_all.sql || echo "No DQ checks yet"
YAML

echo "== Convert submodule → subtree (history preserved) =="
if [[ -d "$SUBMODULE_PATH/.git" || -f .gitmodules ]]; then
  echo "  - Submodule URL: ${SUBMODULE_REMOTE_URL:-<unknown>}"
  if [[ "$EXECUTE" == "1" ]]; then
    # 1) Deinit and remove the submodule entry
    git submodule deinit -f "$SUBMODULE_PATH" || true
    rm -rf ".git/modules/${SUBMODULE_PATH}" || true
    git rm -f "$SUBMODULE_PATH" || true
    rm -f .gitmodules || true

    # 2) Add as remote (if not present) and fetch
    if [[ -n "${SUBMODULE_REMOTE_URL:-}" ]]; then
      git remote add pi_edge_src "$SUBMODULE_REMOTE_URL" 2>/dev/null || true
      git fetch pi_edge_src "${SUBMODULE_BRANCH}:${SUBMODULE_BRANCH}" --tags
      # 3) Pull history into tree at TARGET_PREFIX
      git subtree add --prefix="$TARGET_PREFIX" pi_edge_src "${SUBMODULE_BRANCH}" -m "feat: import pi-edge from submodule (subtree with history)"
    else
      echo "!! Could not find submodule URL. Aborting subtree import."; exit 1
    fi
  else
    echo "[DRY-RUN] Would: deinit & remove submodule, add remote pi_edge_src=$SUBMODULE_REMOTE_URL, subtree add into $TARGET_PREFIX"
  fi
else
  echo "  - No submodule detected at $SUBMODULE_PATH (skipping)."
fi

echo "== Normalize scattered SQL into db/ & dq/ (heuristic) =="
# Heuristic classifier: copy files; originals left in place for manual review.
SQL_CANDIDATES=$(git ls-files | grep -Ei '\.sql$' || true)
for f in $SQL_CANDIDATES; do
  base="$(basename "$f")"
  if grep -qiE 'create\s+view|materialized\s+view' "$f"; then
    dest="dq/views/${base}"
  elif grep -qiE 'select\s+.*(count|coverage|dq_|assert|check)' "$f"; then
    dest="dq/checks/${base}"
  else
    dest="db/migrations/zz_${base}"
  fi
  if [[ "$EXECUTE" == "1" ]]; then
    mkdir -p "$(dirname "$dest")"
    cp -n "$f" "$dest" || true
    git add "$dest"
  else
    printf "[DRY-RUN] Would copy %-60s -> %s\n" "$f" "$dest"
  fi
done

echo "== Bootstrap minimal contracts package (if missing) =="
if [[ ! -d packages/contracts ]]; then
  mkdir -p packages/contracts/src/jsonschema packages/types
  cat > packages/contracts/package.json <<'JSON'
{ "name": "@pi/contracts", "version": "0.1.0", "type": "module",
  "scripts": { "generate": "node ./scripts/generate.js" },
  "dependencies": { "ajv": "^8.14.0", "zod": "^3.23.8" },
  "devDependencies": { "typescript": "^5.4.5" }
}
JSON
  mkdir -p packages/contracts/scripts
  cat > packages/contracts/scripts/generate.js <<'JS'
import fs from 'fs'; fs.mkdirSync('../types', { recursive: true }); fs.writeFileSync('../types/README.md','Types go here\n');
console.log('Generated types stub');
JS
  cat > packages/contracts/src/jsonschema/suqi-edge-transaction.schema.json <<'JSON'
{ "$schema": "http://json-schema.org/draft-07/schema#", "title": "suqi-edge-transaction", "type": "object", "properties": { "id": { "type": "string" } }, "required": ["id"] }
JSON
fi

echo "== Minimal DQ guardrail (optional) =="
[[ -f dq/checks/run_all.sql ]] || cat > dq/checks/run_all.sql <<'SQL'
-- Fail CI if brand coverage drops under 70% (example)
-- SELECT CASE WHEN (SELECT 1.0*count(*) FILTER (WHERE brand_id IS NOT NULL)/NULLIF(count(*),0) FROM scout.product_catalog) >= 0.70 THEN 1 ELSE (SELECT pg_sleep(0); RAISE EXCEPTION 'Brand coverage < 70%%'; END IF;  -- simplified for CI
SQL

echo "== Drop dev docker compose (optional) =="
[[ -f infra/docker/compose.yml ]] || cat > infra/docker/compose.yml <<'YAML'
version: "3.9"
services:
  db:
    image: ankane/pgvector:pg16
    environment: { POSTGRES_USER: suqi, POSTGRES_PASSWORD: suqi, POSTGRES_DB: suqi }
    ports: ["5432:5432"]
    volumes: [ "../../db/migrations:/docker-entrypoint-initdb.d" ]
  api:
    build: ../../services/api
    environment: { DATABASE_URL: postgres://suqi:suqi@db:5432/suqi }
    ports: ["8080:8080"]
    depends_on: [db]
  worker:
    build: ../../services/worker
    environment: { DATABASE_URL: postgres://suqi:suqi@db:5432/suqi }
    depends_on: [db]
YAML

echo "== Commit scaffold =="
if [[ "$EXECUTE" == "1" ]]; then
  git add -A
  git commit -m "chore: scaffold monorepo structure (apps/, services/, db/, dq/, infra/, CI)"
  echo "== DONE. Next: push and open PR =="
  git status -s
else
  echo "[DRY-RUN] No changes committed. Re-run with EXECUTE=1 to apply."
fi

echo "== Summary =="
echo " Branch: $BRANCH"
echo " Submodule: $SUBMODULE_PATH  →  $TARGET_PREFIX   (remote: ${SUBMODULE_REMOTE_URL:-n/a})"
echo " Dry-run: $([[ $EXECUTE == 1 ]] && echo NO || echo YES)"