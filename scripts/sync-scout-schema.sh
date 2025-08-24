#!/bin/bash
# sync-scout-schema.sh - Automatically sync Scout schema migrations from Supabase backend

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCOUT_DATABANK_DIR="$PROJECT_ROOT/platform/scout/scout-databank"
SUPABASE_MIGRATIONS_DIR="$PROJECT_ROOT/supabase/migrations"
LOG_FILE="$PROJECT_ROOT/logs/scout-sync-$(date +%Y%m%d-%H%M%S).log"

# Create logs directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${1}" | tee -a "$LOG_FILE"
}

# Error handler
error_exit() {
    log "${RED}ERROR: $1${NC}"
    exit 1
}

# Check if running in CI/CD or local
IS_CI="${CI:-false}"

log "${BLUE}=== Scout Schema Sync Started ===${NC}"
log "Timestamp: $(date)"
log "Project Root: $PROJECT_ROOT"

# Step 1: Update submodule
log "\n${YELLOW}Step 1: Updating scout-databank submodule...${NC}"
cd "$PROJECT_ROOT"

# Update only the scout-databank submodule specifically
git submodule update --init platform/scout/scout-databank || error_exit "Failed to update scout-databank submodule"

# Navigate to submodule and update
if [ -d "$SCOUT_DATABANK_DIR/.git" ]; then
    cd "$SCOUT_DATABANK_DIR"
    git fetch origin || log "${YELLOW}Warning: Failed to fetch from origin${NC}"
    git checkout main || git checkout master || log "${YELLOW}Warning: Failed to checkout main/master branch${NC}"
    git pull origin main || git pull origin master || log "${YELLOW}Warning: Failed to pull latest changes${NC}"
else
    log "${YELLOW}Warning: scout-databank is not a git repository, using existing files${NC}"
fi

# Step 2: Find Scout-specific migrations
log "\n${YELLOW}Step 2: Finding Scout-specific migrations...${NC}"
SCOUT_MIGRATIONS=(
    # Pattern matching for Scout-related migrations
    "scout_*.sql"
    "*scout*.sql"
    "*sari_sari*.sql"
    "*dal_*.sql"
    "*isko*.sql"
    "*agentic*.sql"
    "*products*.sql"
    "*brands*.sql"
    "*silver*.sql"
    "*gold*.sql"
    "*platinum*.sql"
)

# Create array of files to sync
declare -a FILES_TO_SYNC

# Check migrations directory
if [ -d "$SCOUT_DATABANK_DIR/migrations" ]; then
    for pattern in "${SCOUT_MIGRATIONS[@]}"; do
        while IFS= read -r -d '' file; do
            FILES_TO_SYNC+=("$file")
        done < <(find "$SCOUT_DATABANK_DIR/migrations" -name "$pattern" -type f -print0)
    done
fi

# Check supabase/migrations directory  
if [ -d "$SCOUT_DATABANK_DIR/supabase/migrations" ]; then
    for pattern in "${SCOUT_MIGRATIONS[@]}"; do
        while IFS= read -r -d '' file; do
            FILES_TO_SYNC+=("$file")
        done < <(find "$SCOUT_DATABANK_DIR/supabase/migrations" -name "$pattern" -type f -print0)
    done
fi

# Remove duplicates
FILES_TO_SYNC=($(printf "%s\n" "${FILES_TO_SYNC[@]}" | sort -u))

log "Found ${#FILES_TO_SYNC[@]} Scout-related migration files"

# Step 3: Sync migrations
log "\n${YELLOW}Step 3: Syncing migrations...${NC}"
SYNCED_COUNT=0
SKIPPED_COUNT=0

for file in "${FILES_TO_SYNC[@]}"; do
    filename=$(basename "$file")
    target_file="$SUPABASE_MIGRATIONS_DIR/$filename"
    
    # Check if file already exists and compare
    if [ -f "$target_file" ]; then
        if cmp -s "$file" "$target_file"; then
            log "  ${BLUE}SKIP${NC} $filename (identical)"
            ((SKIPPED_COUNT++))
        else
            log "  ${YELLOW}UPDATE${NC} $filename"
            cp "$file" "$target_file"
            ((SYNCED_COUNT++))
        fi
    else
        log "  ${GREEN}ADD${NC} $filename"
        cp "$file" "$target_file"
        ((SYNCED_COUNT++))
    fi
done

# Step 4: Generate sync manifest
log "\n${YELLOW}Step 4: Generating sync manifest...${NC}"
MANIFEST_FILE="$PROJECT_ROOT/supabase/migrations/.scout-sync-manifest.json"
cat > "$MANIFEST_FILE" << EOF
{
  "last_sync": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "submodule_commit": "$(cd $SCOUT_DATABANK_DIR && git rev-parse HEAD)",
  "synced_files": [
EOF

first=true
for file in "${FILES_TO_SYNC[@]}"; do
    filename=$(basename "$file")
    if [ "$first" = true ]; then
        first=false
    else
        echo "," >> "$MANIFEST_FILE"
    fi
    echo -n "    \"$filename\"" >> "$MANIFEST_FILE"
done

cat >> "$MANIFEST_FILE" << EOF

  ],
  "stats": {
    "total_files": ${#FILES_TO_SYNC[@]},
    "synced": $SYNCED_COUNT,
    "skipped": $SKIPPED_COUNT
  }
}
EOF

# Step 5: Validate migrations (optional)
if command -v supabase &> /dev/null; then
    log "\n${YELLOW}Step 5: Validating migrations...${NC}"
    cd "$PROJECT_ROOT"
    supabase db lint || log "${YELLOW}Warning: Migration validation failed${NC}"
else
    log "\n${YELLOW}Step 5: Skipping validation (Supabase CLI not found)${NC}"
fi

# Step 6: Create commit if changes were made
if [ $SYNCED_COUNT -gt 0 ]; then
    if [ "$IS_CI" = "true" ]; then
        log "\n${YELLOW}Step 6: Creating commit...${NC}"
        cd "$PROJECT_ROOT"
        git add supabase/migrations/
        git commit -m "chore: sync Scout schema migrations from scout-databank

- Synced $SYNCED_COUNT migration files
- Submodule commit: $(cd $SCOUT_DATABANK_DIR && git rev-parse --short HEAD)
- Auto-generated by scout-sync workflow" || log "${YELLOW}No changes to commit${NC}"
    else
        log "\n${YELLOW}Step 6: Changes detected but not committing (not in CI)${NC}"
        log "Run 'git add supabase/migrations/ && git commit' to commit changes"
    fi
fi

# Summary
log "\n${GREEN}=== Scout Schema Sync Complete ===${NC}"
log "Summary:"
log "  - Files examined: ${#FILES_TO_SYNC[@]}"
log "  - Files synced: $SYNCED_COUNT"
log "  - Files skipped: $SKIPPED_COUNT"
log "  - Manifest created: $MANIFEST_FILE"
log "  - Log file: $LOG_FILE"

exit 0