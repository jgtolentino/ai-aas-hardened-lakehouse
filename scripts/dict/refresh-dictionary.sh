#!/bin/bash

# Scout Analytics Platform - Dictionary Refresh Pipeline
# Automatically generates and deploys brand dictionary from catalog

set -e

# Configuration
DB_URL="${SUPABASE_DB_URL:-postgresql://postgres.cxzllzyxwpyptfretryc:YOUR_PASSWORD@aws-0-us-west-1.pooler.supabase.com:6543/postgres}"
DETECTOR_URL="${BRAND_DETECTOR_URL:-http://localhost:8000}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DICT_DIR="./dictionary-builds"
DICT_FILE="$DICT_DIR/brand-dictionary-${TIMESTAMP}.json"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() {
    echo -e "${1}"
}

# Create build directory
mkdir -p "$DICT_DIR"

log "${BLUE}🔄 Scout Dictionary Refresh Pipeline${NC}"
log "====================================="
log "Timestamp: $(date)"
log ""

# Step 1: Consolidate brands from all sources
log "${YELLOW}1️⃣ Consolidating brand catalog...${NC}"
psql "$DB_URL" -c "SELECT scout.consolidate_brands();" > /dev/null
log "${GREEN}  ✅ Brand consolidation complete${NC}"

# Step 2: Cluster unknowns
log "${YELLOW}2️⃣ Clustering unknown brands...${NC}"
psql "$DB_URL" -c "SELECT scout.cluster_unknowns();" > /dev/null
UNKNOWN_COUNT=$(psql "$DB_URL" -t -c "SELECT COUNT(*) FROM scout.unknown_clusters WHERE status = 'pending' AND occurrence_count >= 10;")
log "${GREEN}  ✅ Found $UNKNOWN_COUNT high-volume unknowns${NC}"

# Step 3: Auto-promote brands with consensus
log "${YELLOW}3️⃣ Auto-promoting brands with consensus...${NC}"
psql "$DB_URL" -c "SELECT scout.auto_promote_brands();" > /dev/null
log "${GREEN}  ✅ Auto-promotion complete${NC}"

# Step 4: Generate dictionary JSON
log "${YELLOW}4️⃣ Generating dictionary from catalog...${NC}"
psql "$DB_URL" -t -c "SELECT scout.generate_dictionary_json();" | jq . > "$DICT_FILE"

# Get dictionary stats
BRAND_COUNT=$(jq '.brands | length' "$DICT_FILE")
VERSION=$(jq -r '.version' "$DICT_FILE")

log "${GREEN}  ✅ Dictionary generated:${NC}"
log "     Version: $VERSION"
log "     Brands: $BRAND_COUNT"
log "     File: $DICT_FILE"

# Step 5: Deploy to detector (if URL provided)
if [ "$DETECTOR_URL" != "http://localhost:8000" ]; then
    log "${YELLOW}5️⃣ Deploying dictionary to detector...${NC}"
    
    RESPONSE=$(curl -s -X POST "$DETECTOR_URL/dictionary/upsert" \
        -H "content-type: application/json" \
        -d @"$DICT_FILE")
    
    if echo "$RESPONSE" | jq -e '.success' > /dev/null; then
        log "${GREEN}  ✅ Dictionary deployed successfully${NC}"
        
        # Mark version as active
        psql "$DB_URL" << EOF > /dev/null
UPDATE scout.dictionary_versions SET is_active = FALSE WHERE is_active = TRUE;
UPDATE scout.dictionary_versions SET is_active = TRUE, deployed_at = NOW() 
WHERE version_hash = MD5('$(cat "$DICT_FILE")');
EOF
    else
        log "${RED}  ❌ Dictionary deployment failed${NC}"
        echo "$RESPONSE" | jq .
        exit 1
    fi
else
    log "${YELLOW}  ⚠️  Skipping deployment (no detector URL)${NC}"
fi

# Step 6: Check coverage metrics
log "${YELLOW}6️⃣ Checking coverage metrics...${NC}"
COVERAGE=$(psql "$DB_URL" -t -c "
SELECT 
    ROUND(AVG(brand_coverage) * 100, 2) 
FROM dq.v_brand_coverage 
WHERE day >= CURRENT_DATE - INTERVAL '3 days';
")

log "  📊 Brand coverage (3-day avg): ${COVERAGE}%"

if (( $(echo "$COVERAGE < 70" | bc -l) )); then
    log "${RED}  ❌ WARNING: Brand coverage below 70% threshold${NC}"
else
    log "${GREEN}  ✅ Brand coverage meets threshold${NC}"
fi

# Step 7: Queue reprocessing (optional)
if [ "$1" == "--reprocess" ]; then
    log "${YELLOW}7️⃣ Queuing items for reprocessing...${NC}"
    psql "$DB_URL" -c "SELECT scout.queue_reprocessing(7);" > /dev/null
    QUEUE_SIZE=$(psql "$DB_URL" -t -c "SELECT COUNT(*) FROM scout.reprocess_queue WHERE status = 'pending';")
    log "${GREEN}  ✅ Queued $QUEUE_SIZE items for reprocessing${NC}"
fi

# Summary
log ""
log "${GREEN}🎉 Dictionary refresh complete!${NC}"
log ""
log "Next steps:"
log "  - Review unknowns: SELECT * FROM scout.unknown_clusters WHERE status = 'pending' ORDER BY occurrence_count DESC;"
log "  - Add aliases: INSERT INTO scout.brand_aliases (brand_id, alias) VALUES (?, ?);"
log "  - Monitor coverage: SELECT * FROM dq.v_coverage_summary ORDER BY day DESC;"

# Keep last 10 dictionary versions
log ""
log "Cleaning old dictionary files..."
ls -t "$DICT_DIR"/brand-dictionary-*.json 2>/dev/null | tail -n +11 | xargs -r rm
log "Done!"