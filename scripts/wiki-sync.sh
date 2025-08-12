#!/usr/bin/env bash
set -euo pipefail
WIKI_REMOTE="${WIKI_REPO:-https://github.com/jgtolentino/ai-aas-hardened-lakehouse.wiki.git}"
SRC="${WIKI_SRC:-docs-site/wiki}"
TMP="$(mktemp -d)"
git clone "$WIKI_REMOTE" "$TMP"
rsync -a --delete "$SRC"/ "$TMP"/
cd "$TMP"
git add .
if ! git diff --cached --quiet; then
  git commit -m "docs: wiki sync $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  git push origin master
  echo "[wiki] Pushed."
else
  echo "[wiki] No changes."
fi