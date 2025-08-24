#!/bin/bash

# Scout Analytics Platform - Reprocessing Worker
# Processes queued items against the latest dictionary

set -e

# Configuration
DB_URL="${SUPABASE_DB_URL:-postgresql://postgres.cxzllzyxwpyptfretryc:YOUR_PASSWORD@aws-0-us-west-1.pooler.supabase.com:6543/postgres}"
DETECTOR_URL="${BRAND_DETECTOR_URL:-http://localhost:8000}"
BATCH_SIZE="${REPROCESS_BATCH_SIZE:-100}"
MAX_RETRIES=3

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${1}"
}

# Process a single item
process_item() {
    local entity_type=$1
    local entity_id=$2
    local text_input=""
    local transaction_id=""
    
    case $entity_type in
        "transcript")
            # Get transcript text
            text_input=$(psql "$DB_URL" -t -c "
                SELECT text_content 
                FROM bronze.transcripts 
                WHERE id = $entity_id;
            ")
            transaction_id="TRANSCRIPT-$entity_id"
            ;;
        "transaction")
            # Get transaction description
            text_input=$(psql "$DB_URL" -t -c "
                SELECT product_description 
                FROM scout_gold.fact_transactions 
                WHERE transaction_id = $entity_id;
            ")
            transaction_id="TXN-$entity_id"
            ;;
        *)
            log "${RED}Unknown entity type: $entity_type${NC}"
            return 1
            ;;
    esac
    
    # Skip if no text
    if [ -z "$text_input" ]; then
        return 1
    fi
    
    # Call detector API
    local response=$(curl -s -X POST "$DETECTOR_URL/predict" \
        -H "content-type: application/json" \
        -d "$(jq -n --arg text "$text_input" --arg txn "$transaction_id" \
            '{text: $text, transaction_id: $txn}')")
    
    # Check if successful
    if echo "$response" | jq -e '.brand' > /dev/null; then
        local predicted_brand=$(echo "$response" | jq -r '.brand')
        local confidence=$(echo "$response" | jq -r '.confidence // 0')
        
        # Link prediction to entity
        psql "$DB_URL" << EOF > /dev/null
INSERT INTO ml.link_prediction (entity_type, entity_id, prediction_id)
SELECT '$entity_type', $entity_id, prediction_id
FROM ml.prediction_events
WHERE transaction_id = '$transaction_id'
ORDER BY ts DESC
LIMIT 1
ON CONFLICT DO NOTHING;
EOF
        
        return 0
    else
        return 1
    fi
}

# Main processing loop
main() {
    log "${BLUE}🔄 Scout Reprocessing Worker Started${NC}"
    log "Configuration:"
    log "  Database: $DB_URL"
    log "  Detector: $DETECTOR_URL"
    log "  Batch Size: $BATCH_SIZE"
    log ""
    
    while true; do
        # Get batch of pending items
        BATCH=$(psql "$DB_URL" -t -A -F'|' << EOF
UPDATE scout.reprocess_queue
SET status = 'processing'
WHERE id IN (
    SELECT id 
    FROM scout.reprocess_queue 
    WHERE status = 'pending' 
    ORDER BY queued_at 
    LIMIT $BATCH_SIZE
    FOR UPDATE SKIP LOCKED
)
RETURNING id, entity_type, entity_id;
EOF
)
        
        # Check if any items to process
        if [ -z "$BATCH" ]; then
            log "${YELLOW}No items to process. Waiting...${NC}"
            sleep 30
            continue
        fi
        
        # Process each item
        PROCESSED=0
        FAILED=0
        
        echo "$BATCH" | while IFS='|' read -r queue_id entity_type entity_id; do
            [ -z "$queue_id" ] && continue
            
            log "Processing: $entity_type #$entity_id"
            
            # Try processing with retries
            RETRY=0
            SUCCESS=false
            
            while [ $RETRY -lt $MAX_RETRIES ]; do
                if process_item "$entity_type" "$entity_id"; then
                    SUCCESS=true
                    break
                fi
                RETRY=$((RETRY + 1))
                [ $RETRY -lt $MAX_RETRIES ] && sleep 2
            done
            
            # Update queue status
            if [ "$SUCCESS" = true ]; then
                psql "$DB_URL" -c "
                    UPDATE scout.reprocess_queue 
                    SET status = 'completed', processed_at = NOW() 
                    WHERE id = $queue_id;
                " > /dev/null
                PROCESSED=$((PROCESSED + 1))
                log "${GREEN}  ✅ Processed successfully${NC}"
            else
                psql "$DB_URL" -c "
                    UPDATE scout.reprocess_queue 
                    SET status = 'failed', 
                        processed_at = NOW(),
                        error_message = 'Processing failed after $MAX_RETRIES attempts' 
                    WHERE id = $queue_id;
                " > /dev/null
                FAILED=$((FAILED + 1))
                log "${RED}  ❌ Processing failed${NC}"
            fi
        done
        
        log "${BLUE}Batch complete: $PROCESSED processed, $FAILED failed${NC}"
        
        # Check if should continue
        if [ -n "$RUN_ONCE" ]; then
            break
        fi
        
        # Brief pause between batches
        sleep 5
    done
    
    log "${GREEN}🎉 Reprocessing complete${NC}"
}

# Handle signals
trap 'log "${YELLOW}Shutting down...${NC}"; exit 0' SIGTERM SIGINT

# Run main loop
main