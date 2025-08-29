#!/bin/bash
# Zero-click dashboard retargeting
# Usage: ./retarget-dashboard.sh "executive kpi" "TBWA"

set -euo pipefail

QUERY="${1:-}"
BRAND="${2:-}"
SCRIPTDIR="$(dirname "$(realpath "$0")")"
HUBDIR="$SCRIPTDIR/../infra/mcp-hub"

# Configuration
HUB_API_KEY="${HUB_API_KEY:-dev-key-12345}"
HUB_URL="${HUB_URL:-http://localhost:8787}"
OUTPUT_DIR="${OUTPUT_DIR:-./output}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

usage() {
  cat << EOF
Zero-Click Dashboard Retargeting

USAGE:
  $0 <search_query> <brand_name>

EXAMPLES:
  $0 "executive kpi" "TBWA"
  $0 "financial dashboard" "Nike"
  $0 "analytics cards" "Apple"

ENVIRONMENT VARIABLES:
  HUB_API_KEY     API key for MCP Hub (default: dev-key-12345)
  HUB_URL         MCP Hub URL (default: http://localhost:8787)
  OUTPUT_DIR      Output directory (default: ./output)
  FIGMA_TEAM_ID   Figma team ID for new file creation

EOF
}

check_requirements() {
  local missing=0
  
  for cmd in curl jq node; do
    if ! command -v "$cmd" &> /dev/null; then
      error "Required command '$cmd' not found"
      ((missing++))
    fi
  done
  
  if [[ $missing -gt 0 ]]; then
    error "Please install missing requirements"
    exit 1
  fi
  
  # Check if MCP Hub is running
  if ! curl -sf "$HUB_URL/health" &> /dev/null; then
    warn "MCP Hub not running at $HUB_URL"
    log "Starting MCP Hub..."
    cd "$HUBDIR" && npm run start &
    sleep 3
  fi
}

search_design() {
  local query="$1"
  local kind="${2:-dashboard}"
  
  log "Searching for design: '$query' (kind: $kind)"
  
  local search_payload
  search_payload=$(jq -n \
    --arg text "$query" \
    --arg kind "$kind" \
    '{text: $text, kind: $kind, limit: 5}')
  
  local response
  response=$(curl -s -X POST "$HUB_URL/mcp/design/search" \
    -H "X-API-Key: $HUB_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$search_payload")
  
  if [[ $(echo "$response" | jq -r '.results | length') -eq 0 ]]; then
    error "No designs found for query: '$query'"
    return 1
  fi
  
  echo "$response"
}

apply_brand_patch() {
  local file_key="$1"
  local node_id="$2"
  local brand="$3"
  
  log "Applying brand patch for: $brand"
  
  # Create patch specification based on brand
  local patch_spec
  case "$brand" in
    "TBWA"|"tbwa")
      patch_spec=$(jq -n '{
        target: {
          fileKey: $file_key,
          nodeId: $node_id,
          selectors: ["*"]
        },
        operations: [
          {
            type: "style",
            changes: {
              fills: [{"type": "SOLID", "color": {"r": 0.11, "g": 0.25, "b": 0.69}}],
              textStyles: {"fontFamily": "Inter", "fontWeight": 600}
            }
          },
          {
            type: "text",
            find: "Company Name",
            replace: "TBWA"
          },
          {
            type: "text",
            find: "Brand",
            replace: "TBWA"
          }
        ],
        options: {
          preview: false,
          parallel: true,
          timeout: 30000
        }
      }' --arg file_key "$file_key" --arg node_id "$node_id")
      ;;
    "Nike"|"nike")
      patch_spec=$(jq -n '{
        target: {
          fileKey: $file_key,
          nodeId: $node_id,
          selectors: ["*"]
        },
        operations: [
          {
            type: "style",
            changes: {
              fills: [{"type": "SOLID", "color": {"r": 0, "g": 0, "b": 0}}],
              textStyles: {"fontFamily": "Nike Futura", "fontWeight": 700}
            }
          },
          {
            type: "text",
            find: "Company Name",
            replace: "Nike"
          }
        ]
      }' --arg file_key "$file_key" --arg node_id "$node_id")
      ;;
    "Apple"|"apple")
      patch_spec=$(jq -n '{
        target: {
          fileKey: $file_key,
          nodeId: $node_id,
          selectors: ["*"]
        },
        operations: [
          {
            type: "style",
            changes: {
              fills: [{"type": "SOLID", "color": {"r": 0.92, "g": 0.92, "b": 0.92}}],
              textStyles: {"fontFamily": "SF Pro Display", "fontWeight": 400}
            }
          },
          {
            type: "text",
            find: "Company Name",
            replace: "Apple"
          }
        ]
      }' --arg file_key "$file_key" --arg node_id "$node_id")
      ;;
    *)
      # Generic brand patch
      patch_spec=$(jq -n '{
        target: {
          fileKey: $file_key,
          nodeId: $node_id,
          selectors: ["*"]
        },
        operations: [
          {
            type: "text",
            find: "Company Name",
            replace: $brand
          },
          {
            type: "text",
            find: "Brand",
            replace: $brand
          }
        ]
      }' --arg file_key "$file_key" --arg node_id "$node_id" --arg brand "$brand")
      ;;
  esac
  
  # Apply patch via Figma Bridge
  local response
  response=$(curl -s -X POST "$HUB_URL/mcp/run" \
    -H "X-API-Key: $HUB_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --argjson spec "$patch_spec" '{
      server: "figma",
      tool: "figma_apply_patch",
      args: {patchSpec: $spec}
    }')")
  
  if [[ $(echo "$response" | jq -r '.error // empty') ]]; then
    error "Patch application failed: $(echo "$response" | jq -r '.error')"
    return 1
  fi
  
  echo "$response"
}

