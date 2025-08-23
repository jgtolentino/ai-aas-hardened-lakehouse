#!/bin/bash
# Deploy Agentic Analytics to Supabase
# This script deploys all migrations and imports data

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Source environment variables
if [ -f /Users/tbwa/.env ]; then
    export $(cat /Users/tbwa/.env | grep -v '^#' | xargs)
fi

# Build database URL
DATABASE_URL="postgresql://postgres.cxzllzyxwpyptfretryc:${SUPABASE_SERVICE_ROLE_KEY}@aws-0-us-west-1.pooler.supabase.com:6543/postgres"

echo -e "${GREEN}🚀 Starting Agentic Analytics Deployment${NC}"
echo "Target: $SUPABASE_URL"

# Function to run SQL file
run_sql_file() {
    local file=$1
    local desc=$2
    echo -e "\n${YELLOW}📄 Running: $desc${NC}"
    if psql "$DATABASE_URL" -f "$file" -v ON_ERROR_STOP=1; then
        echo -e "${GREEN}✓ Success: $desc${NC}"
    else
        echo -e "${RED}✗ Failed: $desc${NC}"
        exit 1
    fi
}

# Deploy migrations in order
echo -e "\n${GREEN}📋 Step 1: Deploying Database Migrations${NC}"

run_sql_file "supabase/migrations/20250823_agentic_analytics.sql" "Core Agentic Analytics Infrastructure"
run_sql_file "supabase/migrations/20250823_isko_ops.sql" "Isko Operations and Agent Feed"
run_sql_file "supabase/migrations/20250823_brands_products.sql" "Brands and Products Catalog"
run_sql_file "supabase/migrations/20250823_products_autogen.sql" "Product Auto-generation Functions"
run_sql_file "supabase/migrations/20250823_import_sku_catalog.sql" "CSV Import Infrastructure"

# Verify deployment
echo -e "\n${GREEN}📋 Step 2: Verifying Deployment${NC}"

cat > /tmp/verify_deployment.sql << 'EOF'
-- Check schemas
SELECT 'Schemas' as check_type, COUNT(*) as count
FROM information_schema.schemata 
WHERE schema_name IN ('scout', 'deep_research', 'masterdata', 'staging');

-- Check core tables
SELECT 'Tables' as check_type, COUNT(*) as count
FROM information_schema.tables 
WHERE table_schema IN ('scout', 'deep_research', 'masterdata', 'staging')
  AND table_type = 'BASE TABLE';

-- Check monitors
SELECT 'Monitors' as check_type, COUNT(*) as count 
FROM scout.platinum_monitors;

-- Check brands
SELECT 'Brands' as check_type, COUNT(*) as count 
FROM masterdata.brands;

-- Check functions
SELECT 'Functions' as check_type, COUNT(*) as count
FROM information_schema.routines 
WHERE routine_schema IN ('scout', 'deep_research', 'masterdata')
  AND routine_type = 'FUNCTION';
EOF

psql "$DATABASE_URL" -f /tmp/verify_deployment.sql

# Import CSV data
echo -e "\n${GREEN}📋 Step 3: Importing SKU Catalog Data${NC}"

# Check if CSV file exists
CSV_FILE="/Users/tbwa/Downloads/sku_catalog_with_telco_filled.csv"
if [ -f "$CSV_FILE" ]; then
    echo "Found CSV file: $CSV_FILE"
    
    # Create import script
    cat > /tmp/import_sku_data.sql << 'EOF'
-- Import SKU catalog data
TRUNCATE staging.sku_catalog_upload;

-- Note: Use Supabase Dashboard to import CSV, then run:
SELECT * FROM masterdata.import_sku_catalog();

-- Show import results
SELECT 
    'Import Summary' as report,
    COUNT(*) as products_imported,
    COUNT(DISTINCT brand_name) as unique_brands
FROM masterdata.products p
JOIN masterdata.brands b ON p.brand_id = b.id
WHERE p.created_at > now() - interval '5 minutes';
EOF

    echo -e "${YELLOW}⚠️  Manual Step Required:${NC}"
    echo "1. Go to: https://supabase.com/dashboard/project/cxzllzyxwpyptfretryc/editor"
    echo "2. Navigate to Table Editor → staging.sku_catalog_upload"
    echo "3. Click 'Import data from CSV'"
    echo "4. Upload: $CSV_FILE"
    echo "5. After upload, run in SQL Editor:"
    echo "   SELECT * FROM masterdata.import_sku_catalog();"
else
    echo -e "${YELLOW}⚠️  CSV file not found at: $CSV_FILE${NC}"
fi

# Deploy Edge Function
echo -e "\n${GREEN}📋 Step 4: Deploying Edge Function${NC}"

if command -v supabase &> /dev/null; then
    echo "Deploying agentic-cron function..."
    cd "$(dirname "$0")"
    supabase functions deploy agentic-cron --no-verify-jwt
    echo -e "${GREEN}✓ Edge function deployed${NC}"
else
    echo -e "${YELLOW}⚠️  Supabase CLI not found. Please install it to deploy Edge Functions.${NC}"
fi

# Final summary
echo -e "\n${GREEN}🎉 Deployment Summary${NC}"
echo "✓ Database migrations applied"
echo "✓ Core tables and functions created"
echo "✓ Monitors and contracts initialized"
echo "⏳ CSV import pending (manual step)"
echo "✓ Edge function ready for deployment"

echo -e "\n${GREEN}📋 Next Steps:${NC}"
echo "1. Import CSV data via Supabase Dashboard"
echo "2. Schedule Edge Function: supabase functions deploy agentic-cron --schedule '*/15 * * * *'"
echo "3. Start Isko worker: deno run -A workers/isko-worker/index.ts"
echo "4. Connect GenieView UI to Agent Feed"

echo -e "\n${GREEN}📊 Quick Test:${NC}"
echo "Run: psql \"$DATABASE_URL\" -c \"SELECT scout.run_monitors();\""