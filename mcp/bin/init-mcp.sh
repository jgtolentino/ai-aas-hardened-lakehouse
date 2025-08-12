#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$MCP_DIR")"

echo "[MCP] Initializing Model Context Protocol servers..."

# Check for environment file
if [ ! -f "$MCP_DIR/config/.env.mcp" ]; then
  echo "[ERROR] Missing .env.mcp file. Please copy .env.mcp.example and configure it."
  echo "       cp $MCP_DIR/config/.env.mcp.example $MCP_DIR/config/.env.mcp"
  exit 1
fi

# Source environment
set -a
source "$MCP_DIR/config/.env.mcp"
set +a

# Validate required variables
REQUIRED_VARS=(
  "CONTEXT7_API_KEY"
  "SUPABASE_PROJECT_REF"
  "SUPABASE_ACCESS_TOKEN"
)

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "[ERROR] Required environment variable $var is not set"
    exit 1
  fi
done

# Create log directory
LOG_DIR="${MCP_AUDIT_LOG_PATH:-/tmp/mcp/logs}"
mkdir -p "$(dirname "$LOG_DIR")"

# Validate MCP servers configuration
echo -n "Validating MCP configuration... "
if jq . "$MCP_DIR/config/mcp-servers.json" >/dev/null 2>&1; then
  echo "✓"
else
  echo "✗"
  echo "[ERROR] Invalid JSON in mcp-servers.json"
  exit 1
fi

# Test Context7 connectivity
if [ "${MCP_ENABLE_CONTEXT7:-true}" = "true" ]; then
  echo -n "Testing Context7 connectivity... "
  if command -v context7-mcp >/dev/null 2>&1; then
    echo "✓"
  else
    echo "⚠ context7-mcp not found, installing..."
    npm install -g context7-mcp
  fi
fi

# Test Supabase MCP
echo -n "Testing Supabase MCP... "
if npx -y @supabase/mcp-server-supabase@latest --version >/dev/null 2>&1; then
  echo "✓"
else
  echo "✗"
  echo "[ERROR] Failed to run Supabase MCP server"
  exit 1
fi

# Create symbolic link for Claude Desktop
CLAUDE_CONFIG_DIR="$HOME/.claude"
if [ -d "$CLAUDE_CONFIG_DIR" ]; then
  echo -n "Linking configuration for Claude Desktop... "
  ln -sf "$MCP_DIR/config/mcp-servers.json" "$CLAUDE_CONFIG_DIR/mcp-servers.json" && echo "✓" || echo "✗"
fi

# Generate security report
echo -n "Generating security report... "
cat > "$MCP_DIR/security-report.txt" << EOF
MCP Security Configuration Report
Generated: $(date)

Servers Configured:
$(jq -r '.mcpServers | keys[]' "$MCP_DIR/config/mcp-servers.json")

Security Settings:
- Default filesystem access: $(jq -r '.security.defaultPermissions.filesystem' "$MCP_DIR/config/mcp-servers.json")
- Default network access: $(jq -r '.security.defaultPermissions.network' "$MCP_DIR/config/mcp-servers.json")
- Default execute access: $(jq -r '.security.defaultPermissions.execute' "$MCP_DIR/config/mcp-servers.json")
- Audit logging: $(jq -r '.security.auditLogging' "$MCP_DIR/config/mcp-servers.json")

Rate Limits:
- Requests per minute: $(jq -r '.rateLimits.default.requests_per_minute' "$MCP_DIR/config/mcp-servers.json")
- Concurrent connections: $(jq -r '.rateLimits.default.concurrent_connections' "$MCP_DIR/config/mcp-servers.json")
EOF
echo "✓"

echo
echo "[OK] MCP initialization complete!"
echo "[INFO] Security report saved to: $MCP_DIR/security-report.txt"
echo "[INFO] To use with Claude Desktop, restart the application"
echo "[INFO] To use with Claude Code CLI, run: claude mcp list"