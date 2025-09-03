#!/usr/bin/env bash
set -euo pipefail

# Memory Bridge MCP Server
# Session history management for Scout system

# Set environment variables
export SESSION_DB=/Users/tbwa/ai-aas-hardened-lakehouse/session-history/sessions.db
export SCOUT_RAG_ENABLED=true
export PROJECT_ROOT=/Users/tbwa/ai-aas-hardened-lakehouse

# Create sessions.db if it doesn't exist
if [ ! -f "$SESSION_DB" ]; then
    echo "Creating session database at $SESSION_DB"
    mkdir -p "$(dirname "$SESSION_DB")"
    touch "$SESSION_DB"
fi

# Launch the memory bridge server
exec npx @modelcontextprotocol/server-memory server
