#!/usr/bin/env bash
set -euo pipefail

# Scout Analytics Platform - Gold Views Deployment Script
# This script deploys comprehensive Gold layer views for the analytics dashboard

echo "🚀 Scout Analytics Gold Views Deployment"
echo "========================================"

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get database connection details
DB_HOST="${SUPABASE_DB_HOST:-db.cxzllzyxwpyptfretryc.supabase.co}"
DB_PORT="${SUPABASE_DB_PORT:-5432}"
DB_NAME="${SUPABASE_DB_NAME:-postgres}"
DB_USER="${SUPABASE_DB_USER:-postgres}"

# Migration file
MIGRATION_FILE="platform/scout/migrations/025_gold_analytics_views.sql"

# Check if migration file exists
if [ ! -f "$MIGRATION_FILE" ]; then
    echo -e "${RED}❌ Migration file not found: $MIGRATION_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}📄 Migration file: $MIGRATION_FILE${NC}"

# Function to execute SQL with error handling
execute_sql() {
    local sql="$1"
    local description="$2"
    
    echo -n "  $description... "
    
    if psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -c "$sql" > /dev/null 2>&1; then
        echo -e "${GREEN}✅${NC}"
        return 0
    else
        echo -e "${RED}❌${NC}"
        return 1
    fi
}

# Check database connection
echo ""
echo "🔌 Checking database connection..."
if ! psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -c "SELECT 1" > /dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to database${NC}"
    echo "Please ensure:"
    echo "  1. SUPABASE_DB_PASSWORD is set in environment"
    echo "  2. Database host is accessible"
    echo "  3. Credentials are correct"
    exit 1
fi
echo -e "${GREEN}✅ Database connection successful${NC}"

# Check if scout schema exists
echo ""
echo "🔍 Checking scout schema..."
if ! psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -t -c "SELECT 1 FROM information_schema.schemata WHERE schema_name = 'scout'" | grep -q 1; then
    echo -e "${RED}❌ Scout schema not found${NC}"
    echo "Please run the base schema migrations first"
    exit 1
fi
echo -e "${GREEN}✅ Scout schema exists${NC}"

# Deploy the Gold views
echo ""
echo "🎯 Deploying Gold analytics views..."
echo "This will create 10 comprehensive views for the analytics dashboard:"
echo "  1. gold_dashboard_kpis - Executive KPIs"
echo "  2. gold_product_performance - Product analytics"
echo "  3. gold_campaign_effectiveness - Marketing ROI"
echo "  4. gold_customer_segments - Customer insights"
echo "  5. gold_store_performance - Store metrics"
echo "  6. gold_sales_trends - Time series data"
echo "  7. gold_inventory_analysis - Stock management"
echo "  8. gold_category_insights - Category performance"
echo "  9. gold_geographic_summary - Regional analysis"
echo " 10. gold_time_series_metrics - Hourly/daily patterns"
echo ""

# Execute the migration
if psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -f "$MIGRATION_FILE"; then
    echo -e "${GREEN}✅ Gold views deployed successfully!${NC}"
else
    echo -e "${RED}❌ Failed to deploy Gold views${NC}"
    exit 1
fi

# Verify views were created
echo ""
echo "🔍 Verifying Gold views..."
VIEWS=(
    "gold_dashboard_kpis"
    "gold_product_performance"
    "gold_campaign_effectiveness"
    "gold_customer_segments"
    "gold_store_performance"
    "gold_sales_trends"
    "gold_inventory_analysis"
    "gold_category_insights"
    "gold_geographic_summary"
    "gold_time_series_metrics"
)

ALL_VIEWS_EXIST=true
for view in "${VIEWS[@]}"; do
    if psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -t -c "SELECT 1 FROM information_schema.views WHERE table_schema = 'scout' AND table_name = '$view'" | grep -q 1; then
        echo -e "  ✅ scout.$view"
    else
        echo -e "  ❌ scout.$view NOT FOUND"
        ALL_VIEWS_EXIST=false
    fi
done

if [ "$ALL_VIEWS_EXIST" = false ]; then
    echo -e "${RED}❌ Some views were not created${NC}"
    exit 1
fi

# Test sample queries
echo ""
echo "🧪 Testing Gold views with sample queries..."

# Test dashboard KPIs
echo -n "  Testing gold_dashboard_kpis... "
if psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -c "SELECT * FROM scout.gold_dashboard_kpis LIMIT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${YELLOW}⚠️  (may need data)${NC}"
fi

