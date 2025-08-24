#!/bin/bash

# Monitor SKU Catalog Auto-Deployment Status
# Checks GitHub Actions and Supabase deployment

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔍 Monitoring SKU Catalog Auto-Deployment${NC}"
echo "=============================================="

# 1. Check GitHub Actions status
echo -e "${BLUE}1️⃣ Checking GitHub Actions workflow...${NC}"
if command -v gh &> /dev/null; then
    echo "   Latest workflow runs:"
    gh run list --limit 3 || echo "   ⚠️  Unable to check workflow status"
else
    echo "   ⚠️  GitHub CLI not available"
    echo "   📋 Check manually: https://github.com/jgtolentino/ai-aas-hardened-lakehouse/actions"
fi

echo ""

# 2. Check if we can connect to Supabase
echo -e "${BLUE}2️⃣ Testing Supabase connection...${NC}"
if [ -f ".env.local" ]; then
    source .env.local
    
    # Test connection using psql if available
    if command -v psql &> /dev/null && [ -n "${DATABASE_URL:-}" ]; then
        echo "   Testing database connection..."
        if psql "$DATABASE_URL" -c "SELECT 'Connection successful' as status;" >/dev/null 2>&1; then
            echo -e "   ✅ Database connection successful"
        else
            echo -e "   ❌ Database connection failed"
        fi
    else
        echo "   📋 Database URL: ${SUPABASE_URL:-Not found}"
        echo "   📋 Project Ref: ${SUPABASE_PROJECT_REF:-Not found}"
    fi
else
    echo "   ⚠️  .env.local not found"
fi

echo ""

# 3. Quick verification SQL (if connection works)
echo -e "${BLUE}3️⃣ Quick deployment verification...${NC}"
cat << 'EOF'
📋 Run this SQL in Supabase dashboard to verify deployment:

```sql
-- Check if migration applied
SELECT 'SKU Catalog Migration' as check_type,
       EXISTS (
         SELECT 1 FROM information_schema.schemata 
         WHERE schema_name = 'masterdata'
       ) as deployed;

-- Check migration timestamp
SELECT filename, executed_at 
FROM supabase_migrations.schema_migrations 
WHERE filename LIKE '%sku_catalog%' 
ORDER BY executed_at DESC 
LIMIT 3;

-- Verify tables created
SELECT table_schema, table_name 
FROM information_schema.tables 
WHERE table_schema IN ('masterdata', 'staging')
AND table_name IN ('products', 'brands', 'telco_products', 'sku_catalog_upload')
ORDER BY table_schema, table_name;

-- Check if ready for import
SELECT * FROM masterdata.verify_sku_catalog_deployment();
```
EOF

echo ""

# 4. Next steps
echo -e "${BLUE}4️⃣ Next Steps:${NC}"
echo "   After successful deployment:"
echo "   1. Run: node scripts/import-sku-catalog-347.js"
echo "   2. Verify: node scripts/verify-sku-catalog.js"
echo "   3. Check Supabase dashboard for data"
echo ""

echo -e "${GREEN}🎯 Deployment Monitoring Complete!${NC}"
echo "   📊 GitHub Actions: https://github.com/jgtolentino/ai-aas-hardened-lakehouse/actions"
echo "   🗄️  Supabase SQL: https://app.supabase.com/project/cxzllzyxwpyptfretryc/sql/new"
echo "   📈 Dashboard: https://app.supabase.com/project/cxzllzyxwpyptfretryc"

exit 0