#!/bin/bash
# ============================================================
# Scout v5.2 - Compute Migration SHA256 Hashes
# Generates hashes for all SQL migration files for manifest.yaml
# ============================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}Scout v5.2 - Migration Hash Calculator${NC}"
echo -e "${BLUE}============================================================${NC}"

# Base directory (relative to script location)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Migration directories
MIGRATION_DIRS=(
    "platform/scout/migrations"
    "supabase/migrations"
)

# Output file
OUTPUT_FILE="${BASE_DIR}/migrations/migration_hashes.txt"
MANIFEST_UPDATE="${BASE_DIR}/migrations/manifest_update.yaml"

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Clear output files
> "$OUTPUT_FILE"
> "$MANIFEST_UPDATE"

echo -e "\n${YELLOW}Scanning for migration files...${NC}"

# Function to compute hash
compute_hash() {
    local file="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        shasum -a 256 "$file" | cut -d' ' -f1
    else
        # Linux
        sha256sum "$file" | cut -d' ' -f1
    fi
}

# Track total files
total_files=0
missing_files=0

# Process each migration directory
for dir in "${MIGRATION_DIRS[@]}"; do
    full_dir="${BASE_DIR}/${dir}"
    
    if [[ -d "$full_dir" ]]; then
        echo -e "\n${GREEN}Processing: ${dir}${NC}"
        
        # Find all SQL files
        while IFS= read -r -d '' file; do
            # Get relative path from base directory
            rel_path="${file#$BASE_DIR/}"
            filename=$(basename "$file")
            
            # Compute hash
            hash=$(compute_hash "$file")
            
            # Output to file
            echo "${filename}|${rel_path}|${hash}" >> "$OUTPUT_FILE"
            
            # Also create YAML snippet for manifest update
            cat >> "$MANIFEST_UPDATE" << EOF
  - file: "${filename}"
    path: "${rel_path}"
    sha256: "${hash}"
    description: "Auto-generated from file"
    applied: false
    applied_at: null
    
EOF
            
            echo -e "  ✓ ${filename}: ${GREEN}${hash:0:16}...${NC}"
            ((total_files++))
        done < <(find "$full_dir" -name "*.sql" -type f -print0 | sort -z)
    else
        echo -e "${YELLOW}Warning: Directory not found: ${dir}${NC}"
    fi
done

# Check for migrations referenced in manifest but not found
echo -e "\n${YELLOW}Checking manifest for missing files...${NC}"

# Expected migrations from manifest
declare -a expected_migrations=(
    "001_scout_enums_dims.sql"
    "002_scout_bronze_silver.sql"
    "003_scout_gold_views.sql"
    "010_geo_boundaries.sql"
    "026_edge_device_monitoring.sql"
    "027_stt_brand_detection.sql"
    "028_standardize_naming.sql"
    "029_silver_line_items.sql"
)

for expected in "${expected_migrations[@]}"; do
    if ! grep -q "^${expected}|" "$OUTPUT_FILE"; then
        echo -e "  ${RED}✗ Missing: ${expected}${NC}"
        ((missing_files++))
    fi
done

# Generate summary
echo -e "\n${BLUE}============================================================${NC}"
echo -e "${BLUE}Summary:${NC}"
echo -e "  Total SQL files found: ${GREEN}${total_files}${NC}"
echo -e "  Missing expected files: ${RED}${missing_files}${NC}"
echo -e "  Hash file: ${OUTPUT_FILE}"
echo -e "  Manifest update: ${MANIFEST_UPDATE}"

# Create a formatted output for easy copying
echo -e "\n${YELLOW}Migration hashes for manifest.yaml:${NC}"
echo -e "${BLUE}------------------------------------------------------------${NC}"

while IFS='|' read -r filename filepath hash; do
    # Find the manifest entry format
    echo -e "${GREEN}${filename}${NC}: ${hash}"
done < "$OUTPUT_FILE"

# Create Python script for updating manifest
cat > "${BASE_DIR}/scripts/update_manifest_hashes.py" << 'EOF'
#!/usr/bin/env python3
"""Update manifest.yaml with computed hashes"""

import yaml
import sys
from pathlib import Path

def update_manifest(hash_file, manifest_file):
    # Read hashes
    hashes = {}
    with open(hash_file, 'r') as f:
        for line in f:
            if line.strip():
                filename, filepath, hash_value = line.strip().split('|')
                hashes[filename] = {
                    'path': filepath,
                    'hash': hash_value
                }
    
    # Read manifest
    with open(manifest_file, 'r') as f:
        manifest = yaml.safe_load(f)
    
    # Update hashes
    updated = 0
    for migration in manifest.get('migrations', []):
        filename = migration.get('file')
        if filename in hashes:
            migration['sha256'] = hashes[filename]['hash']
            if migration['sha256'] == 'pending_calculation':
                updated += 1
    
    # Write updated manifest
    with open(manifest_file, 'w') as f:
        yaml.dump(manifest, f, default_flow_style=False, sort_keys=False)
    
    print(f"Updated {updated} migration hashes in manifest")

if __name__ == "__main__":
    script_dir = Path(__file__).parent
    base_dir = script_dir.parent
    
    hash_file = base_dir / "migrations" / "migration_hashes.txt"
    manifest_file = base_dir / "migrations" / "manifest.yaml"
    
    if hash_file.exists() and manifest_file.exists():
        update_manifest(hash_file, manifest_file)
    else:
        print("Error: Required files not found")
        sys.exit(1)
EOF

chmod +x "${BASE_DIR}/scripts/update_manifest_hashes.py"

echo -e "\n${GREEN}✨ Hash computation complete!${NC}"
echo -e "\nTo update manifest.yaml with these hashes, run:"
echo -e "  ${BLUE}python3 scripts/update_manifest_hashes.py${NC}"

# Check if we should auto-update
if [[ "${1:-}" == "--update-manifest" ]]; then
    echo -e "\n${YELLOW}Auto-updating manifest.yaml...${NC}"
    cd "$BASE_DIR"
    python3 scripts/update_manifest_hashes.py
fi