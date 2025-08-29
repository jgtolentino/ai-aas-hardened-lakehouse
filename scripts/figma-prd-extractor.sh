#!/bin/bash

# Figma PRD Extractor
# Extracts Product Requirements Document content from Figma boards via bridge

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIGMA_BRIDGE_PORT=${FIGMA_BRIDGE_PORT:-3001}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[PRD Extractor]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[PRD Extractor]${NC} $1"
}

error() {
    echo -e "${RED}[PRD Extractor]${NC} $1"
    exit 1
}

# Check if Figma Bridge is running
check_bridge_status() {
    if curl -s "http://localhost:$FIGMA_BRIDGE_PORT/api/health" >/dev/null 2>&1; then
        log "Figma Bridge is responding on port $FIGMA_BRIDGE_PORT"
        return 0
    else
        error "Figma Bridge is not responding. Start it first with: ./scripts/figma-bridge.sh start"
    fi
}

# Extract PRD content from Figma board
extract_prd_content() {
    local figma_url="$1"
    
    log "Extracting PRD content from Figma board..."
    
    # Extract board ID from URL
    local board_id=$(echo "$figma_url" | sed 's/.*\/board\/\([^\/]*\)\/.*/\1/')
    log "Board ID: $board_id"
    
    # Create extraction request
    local extraction_request='{
        "type": "extract-prd-content",
        "board_url": "'$figma_url'",
        "board_id": "'$board_id'",
        "extraction_targets": [
            "user-stories",
            "requirements",
            "wireframes",
            "user-flows",
            "acceptance-criteria",
            "technical-specs",
            "design-tokens",
            "components"
        ]
    }'
    
    # Send request to Figma Bridge
    log "Sending extraction request to Figma Bridge..."
    
    local response
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$extraction_request" \
        "http://localhost:$FIGMA_BRIDGE_PORT/api/extract-prd" 2>/dev/null || echo '{"error": "Bridge not responding"}')
    
    if echo "$response" | grep -q '"error"'; then
        warn "Direct extraction failed. Creating manual extraction prompt..."
        create_manual_extraction_guide "$figma_url"
    else
        log "PRD content extracted successfully"
        echo "$response" | jq '.' > "$PROJECT_ROOT/docs/extracted-prd.json"
        log "PRD content saved to docs/extracted-prd.json"
        
        # Convert to markdown
        convert_prd_to_markdown "$PROJECT_ROOT/docs/extracted-prd.json"
    fi
}

