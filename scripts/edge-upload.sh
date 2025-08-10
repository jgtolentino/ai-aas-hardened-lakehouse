#!/bin/bash
# ============================================================================
# Edge Device Dataset Upload Script
# For Raspberry Pi 5 and other edge devices
# ============================================================================
set -euo pipefail

# Load environment variables
if [ -f ".env" ]; then
    export $(cat .env | xargs)
fi

# Check required variables
if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_STORAGE_TOKEN:-}" ]; then
    echo "❌ Error: Missing environment variables"
    echo "Create .env file with:"
    echo "  SUPABASE_URL=https://your-project.supabase.co"
    echo "  SUPABASE_STORAGE_TOKEN=your-token-here"
    exit 1
fi

# Configuration
DATASET_DIR="${1:-/home/pi/datasets}"
BUCKET="sample"
BASE_PATH="scout/v1"

echo "📦 Edge Device Upload Script"
echo "═══════════════════════════════════════"
echo "URL: $SUPABASE_URL"
echo "Directory: $DATASET_DIR"
echo ""

# Function to upload file
upload_file() {
    local file="$1"
    local storage_path="$2"
    
    echo "⬆️  Uploading: $(basename "$file") → $storage_path"
    
    response=$(curl -s -w "\n%{http_code}" -X POST \
        "${SUPABASE_URL}/storage/v1/object/${BUCKET}/${storage_path}" \
        -H "Authorization: Bearer ${SUPABASE_STORAGE_TOKEN}" \
        -H "Content-Type: application/octet-stream" \
        --data-binary "@${file}")
    
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        echo "✅ Success: $(basename "$file")"
        return 0
    else
        echo "❌ Failed: $(basename "$file") (HTTP $http_code)"
        return 1
    fi
}

# Upload datasets by tier
upload_count=0
fail_count=0

for tier in bronze silver gold platinum; do
    tier_dir="${DATASET_DIR}/${tier}"
    
    if [ -d "$tier_dir" ]; then
        echo ""
        echo "📊 Processing $tier tier..."
        
        for file in "$tier_dir"/*.{csv,parquet,json} 2>/dev/null; do
            if [ -f "$file" ]; then
                filename=$(basename "$file")
                storage_path="${BASE_PATH}/${tier}/${filename}"
                
                if upload_file "$file" "$storage_path"; then
                    ((upload_count++))
                else
                    ((fail_count++))
                fi
            fi
        done
    fi
done

# Create and upload manifest
echo ""
echo "📝 Creating manifest..."

manifest_file="/tmp/manifest_$(date +%s).json"
cat > "$manifest_file" <<EOF
{
    "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "device_id": "$(hostname)",
    "datasets": {
        "bronze": $(find "${DATASET_DIR}/bronze" -name "*.csv" -o -name "*.parquet" 2>/dev/null | wc -l),
        "silver": $(find "${DATASET_DIR}/silver" -name "*.csv" -o -name "*.parquet" 2>/dev/null | wc -l),
        "gold": $(find "${DATASET_DIR}/gold" -name "*.csv" -o -name "*.parquet" 2>/dev/null | wc -l),
        "platinum": $(find "${DATASET_DIR}/platinum" -name "*.csv" -o -name "*.parquet" 2>/dev/null | wc -l)
    },
    "upload_stats": {
        "successful": $upload_count,
        "failed": $fail_count
    }
}
EOF

upload_file "$manifest_file" "${BASE_PATH}/manifests/latest.json"
rm "$manifest_file"

echo ""
echo "═══════════════════════════════════════"
echo "📊 Upload Complete!"
echo "✅ Successful: $upload_count files"
if [ $fail_count -gt 0 ]; then
    echo "❌ Failed: $fail_count files"
fi
echo "═══════════════════════════════════════"
