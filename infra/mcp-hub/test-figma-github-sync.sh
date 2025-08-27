#!/bin/bash
set -euo pipefail

# Test script for Figma → GitHub sync via MCP Hub
# Usage: ./test-figma-github-sync.sh [FIGMA_FILE_KEY] [HUB_URL]

FIGMA_FILE_KEY="${1:-}"
HUB_URL="${2:-http://localhost:8787}"
HUB_API_KEY="${HUB_API_KEY:-}"

if [[ -z "$HUB_API_KEY" ]]; then
    echo "❌ Error: HUB_API_KEY environment variable is required"
    exit 1
fi

if [[ -z "$FIGMA_FILE_KEY" ]]; then
    echo "❌ Error: FIGMA_FILE_KEY is required as first argument"
    echo "Usage: $0 <FIGMA_FILE_KEY> [HUB_URL]"
    exit 1
fi

echo "🚀 Testing Figma → GitHub sync workflow"
echo "Hub URL: $HUB_URL"
echo "Figma File Key: $FIGMA_FILE_KEY"
echo ""

# Test 1: Export Figma file JSON
echo "📋 Step 1: Exporting Figma file JSON..."
FIGMA_RESPONSE=$(curl -s -H "X-API-Key: $HUB_API_KEY" -H "Content-Type: application/json" \
  -d "{
    \"server\":\"figma\",
    \"tool\":\"file.exportJSON\",
    \"args\":{\"fileKey\":\"$FIGMA_FILE_KEY\"}
  }" \
  "$HUB_URL/mcp/run")

# Check if export was successful
if echo "$FIGMA_RESPONSE" | jq -e '.error' > /dev/null; then
    echo "❌ Figma export failed:"
    echo "$FIGMA_RESPONSE" | jq -r '.error // .details // .'
    exit 1
fi

# Extract file name and last modified for commit message
FILE_NAME=$(echo "$FIGMA_RESPONSE" | jq -r '.data.name // "Figma File"')
LAST_MODIFIED=$(echo "$FIGMA_RESPONSE" | jq -r '.data.lastModified // "unknown"')
echo "✅ Successfully exported: $FILE_NAME (modified: $LAST_MODIFIED)"

# Test 2: Commit to GitHub
echo ""
echo "💾 Step 2: Committing to GitHub..."
COMMIT_MESSAGE="chore(figma): sync $FILE_NAME - $LAST_MODIFIED"
COMMIT_PATH="design/figma/$(echo "$FILE_NAME" | tr ' ' '_' | tr '[:upper:]' '[:lower:]').json"

GITHUB_RESPONSE=$(curl -s -H "X-API-Key: $HUB_API_KEY" -H "Content-Type: application/json" \
  -d "{
    \"server\":\"github\",
    \"tool\":\"repo.commitFile\",
    \"args\":{
      \"path\":\"$COMMIT_PATH\",
      \"content\":$(echo "$FIGMA_RESPONSE" | jq -c '.data'),
      \"message\":\"$COMMIT_MESSAGE\"
    }
  }" \
  "$HUB_URL/mcp/run")

# Check if commit was successful
if echo "$GITHUB_RESPONSE" | jq -e '.error' > /dev/null; then
    echo "❌ GitHub commit failed:"
    echo "$GITHUB_RESPONSE" | jq -r '.error // .details // .'
    exit 1
fi

BRANCH=$(echo "$GITHUB_RESPONSE" | jq -r '.data.branch // "unknown"')
echo "✅ Successfully committed to branch: $BRANCH"
echo "📁 File path: $COMMIT_PATH"

# Test 3: Test individual node export (optional)
echo ""
echo "🎨 Step 3: Testing node export (optional)..."
NODE_RESPONSE=$(curl -s -H "X-API-Key: $HUB_API_KEY" -H "Content-Type: application/json" \
  -d "{
    \"server\":\"figma\",
    \"tool\":\"nodes.get\",
    \"args\":{\"fileKey\":\"$FIGMA_FILE_KEY\",\"ids\":[\"0:1\"]}
  }" \
  "$HUB_URL/mcp/run")

if echo "$NODE_RESPONSE" | jq -e '.error' > /dev/null; then
    echo "⚠️  Node export failed (expected for some files):"
    echo "$NODE_RESPONSE" | jq -r '.error'
else
    echo "✅ Node export successful"
fi

echo ""
echo "🎉 End-to-end test completed!"
echo "Summary:"
echo "  - Figma file exported: ✅"
echo "  - GitHub commit created: ✅"
echo "  - Branch: $BRANCH"
echo "  - Path: $COMMIT_PATH"