export_design() {
  local file_key="$1"
  local node_id="$2"
  local brand="$3"
  
  mkdir -p "$OUTPUT_DIR"
  
  log "Exporting design to $OUTPUT_DIR"
  
  # Export as PNG
  local export_response
  export_response=$(curl -s -X POST "$HUB_URL/mcp/run" \
    -H "X-API-Key: $HUB_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg file_key "$file_key" --arg node_id "$node_id" '{
      server: "figma",
      tool: "figma_export",
      args: {
        fileKey: $file_key,
        nodeId: $node_id,
        format: "PNG",
        scale: 2
      }
    }')")
  
  if [[ $(echo "$export_response" | jq -r '.error // empty') ]]; then
    warn "Export failed, continuing without export"
    return 0
  fi
  
  local export_url
  export_url=$(echo "$export_response" | jq -r '.data.url // empty')
  
  if [[ -n "$export_url" ]]; then
    local filename="${brand}-dashboard-$(date +%Y%m%d-%H%M%S).png"
    curl -s "$export_url" -o "$OUTPUT_DIR/$filename"
    success "Design exported to: $OUTPUT_DIR/$filename"
  fi
}

commit_changes() {
  local brand="$1"
  
  if [[ ! -d .git ]]; then
    warn "Not a git repository, skipping commit"
    return 0
  fi
  
  log "Committing changes to git"
  
  git add "$OUTPUT_DIR" || true
  git commit -m "feat: retarget dashboard for $brand

🎨 Applied brand customizations via zero-click automation
- Modified design elements for $brand brand compliance
- Updated text content and styling
- Exported final design assets

Generated with Claude Code automation script" || warn "Nothing to commit"
}

main() {
  if [[ $# -lt 2 ]]; then
    usage
    exit 1
  fi
  
  local query="$1"
  local brand="$2"
  
  log "Starting zero-click dashboard retargeting"
  log "Query: $query"
  log "Brand: $brand"
  
  check_requirements
  
  # Step 1: Find design matching criteria
  log "Step 1: Finding design candidates"
  local search_results
  search_results=$(search_design "$query")
  
  local design
  design=$(echo "$search_results" | jq -r '.results[0]')
  
  if [[ "$design" == "null" ]]; then
    error "No suitable designs found"
    exit 1
  fi
  
  local file_key node_id title
  file_key=$(echo "$design" | jq -r '.file_key')
  node_id=$(echo "$design" | jq -r '.node_id')
  title=$(echo "$design" | jq -r '.title')
  
  success "Found design: $title"
  log "File: $file_key"
  log "Node: $node_id"
  
  # Step 2: Apply brand patch
  log "Step 2: Applying brand customizations"
  local patch_result
  patch_result=$(apply_brand_patch "$file_key" "$node_id" "$brand")
  
  success "Brand patch applied successfully"
  
  # Step 3: Export final design
  log "Step 3: Exporting final design"
  export_design "$file_key" "$node_id" "$brand"
  
  # Step 4: Commit changes
  log "Step 4: Committing changes"
  commit_changes "$brand"
  
  success "Zero-click retargeting complete!"
  log "Results available in: $OUTPUT_DIR"
}

# Handle interruption gracefully
trap 'error "Process interrupted"; exit 130' INT TERM

main "$@"