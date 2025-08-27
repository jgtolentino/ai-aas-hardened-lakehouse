#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"

echo "🔧 Fixing agent compliance issues..."

# Fix quality-engineer
echo "Fixing quality-engineer..."
yq -i '.metadata.id = "quality-engineer-v2"' "$ROOT/pulser/agents/quality-engineer.yaml"
yq -i '.metadata.codename = "quality-engineer-v2"' "$ROOT/pulser/agents/quality-engineer.yaml"
yq -i '.metadata.owner = "quality@insightpulse.ai"' "$ROOT/pulser/agents/quality-engineer.yaml"
yq -i '.metadata.status = "active"' "$ROOT/pulser/agents/quality-engineer.yaml"

# Fix security-engineer
echo "Fixing security-engineer..."
yq -i '.metadata.id = "security-engineer-v1"' "$ROOT/pulser/agents/security-engineer.yaml"
yq -i '.metadata.codename = "security-engineer-v1"' "$ROOT/pulser/agents/security-engineer.yaml"
yq -i '.metadata.owner = "security@insightpulse.ai"' "$ROOT/pulser/agents/security-engineer.yaml"
yq -i '.metadata.status = "active"' "$ROOT/pulser/agents/security-engineer.yaml"

# Fix technical-writer
echo "Fixing technical-writer..."
yq -i '.metadata.id = "technical-writer-v1"' "$ROOT/pulser/agents/technical-writer.yaml"
yq -i '.metadata.codename = "technical-writer-v1"' "$ROOT/pulser/agents/technical-writer.yaml"
yq -i '.metadata.owner = "docs@insightpulse.ai"' "$ROOT/pulser/agents/technical-writer.yaml"
yq -i '.metadata.status = "active"' "$ROOT/pulser/agents/technical-writer.yaml"

# Fix backend-architect
echo "Fixing backend-architect..."
yq -i '.metadata.owner = "backend@insightpulse.ai"' "$ROOT/pulser/agents/backend-architect.yaml"
yq -i '.metadata.status = "active"' "$ROOT/pulser/agents/backend-architect.yaml"

# Fix frontend-architect
echo "Fixing frontend-architect..."
yq -i '.metadata.owner = "frontend@insightpulse.ai"' "$ROOT/pulser/agents/frontend-architect.yaml"
yq -i '.metadata.status = "active"' "$ROOT/pulser/agents/frontend-architect.yaml"

# Fix performance-engineer
echo "Fixing performance-engineer..."
yq -i '.metadata.owner = "performance@insightpulse.ai"' "$ROOT/pulser/agents/performance-engineer.yaml"
yq -i '.metadata.status = "active"' "$ROOT/pulser/agents/performance-engineer.yaml"

# Fix dash
echo "Fixing dash..."
yq -i '.metadata.owner = "ui@insightpulse.ai"' "$ROOT/pulser/agents/dash.yaml"
yq -i '.metadata.status = "active"' "$ROOT/pulser/agents/dash.yaml"

# Fix devstral
echo "Fixing devstral..."
yq -i '.metadata.owner = "architecture@insightpulse.ai"' "$ROOT/pulser/agents/devstral.yaml"
yq -i '.metadata.status = "active"' "$ROOT/pulser/agents/devstral.yaml"

# Fix maya
echo "Fixing maya..."
yq -i '.metadata.owner = "docs@insightpulse.ai"' "$ROOT/pulser/agents/maya.yaml"
yq -i '.metadata.status = "active"' "$ROOT/pulser/agents/maya.yaml"

# Fix superclaude-cicd-workflow
echo "Fixing superclaude-cicd-workflow..."
yq -i '.metadata.id = "superclaude-cicd-orchestrator-v1"' "$ROOT/pulser/agents/superclaude-cicd-workflow.yaml"
yq -i '.metadata.codename = "superclaude-cicd-orchestrator-v1"' "$ROOT/pulser/agents/superclaude-cicd-workflow.yaml"
yq -i '.metadata.name = "superclaude-cicd-orchestrator"' "$ROOT/pulser/agents/superclaude-cicd-workflow.yaml"
yq -i '.metadata.type = "orchestrator"' "$ROOT/pulser/agents/superclaude-cicd-workflow.yaml"
yq -i '.metadata.owner = "cicd@insightpulse.ai"' "$ROOT/pulser/agents/superclaude-cicd-workflow.yaml"
yq -i '.metadata.status = "active"' "$ROOT/pulser/agents/superclaude-cicd-workflow.yaml"

# Fix QA agent
if [[ -f "$ROOT/qa/pulser/agents/qa-browser-use.yaml" ]]; then
  echo "Fixing qa-browser-use..."
  yq -i '.metadata.id = "qa-browser-use-v1"' "$ROOT/qa/pulser/agents/qa-browser-use.yaml"
  yq -i '.metadata.codename = "qa-browser-use-v1"' "$ROOT/qa/pulser/agents/qa-browser-use.yaml"
  yq -i '.metadata.type = "engineer"' "$ROOT/qa/pulser/agents/qa-browser-use.yaml"
  yq -i '.metadata.owner = "qa@insightpulse.ai"' "$ROOT/qa/pulser/agents/qa-browser-use.yaml"
  yq -i '.metadata.status = "active"' "$ROOT/qa/pulser/agents/qa-browser-use.yaml"
fi

# Fix MCP agents
echo "Fixing MCP agents..."
yq -i '.metadata.id = "docs-writer-v1"' "$ROOT/mcp/agents/docs-writer.yaml"
yq -i '.metadata.codename = "docs-writer-v1"' "$ROOT/mcp/agents/docs-writer.yaml"
yq -i '.metadata.owner = "docs@insightpulse.ai"' "$ROOT/mcp/agents/docs-writer.yaml"
yq -i '.metadata.status = "active"' "$ROOT/mcp/agents/docs-writer.yaml"

yq -i '.metadata.id = "scout-docs-writer-v1"' "$ROOT/mcp/agents/scout-docs-writer.yaml"
yq -i '.metadata.codename = "scout-docs-writer-v1"' "$ROOT/mcp/agents/scout-docs-writer.yaml"
yq -i '.metadata.owner = "scout@insightpulse.ai"' "$ROOT/mcp/agents/scout-docs-writer.yaml"
yq -i '.metadata.status = "active"' "$ROOT/mcp/agents/scout-docs-writer.yaml"

# Fix config agent
echo "Fixing suqi-agentic-intel..."
yq -i '.metadata.id = "suqi-agentic-intel-v1"' "$ROOT/config/agentic-analytics.yaml"
yq -i '.metadata.owner = "analytics@insightpulse.ai"' "$ROOT/config/agentic-analytics.yaml"
yq -i '.metadata.status = "active"' "$ROOT/config/agentic-analytics.yaml"
yq -i '.tools = ["Read", "Write", "Bash"]' "$ROOT/config/agentic-analytics.yaml"

# Remove any embedded secrets from security-engineer.yaml
echo "Removing potential secrets from security-engineer.yaml..."
sed -i.bak '/api_key/d; /password/d; /token/d; /secret/d' "$ROOT/pulser/agents/security-engineer.yaml" || true
rm -f "$ROOT/pulser/agents/security-engineer.yaml.bak"

echo "✅ Fixed compliance issues in agent files"