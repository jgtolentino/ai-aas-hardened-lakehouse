#!/bin/bash
# Sample design indexing for demonstration
# Populates the design index with sample dashboard designs

set -euo pipefail

SCRIPTDIR="$(dirname "$(realpath "$0")")"
HUBDIR="$SCRIPTDIR/../infra/mcp-hub"

# Configuration
HUB_API_KEY="${HUB_API_KEY:-dev-key-12345}"
HUB_URL="${HUB_URL:-http://localhost:8787}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INDEX]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Sample design data
index_sample_designs() {
  log "Indexing sample designs for demonstration"
  
  # Start MCP Hub if not running
  if ! curl -sf "$HUB_URL/health" &>/dev/null; then
    log "Starting MCP Hub..."
    cd "$HUBDIR" && npm run start &
    sleep 3
  fi
  
  # Sample designs JSON
  local sample_designs='[
    {
      "id": "sample1:exec-dash",
      "file_key": "sample1",
      "node_id": "exec-dash",
      "title": "Executive KPI Dashboard",
      "kind": "dashboard",
      "tags": ["executive", "kpi", "12col", "cards", "finance"],
      "preview": null,
      "metadata": {
        "width": 1440,
        "height": 1024,
        "componentCount": 8,
        "textCount": 24,
        "background": "#f8fafc"
      },
      "updated_at": "2024-01-20T10:00:00Z"
    },
    {
      "id": "sample2:financial-overview",
      "file_key": "sample2", 
      "node_id": "financial-overview",
      "title": "Financial Performance Overview",
      "kind": "dashboard",
      "tags": ["finance", "charts", "analytics", "revenue"],
      "preview": null,
      "metadata": {
        "width": 1200,
        "height": 800,
        "componentCount": 6,
        "textCount": 18,
        "background": "#ffffff"
      },
      "updated_at": "2024-01-19T14:30:00Z"
    },
    {
      "id": "sample3:hr-metrics",
      "file_key": "sample3",
      "node_id": "hr-metrics", 
      "title": "HR Analytics Dashboard",
      "kind": "dashboard",
      "tags": ["hr", "analytics", "employees", "performance"],
      "preview": null,
      "metadata": {
        "width": 1440,
        "height": 900,
        "componentCount": 10,
        "textCount": 32,
        "background": "#f1f5f9"
      },
      "updated_at": "2024-01-18T09:15:00Z"
    },
    {
      "id": "sample4:sales-dashboard",
      "file_key": "sample4",
      "node_id": "sales-dashboard",
      "title": "Sales Performance Dashboard", 
      "kind": "dashboard",
      "tags": ["sales", "performance", "charts", "kpi"],
      "preview": null,
      "metadata": {
        "width": 1280,
        "height": 720,
        "componentCount": 7,
        "textCount": 21,
        "background": "#fefefe"
      },
      "updated_at": "2024-01-17T16:45:00Z"
    },
    {
      "id": "sample5:marketing-roi",
      "file_key": "sample5",
      "node_id": "marketing-roi",
      "title": "Marketing ROI Analytics",
      "kind": "dashboard", 
      "tags": ["marketing", "roi", "campaigns", "analytics"],
      "preview": null,
      "metadata": {
        "width": 1440,
        "height": 1080,
        "componentCount": 12,
        "textCount": 36,
        "background": "#f9fafb"
      },
      "updated_at": "2024-01-16T11:20:00Z"
    },
    {
      "id": "sample6:card-component",
      "file_key": "sample6",
      "node_id": "card-component",
      "title": "KPI Card Component",
      "kind": "component",
      "tags": ["card", "kpi", "reusable", "metric"],
      "preview": null,
      "metadata": {
        "width": 320,
        "height": 200,
        "componentCount": 1,
        "textCount": 4,
        "background": "#ffffff"
      },
      "updated_at": "2024-01-15T08:30:00Z"
    },
    {
      "id": "sample7:chart-template",
      "file_key": "sample7",
      "node_id": "chart-template",
      "title": "Revenue Chart Template",
      "kind": "template",
      "tags": ["chart", "template", "revenue", "line-chart"],
      "preview": null,
      "metadata": {
        "width": 600,
        "height": 400,
        "componentCount": 2,
        "textCount": 8,
        "background": "#f8f9fa"
      },
      "updated_at": "2024-01-14T13:10:00Z"
    }
  ]'
  
  # Index the designs
  local response
  response=$(curl -s -X POST "$HUB_URL/mcp/design/index" \
    -H "X-API-Key: $HUB_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"items\": $sample_designs}")
  
  local indexed_count
  indexed_count=$(echo "$response" | jq -r '.indexed // 0')
  
  success "Indexed $indexed_count sample designs"
  
  # Test search functionality
  log "Testing search functionality"
  
  local search_tests=(
    "executive:5"
    "kpi:3" 
    "finance:2"
    "dashboard:5"
    "component:1"
  )
  
  for test in "${search_tests[@]}"; do
    local query="${test%:*}"
    local expected="${test#*:}"
    
    local search_response
    search_response=$(curl -s -X POST "$HUB_URL/mcp/design/search" \
      -H "X-API-Key: $HUB_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"text\": \"$query\"}")
    
    local actual_count
    actual_count=$(echo "$search_response" | jq -r '.count // 0')
    
    if [[ "$actual_count" -ge 1 ]]; then
      success "Search '$query': found $actual_count results"
    else
      echo "Search '$query': found $actual_count results (expected >= 1)"
    fi
  done
}

main() {
  echo "============= Design Index Population ============="
  echo "Populating design index with sample data for testing"
  echo ""
  
  index_sample_designs
  
  echo ""
  success "Sample design indexing complete!"
  echo ""
  echo "You can now test the automation system with queries like:"
  echo "  ./retarget-dashboard.sh \"executive kpi\" \"TBWA\""
  echo "  ./retarget-dashboard.sh \"financial dashboard\" \"Nike\""
  echo "  ./retarget-dashboard.sh \"analytics\" \"Apple\""
}

main "$@"