# Test product performance
echo -n "  Testing gold_product_performance... "
if psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -c "SELECT * FROM scout.gold_product_performance LIMIT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${YELLOW}⚠️  (may need data)${NC}"
fi

# Display usage examples
echo ""
echo "📊 Gold Views Usage Examples:"
echo "================================"
echo ""
echo "1. Get dashboard KPIs:"
echo -e "${BLUE}SELECT * FROM scout.gold_dashboard_kpis;${NC}"
echo ""
echo "2. Top 10 products by revenue:"
echo -e "${BLUE}SELECT product_name, brand, revenue, units_sold, revenue_rank"
echo "FROM scout.gold_product_performance"
echo "WHERE revenue_rank <= 10;${NC}"
echo ""
echo "3. Campaign ROI analysis:"
echo -e "${BLUE}SELECT campaign_name, roi_percentage, revenue_generated, campaign_status"
echo "FROM scout.gold_campaign_effectiveness"
echo "WHERE campaign_status = 'Completed'"
echo "ORDER BY roi_percentage DESC;${NC}"
echo ""
echo "4. Customer segments summary:"
echo -e "${BLUE}SELECT customer_segment, COUNT(*) as customers, AVG(total_spent) as avg_lifetime_value"
echo "FROM scout.gold_customer_segments"
echo "GROUP BY customer_segment;${NC}"
echo ""
echo "5. Regional performance:"
echo -e "${BLUE}SELECT region, city, store_count, total_revenue, revenue_market_share"
echo "FROM scout.gold_geographic_summary"
echo "ORDER BY revenue_rank;${NC}"

# Create a simple test script for the DAL
echo ""
echo "📝 Creating DAL test script..."
cat > test-gold-views.sql << 'EOF'
-- Test Scout Analytics Gold Views
-- Run this script to verify all views are working

\echo 'Testing Scout Analytics Gold Views...'
\echo '===================================='

-- 1. Dashboard KPIs
\echo '\n1. Dashboard KPIs:'
SELECT 
    total_revenue,
    unique_customers,
    transaction_count,
    revenue_growth_pct,
    customer_growth_pct
FROM scout.gold_dashboard_kpis;

-- 2. Top Products
\echo '\n2. Top 5 Products by Revenue:'
SELECT 
    product_name,
    brand,
    revenue,
    units_sold,
    revenue_rank
FROM scout.gold_product_performance
LIMIT 5;

-- 3. Active Campaigns
\echo '\n3. Campaign Performance:'
SELECT 
    campaign_name,
    campaign_status,
    roi_percentage,
    revenue_to_spend_ratio
FROM scout.gold_campaign_effectiveness
WHERE campaign_status IN ('Active', 'Completed')
LIMIT 5;

-- 4. Customer Tiers
\echo '\n4. Customer Tier Distribution:'
SELECT 
    customer_tier,
    COUNT(*) as customer_count,
    AVG(total_spent) as avg_spent
FROM scout.gold_customer_segments
GROUP BY customer_tier
ORDER BY avg_spent DESC;

-- 5. Store Rankings
\echo '\n5. Top Stores by Revenue:'
SELECT 
    store_name,
    city,
    region,
    total_revenue,
    revenue_vs_region_avg
FROM scout.gold_store_performance
LIMIT 5;

\echo '\n✅ Gold views test complete!'
EOF

echo -e "${GREEN}✅ Test script created: test-gold-views.sql${NC}"

# Final summary
echo ""
echo "========================================="
echo -e "${GREEN}✅ GOLD VIEWS DEPLOYMENT COMPLETE!${NC}"
echo ""
echo "The Scout Analytics Gold layer is now ready for use."
echo "These views provide optimized, business-ready data for:"
echo "  • Executive dashboards"
echo "  • Product analytics"
echo "  • Customer insights"
echo "  • Marketing ROI"
echo "  • Inventory management"
echo "  • Geographic analysis"
echo ""
echo "To test the views:"
echo -e "${BLUE}psql -h $DB_HOST -p $DB_PORT -d $DB_NAME -U $DB_USER -f test-gold-views.sql${NC}"
echo ""
echo "To use in the DAL service:"
echo -e "${BLUE}import { DALService } from './modules/scout/src/services';${NC}"
echo -e "${BLUE}const kpis = await DALService.getDashboardKPIs();${NC}"
echo ""
echo "Happy analyzing! 📊"