# Create manual extraction guide
create_manual_extraction_guide() {
    local figma_url="$1"
    
    log "Creating manual extraction guide..."
    
    cat > "$PROJECT_ROOT/docs/prd-extraction-guide.md" << EOF
# Product Requirements Document - Manual Extraction Guide

## Figma Board
- **URL**: $figma_url
- **Extraction Date**: $(date)

## Manual Extraction Process

Since the Figma board is private, please follow these steps to extract the PRD content:

### 1. Access Verification
- [ ] Confirm you have access to the Figma board
- [ ] Verify the board contains a Product Requirements Document
- [ ] Note the board structure (pages, sections, frames)

### 2. Content Extraction Checklist

#### User Stories
- [ ] Extract all user story cards/frames
- [ ] Note priority levels (High, Medium, Low)
- [ ] Document acceptance criteria for each story
- [ ] Capture story points or effort estimates

#### Requirements
- [ ] Functional requirements list
- [ ] Non-functional requirements (performance, security, usability)
- [ ] Business requirements and objectives
- [ ] Technical constraints and dependencies

#### Design Specifications
- [ ] Wireframes for each screen/component
- [ ] User flow diagrams
- [ ] Information architecture
- [ ] Design system tokens (colors, typography, spacing)

#### Technical Specifications
- [ ] API requirements and endpoints
- [ ] Database schema requirements
- [ ] Third-party integrations
- [ ] Performance requirements
- [ ] Security requirements

### 3. Extraction Template

Use this template to structure the extracted content:

\`\`\`markdown
# [Product Name] - Requirements Document

## 1. Product Overview
- **Product Name**: 
- **Version**: 
- **Last Updated**: 
- **Stakeholders**: 

## 2. User Stories
### Epic 1: [Epic Name]
- **User Story 1**: As a [user type], I want [goal] so that [benefit]
  - **Acceptance Criteria**: 
    - [ ] Criterion 1
    - [ ] Criterion 2
  - **Priority**: High/Medium/Low
  - **Effort**: [Story Points]

## 3. Functional Requirements
- **FR001**: [Requirement description]
- **FR002**: [Requirement description]

## 4. Non-Functional Requirements
- **Performance**: 
- **Security**: 
- **Usability**: 
- **Scalability**: 

## 5. Technical Specifications
### API Endpoints
- **GET /api/endpoint**: Description
- **POST /api/endpoint**: Description

### Database Schema
\`\`\`sql
-- Table definitions
\`\`\`

### Third-Party Integrations
- **Service 1**: Purpose and integration details
- **Service 2**: Purpose and integration details

## 6. User Flows
- **Flow 1**: [Description and steps]
- **Flow 2**: [Description and steps]

## 7. Wireframes
- **Screen 1**: Description and key elements
- **Screen 2**: Description and key elements

## 8. Design System
### Colors
- Primary: #000000
- Secondary: #ffffff

### Typography
- Heading: Font family, size, weight
- Body: Font family, size, weight

### Components
- Button styles
- Form elements
- Navigation patterns
\`\`\`

### 4. Next Steps
1. Fill out the extraction template above
2. Save as \`docs/product-requirements.md\`
3. Validate with stakeholders
4. Update the enterprise bridges with new requirements
EOF

    log "Manual extraction guide created at docs/prd-extraction-guide.md"
}

# Convert JSON PRD to Markdown
convert_prd_to_markdown() {
    local json_file="$1"
    
    if [[ ! -f "$json_file" ]]; then
        warn "JSON file not found: $json_file"
        return 1
    fi
    
    log "Converting PRD to Markdown format..."
    
    # Use jq to convert JSON to structured markdown
    cat > "$PROJECT_ROOT/docs/product-requirements.md" << EOF
# Product Requirements Document

$(jq -r '.title // "Untitled Product"' "$json_file")

**Extracted**: $(date)
**Source**: $(jq -r '.source_url // "Unknown"' "$json_file")

## User Stories

$(jq -r '.user_stories[]? // empty | "- **\(.title // "Untitled")**: \(.description // "No description")"' "$json_file")

## Functional Requirements

$(jq -r '.requirements.functional[]? // empty | "- **\(.id // "REQ")**: \(.description // "No description")"' "$json_file")

## Non-Functional Requirements

$(jq -r '.requirements.non_functional[]? // empty | "- **\(.category // "General")**: \(.description // "No description")"' "$json_file")

## Technical Specifications

$(jq -r '.technical_specs // "No technical specifications found"' "$json_file")

## Design Components

$(jq -r '.components[]? // empty | "- **\(.name // "Unnamed")**: \(.description // "No description")"' "$json_file")

EOF

    log "PRD converted to Markdown at docs/product-requirements.md"
}

# Main execution
main() {
    local figma_url="${1:-}"
    
    if [[ -z "$figma_url" ]]; then
        echo "Usage: $0 <figma_board_url>"
        echo "Example: $0 'https://www.figma.com/board/BLdSOtPdiUrIbmoNkyhmvF/Product-Requirements-Document'"
        exit 1
    fi
    
    log "Starting PRD extraction from Figma board..."
    
    # Check if bridge is available
    check_bridge_status
    
    # Extract PRD content
    extract_prd_content "$figma_url"
    
    log "PRD extraction completed successfully"
}

# Run main function with all arguments
main "$@"