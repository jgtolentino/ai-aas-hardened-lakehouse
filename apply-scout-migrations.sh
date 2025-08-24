#!/bin/bash
# Apply Scout v5.2 Migrations (026-032)

set -e

echo "🚀 Applying Scout v5.2 Migrations"
echo "================================="

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check for required environment variables
if [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}❌ Error: DB_PASSWORD environment variable not set${NC}"
    echo "Please run: source ~/.scout_env"
    exit 1
fi

# Database connection - using pooler URL
DB_URL="postgresql://postgres:${DB_PASSWORD}@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres?options=project%3Dcxzllzyxwpyptfretryc"

# List of migrations to apply
MIGRATIONS=(
    "026_edge_device_schema.sql"
    "027_stt_detection_schema.sql"
    "028_standardize_dim_names.sql"
    "029_silver_line_items.sql"
    "030_competitive_geo_intelligence.sql"
    "031_fact_substitutions_table.sql"
    "032_store_clustering.sql"
)

# Apply each migration
for migration in "${MIGRATIONS[@]}"; do
    echo -e "\n${YELLOW}📄 Applying migration: $migration${NC}"
    
    if psql "$DB_URL" -v ON_ERROR_STOP=1 -f "platform/scout/migrations/$migration"; then
        echo -e "${GREEN}✅ Successfully applied: $migration${NC}"
    else
        echo -e "${RED}❌ Failed to apply: $migration${NC}"
        exit 1
    fi
done

# Run health checks
echo -e "\n${YELLOW}🏥 Running health checks...${NC}"

# Check edge devices
echo -e "\n1️⃣ Edge devices status:"
psql "$DB_URL" -c "SELECT COUNT(*) as edge_devices FROM scout.edge_health;"

# Check STT detections
echo -e "\n2️⃣ STT detection tables:"
psql "$DB_URL" -c "SELECT COUNT(*) as stt_triggers FROM scout.stt_brand_triggers;"

# Check competitive intelligence views
echo -e "\n3️⃣ Competitive intelligence:"
psql "$DB_URL" -c "SELECT COUNT(*) as brands FROM scout.gold_brand_competitive_30d LIMIT 1;"

# Check substitutions
echo -e "\n4️⃣ Substitutions table:"
psql "$DB_URL" -c "SELECT COUNT(*) as substitutions FROM scout.fact_substitutions;"

# Check store clustering
echo -e "\n5️⃣ Store clustering:"
psql "$DB_URL" -c "SELECT COUNT(DISTINCT cluster_id) as clusters FROM scout.store_clusters;"

echo -e "\n${GREEN}✅ All Scout v5.2 migrations applied successfully!${NC}"
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "1. Verify the dashboard at your deployment URL"
echo "2. Check that all views are accessible"
echo "3. Test edge device connectivity"
echo "4. Confirm STT detection is working"