#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-.}"
name="${2:-}"
type="${3:-engineer}"
owner="${4:-platform@insightpulse.ai}"
major="${5:-1}"

[[ -n "$name" ]] || { echo "Usage: $0 <repo-root> <name-kebab> [type] [owner-email] [major]"; exit 2; }

codename="${name}-v${major}"
file="$ROOT/pulser/agents/${name}.yaml"

mkdir -p "$ROOT/pulser/agents" "$ROOT/pulser/registry"

cat > "$file" <<YAML
metadata:
  id: ${codename}
  codename: ${codename}
  name: $(echo "$name" | sed 's/-/ /g' | sed 's/\b./\u&/g')
  version: "1.0.0"
  type: ${type}
  owner: "${owner}"
  frameworks: [pulser, superclaude]
  status: active
  tags:
    - ${type}
    - scout
    - anthropic-first
  
description: "ADD DESCRIPTION HERE"

capabilities:
  - name: primary_capability
    description: "Primary capability of this agent"
    inputSchema:
      type: object
      properties:
        param1:
          type: string
          description: "Description of parameter 1"
      required:
        - param1
    permissions:
      - file:read
      - file:write

policy:
  boundaries:
    will:
      - "Operate within assigned directory scope"
      - "Follow Anthropic's constitutional AI principles"
      - "Validate inputs before processing"
    will_not:
      - "Access external networks without explicit permission"
      - "Modify files outside assigned scope"
      - "Store or transmit secrets in plain text"

tools:
  required: [Read, Write, Bash]
  optional: [Grep, LS]

security:
  sandboxed: true
  allowedHosts: []
  deniedActions:
    - network:external
    - secrets:read
  requiredPermissions:
    - file:read
    - file:write

limits:
  maxExecutionTime: 300000  # 5 minutes
  maxMemoryMB: 512
  maxConcurrent: 3

routing:
  priority: 50
  patterns:
    - "${name}:*"

tasks:
  - name: hello
    description: "Test task for ${codename}"
    run:
      - 'echo "Hello from ${codename}"'
      - 'echo "Type: ${type}, Owner: ${owner}"'

pulser:
  registration: automatic
  tags: ["${type}", "scout", "anthropic-first"]
YAML

# Add to registry if not present
REG="$ROOT/pulser/registry/agents.yaml"
if [[ ! -f "$REG" ]]; then
  cat > "$REG" <<REG
version: 1
updated: $(date -u +%F)
owners:
  default_team: "InsightPulseAI"
schema:
  codename: "^[a-z0-9][a-z0-9-]*-v[0-9]+$"
  version: "^[0-9]+\\.[0-9]+\\.[0-9]+$"
agents: []
REG
fi

# Update registry
yq -i ".updated = \"$(date -u +%F)\"" "$REG"

# Check if agent already exists in registry
existing=$(yq -r ".agents[] | select(.codename == \"${codename}\") | .codename" "$REG" 2>/dev/null || true)
if [[ -z "$existing" ]]; then
  yq -i ".agents += [{\"codename\":\"${codename}\",\"file\":\"pulser/agents/${name}.yaml\",\"owner\":\"${owner}\",\"status\":\"active\"}]" "$REG"
  echo "✅ Added ${codename} to registry"
else
  echo "⚠️  ${codename} already in registry, skipping registry update"
fi

# Validate
echo "Validating agent configuration..."
bash "$ROOT/scripts/agents-validate.sh" "$ROOT" || true

echo "✅ Created agent ${codename} at $file"
echo ""
echo "Next steps:"
echo "1. Update the description in $file"
echo "2. Define specific capabilities for your agent"
echo "3. Update the will/will_not boundaries"
echo "4. Add any additional tools required"
echo "5. Run: ./scripts/agents-validate.sh . to verify compliance"