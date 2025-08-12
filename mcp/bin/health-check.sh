#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== MCP Health Check ==="
echo "Time: $(date)"
echo

# Source environment if available
if [ -f "$MCP_DIR/config/.env.mcp" ]; then
  set -a
  source "$MCP_DIR/config/.env.mcp"
  set +a
else
  echo "[WARNING] No .env.mcp file found"
fi

# Function to check server
check_server() {
  local server_name=$1
  local check_command=$2
  
  echo -n "Checking $server_name... "
  if eval "$check_command" >/dev/null 2>&1; then
    echo "✓ OK"
    return 0
  else
    echo "✗ FAILED"
    return 1
  fi
}

# Check filesystem access
check_server "Filesystem" "test -d '$MCP_DIR'"

# Check Context7 (if enabled)
if [ "${MCP_ENABLE_CONTEXT7:-true}" = "true" ]; then
  check_server "Context7" "command -v context7-mcp"
fi

# Check Supabase MCP
check_server "Supabase MCP" "npx -y @supabase/mcp-server-supabase@latest --version"

# Check PostgreSQL connectivity (if local)
if [ -n "${DATABASE_URL:-}" ]; then
  check_server "PostgreSQL" "npx -y @modelcontextprotocol/server-postgres --version"
fi

# Check configuration files
echo
echo "=== Configuration Status ==="
for config in "$MCP_DIR/config/mcp-servers.json" "$MCP_DIR/config/.env.mcp"; do
  if [ -f "$config" ]; then
    echo "✓ $(basename "$config") exists"
  else
    echo "✗ $(basename "$config") missing"
  fi
done

# Check security components
echo
echo "=== Security Components ==="
if [ -f "$MCP_DIR/guards/mcp-security-guard.ts" ]; then
  echo "✓ Security guard present"
else
  echo "✗ Security guard missing"
fi

if [ -f "$MCP_DIR/middleware/mcp-interceptor.ts" ]; then
  echo "✓ Interceptor present"
else
  echo "✗ Interceptor missing"
fi

# Check audit logging
echo
echo "=== Audit System ==="
LOG_DIR="${MCP_AUDIT_LOG_PATH:-/tmp/mcp/logs}"
if [ -d "$(dirname "$LOG_DIR")" ]; then
  echo "✓ Audit directory exists"
  if [ -f "$LOG_DIR/audit.log" ]; then
    echo "  Last entry: $(tail -1 "$LOG_DIR/audit.log" 2>/dev/null || echo "No entries")"
  fi
else
  echo "✗ Audit directory missing"
fi

# Generate summary
echo
echo "=== Summary ==="
jq -r '.mcpServers | to_entries | .[] | "- \(.key): \(.value.command)"' "$MCP_DIR/config/mcp-servers.json" 2>/dev/null || echo "Failed to parse configuration"

echo
echo "Health check complete."