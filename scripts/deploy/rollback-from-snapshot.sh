#!/usr/bin/env bash
# scripts/deploy/rollback-from-snapshot.sh
# Restores DB from a gzipped pg_dump snapshot (dangerous; confirm target!)
set -euo pipefail
SNAP="${1:-}"
TARGET="${TARGET:-staging}"
[[ -n "$SNAP" && -f "$SNAP" ]] || { echo "Usage: $0 /path/to/snapshot.sql.gz"; exit 2; }

PG_URL="${PG_CONN_URL:-$(bruno env:get PG_CONN_URL 2>/dev/null || true)}"
[[ -n "$PG_URL" ]] || { echo "PG_CONN_URL not set in env/Bruno"; exit 3; }
read -r -p "⚠️ This will overwrite $TARGET database. Type 'ROLLBACK' to continue: " yn
[[ "$yn" == "ROLLBACK" ]] || { echo "Aborted."; exit 1; }

echo "== Restoring $SNAP to $TARGET"
gunzip -c "$SNAP" | psql "$PG_URL"
echo "✅ Restore complete"
