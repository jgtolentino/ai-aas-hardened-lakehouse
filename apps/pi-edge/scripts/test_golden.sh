#!/bin/bash

# Test golden fixture against local validation
echo "Testing golden fixture validation..."

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "jq is required but not installed. Please install jq."
    exit 1
fi

# Validate JSON structure
if jq empty fixtures/golden.json 2>/dev/null; then
    echo "✓ JSON is valid"
else
    echo "✗ JSON is invalid"
    exit 1
fi

# Check required fields
REQUIRED_FIELDS=("transaction_id" "store" "geo" "ts_utc" "tx_start_ts" "tx_end_ts" "request" "items")
for field in "${REQUIRED_FIELDS[@]}"; do
    if jq -e ".$field" fixtures/golden.json > /dev/null 2>&1; then
        echo "✓ Field '$field' exists"
    else
        echo "✗ Field '$field' missing"
        exit 1
    fi
done

# Check items array
ITEM_COUNT=$(jq '.items | length' fixtures/golden.json)
if [ "$ITEM_COUNT" -gt 0 ]; then
    echo "✓ Items array has $ITEM_COUNT items"
else
    echo "✗ Items array is empty"
    exit 1
fi

# Check confidence scores
MIN_CONFIDENCE=$(jq '[.items[].confidence] | min' fixtures/golden.json)
MAX_CONFIDENCE=$(jq '[.items[].confidence] | max' fixtures/golden.json)
echo "✓ Confidence range: $MIN_CONFIDENCE - $MAX_CONFIDENCE"

# Check enums
REQUEST_TYPE=$(jq -r '.request.request_type' fixtures/golden.json)
if [[ "$REQUEST_TYPE" =~ ^(branded|unbranded|point|indirect)$ ]]; then
    echo "✓ request_type '$REQUEST_TYPE' is valid"
else
    echo "✗ Invalid request_type: $REQUEST_TYPE"
    exit 1
fi

echo ""
echo "Golden fixture validation passed!"