#!/usr/bin/env bash
set -euo pipefail

DAYS="${DAYS:-14}"                           # window for "auto-writes" scan
AGENT_RE='Pulser|Bruno|Claude|bot|GitHub Actions|CI'

# --- detect package manager ---
PKG="npm"; RUN_I="npm ci"; RUN_BUILD="npm run build"
[[ -f pnpm-lock.yaml ]] && PKG="pnpm" && RUN_I="pnpm i --frozen-lockfile" && RUN_BUILD="pnpm build"
[[ -f yarn.lock ]]       && PKG="yarn" && RUN_I="yarn install --frozen-lockfile" && RUN_BUILD="yarn build"

# --- basic platform checks ---
echo "== Docusaurus presence =="
HAS_DOCUS=$(node -e "try{const p=require('./package.json');const d={...p.dependencies,...p.devDependencies};process.exit(d&&d['@docusaurus/core']?0:1)}catch{process.exit(1)}" || true)
[[ "$HAS_DOCUS" == "0" ]] && echo "✔ @docusaurus/core found" || { echo "✖ @docusaurus/core not found"; exit 2; }
ls docusaurus.config.* >/dev/null 2>&1 && echo "✔ docusaurus.config present" || { echo "✖ missing docusaurus.config.(js|ts)"; exit 2; }
[[ -d docs ]] && echo "✔ docs/ folder present" || echo "⚠ docs/ missing (may be a pages-only site)"
ls sidebars.* >/dev/null 2>&1 && echo "✔ sidebars file present" || echo "⚠ sidebars file missing"

# --- recent auto-writes by agents/bots ---
echo
echo "== Auto-writes in last ${DAYS} days =="
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "✖ not a git repo"; exit 2; }
git log --since="${DAYS} days ago" --pretty=format:'%C(auto)%h%x09%an%x09%s' --name-only \
    -- docs/** blog/** sidebars.* docusaurus.config.* 2>/dev/null | awk 'NF' | sed 's/^/  /'

echo
echo "== Agent-authored commits (filter) =="
git log --since="${DAYS} days ago" --pretty=format:'%h%x09%an%x09%s' -- docs/** blog/** sidebars.* docusaurus.config.* 2>/dev/null \
  | grep -E "${AGENT_RE}" || echo "  (none found)"

# --- build check ---
echo
echo "== Install + Build (${PKG}) =="
eval "$RUN_I"
eval "$RUN_BUILD"

# --- optional link check (if linkinator available) ---
if npx --yes --package linkinator@^4 -c "linkinator --version" >/dev/null 2>&1; then
  echo
  echo "== Link check =="
  npx --yes linkinator ./build --recurse --silent --timeout 30000 || true
else
  echo "ℹ linkinator not installed; skipping static link check (optional)."
fi

echo
echo "✅ Docusaurus validated. See above for agent/bot commit evidence."