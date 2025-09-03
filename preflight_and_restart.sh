#!/usr/bin/env bash
set -euo pipefail

REPO="$HOME/ai-aas-hardened-lakehouse"
cd "$REPO"

echo "🔎 Pre-flight: checking env & wrappers…"
[ -x session-history/memory_bridge.sh ] || { echo "❌ session-history/memory_bridge.sh not executable"; exit 1; }
[ -f ~/.local/bin/supabase-mcp-secure.sh ] || { echo "❌ ~/.local/bin/supabase-mcp-secure.sh not found"; exit 1; }

# Check keychain credentials
echo "🔐 Checking keychain credentials…"
SUPABASE_ANON=$(security find-generic-password -w -s SUPABASE_ANON_KEY -a "$USER" 2>/dev/null || echo "")
SUPABASE_SERVICE=$(security find-generic-password -w -s SUPABASE_SERVICE_KEY -a "$USER" 2>/dev/null || echo "")

if [[ -z "$SUPABASE_ANON" ]]; then
  echo "❌ SUPABASE_ANON_KEY not found in keychain"
  exit 1
fi

if [[ -z "$SUPABASE_SERVICE" ]]; then
  echo "❌ SUPABASE_SERVICE_KEY not found in keychain"
  exit 1
fi

echo "✅ Keychain credentials found"

mkdir -p logs

echo "🧪 Dry-run: Memory Bridge (should start and stay alive)…"
( timeout 6 ./session-history/memory_bridge.sh server ) || true

echo "🧪 Dry-run: Supabase MCP (checking wrapper exists)…"
if [ -x ~/.local/bin/supabase-mcp-secure.sh ]; then
  echo "✅ Supabase MCP wrapper is executable"
else
  echo "❌ Supabase MCP wrapper not executable"
  exit 1
fi

echo "📄 Tail recent logs (if any):"
for f in logs/memory_bridge.log logs/supabase_mcp.log session-history/sessions.db; do
  if [ -f "$f" ]; then
    if [[ "$f" == *.log ]]; then
      echo "--- $f (last 20) ---"
      tail -n 20 "$f" 2>/dev/null || echo "No content yet"
    else
      echo "✅ $f exists ($(du -h "$f" | cut -f1))"
    fi
  else
    echo "No file yet: $f"
  fi
done

echo "🔁 Restarting Claude Desktop…"
osascript -e 'ignoring application responses
  try
    tell application "Claude" to quit
  end try
end ignoring' || true

osascript -e 'ignoring application responses
  try
    tell application "Claude Desktop" to quit
  end try
end ignoring' || true

sleep 3
open -a "Claude" || open -a "Claude Desktop"

echo "✅ Restart triggered. In Claude Desktop, check Settings → Developer → MCP Servers:"
echo "  - supabase_scout_mcp should show connected"
echo "  - memory_bridge should show connected"
echo ""
echo "If either shows 'disconnected', check logs:"
echo "  tail -n +1 -F logs/memory_bridge.log logs/supabase_mcp.log"