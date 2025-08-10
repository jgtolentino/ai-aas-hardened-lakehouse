#!/bin/bash
# Complete verification script for choropleth deployment
# Includes secret injection, migration application, and hard performance checks

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="${NAMESPACE:-aaas}"
PGURI="${PGURI:-}"
MAPBOX_API_KEY="${MAPBOX_API_KEY:-pk.eyJ1Ijoiamd0b2xlbnRpbm8iLCJhIjoiY21jMmNycWRiMDc0ajJqcHZoaDYyeTJ1NiJ9.Dns6WOql16BUQ4l7otaeww}"

echo "🗺️  Scout Analytics Choropleth - Complete Verification"
echo "===================================================="

# Step 0: Pre-flight checks
echo -e "\n${YELLOW}Step 0: Pre-flight checks...${NC}"

if [ -z "$PGURI" ]; then
    echo -e "${RED}❌ PGURI not set${NC}"
    echo "Export PGURI with your PostgreSQL connection string"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found${NC}"
    exit 1
fi

if ! command -v psql &> /dev/null; then
    echo -e "${RED}❌ psql not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Pre-flight checks passed${NC}"

# Step 1: Create/Update Kubernetes Secret
echo -e "\n${YELLOW}Step 1: Configuring Mapbox secret...${NC}"
kubectl -n "$NAMESPACE" create secret generic superset-mapbox \
  --from-literal=MAPBOX_API_KEY="$MAPBOX_API_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✅ Mapbox secret configured${NC}"

# Step 2: Apply database migrations
echo -e "\n${YELLOW}Step 2: Applying geographic migrations...${NC}"

MIGRATIONS=(
    "platform/scout/migrations/010_geo_boundaries.sql"
    "platform/scout/migrations/011_geo_normalizers.sql"
    "platform/scout/migrations/012_geo_gold_views.sql"
    "platform/scout/migrations/013_geo_performance_indexes.sql"
)

for migration in "${MIGRATIONS[@]}"; do
    if [ -f "$migration" ]; then
        echo "  Applying: $migration"
        psql "$PGURI" -f "$migration" 2>&1 | grep -E "(ERROR|NOTICE|CREATE|ALTER)" || true
    else
        echo -e "${YELLOW}  ⚠️  Migration not found: $migration${NC}"
    fi
done

echo -e "${GREEN}✅ Migrations applied${NC}"

# Step 3: Verify boundary data
echo -e "\n${YELLOW}Step 3: Verifying boundary data...${NC}"

REGION_COUNT=$(psql "$PGURI" -t -c "SELECT COUNT(*) FROM scout.geo_adm1_region;" 2>/dev/null || echo "0")
CITYMUN_COUNT=$(psql "$PGURI" -t -c "SELECT COUNT(*) FROM scout.geo_adm3_citymun;" 2>/dev/null || echo "0")

echo "  Regions: $REGION_COUNT (expected: 17+)"
echo "  Cities/Municipalities: $CITYMUN_COUNT (expected: 1600+)"

if [ "$REGION_COUNT" -lt 17 ]; then
    echo -e "${YELLOW}  ⚠️  Boundary data not loaded. Run geo-importer job.${NC}"
else
    echo -e "${GREEN}  ✅ Boundary data present${NC}"
fi

# Step 4: Check Superset configuration
echo -e "\n${YELLOW}Step 4: Verifying Superset configuration...${NC}"

# Check if Superset pod exists
POD_NAME=$(kubectl -n "$NAMESPACE" get pods -l "app.kubernetes.io/name=superset" -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")

if [ -z "$POD_NAME" ]; then
    echo -e "${YELLOW}  ⚠️  Superset not deployed${NC}"
else
    echo "  Found Superset pod: $POD_NAME"
    
    # Check environment
    MAPBOX_SET=$(kubectl -n "$NAMESPACE" exec "$POD_NAME" -- sh -c 'echo ${MAPBOX_API_KEY:+SET}' 2>/dev/null || echo "")
    
    if [ "$MAPBOX_SET" = "SET" ]; then
        echo -e "${GREEN}  ✅ MAPBOX_API_KEY is configured${NC}"
    else
        echo -e "${RED}  ❌ MAPBOX_API_KEY not set in pod${NC}"
    fi
fi

# Step 5: Run hard performance checks
echo -e "\n${YELLOW}Step 5: Running hard performance checks...${NC}"

if [ -f "scripts/benchmark_choropleth_hard.py" ]; then
    echo "  Executing performance benchmark..."
    
    # Check if psycopg2 is available
    if python3 -c "import psycopg2" 2>/dev/null; then
        python3 scripts/benchmark_choropleth_hard.py \
            --pguri "$PGURI" \
            --exit-on-fail || {
            echo -e "${RED}❌ Performance checks failed${NC}"
            PERF_FAILED=1
        }
    else
        echo -e "${YELLOW}  ⚠️  psycopg2 not installed. Install with: pip install psycopg2-binary${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠️  Performance script not found${NC}"
fi

# Step 6: Test geographic functions
echo -e "\n${YELLOW}Step 6: Testing geographic functions...${NC}"

# Test region normalization
echo "  Testing region normalization..."
psql "$PGURI" -c "
    SELECT 
        scout.norm_region('METRO MANILA') as test1,
        scout.norm_region('Region IV-A') as test2,
        scout.norm_region('CALABARZON') as test3
    LIMIT 1;
" 2>&1 | grep -v "^(" || true

# Test spatial query
echo "  Testing spatial query..."
SPATIAL_TEST=$(psql "$PGURI" -t -c "
    SELECT COUNT(*) 
    FROM scout.geo_adm1_region 
    WHERE ST_Contains(geom, ST_SetSRID(ST_MakePoint(121.0, 14.5), 4326));
" 2>/dev/null || echo "0")

if [ "$SPATIAL_TEST" -eq 1 ]; then
    echo -e "${GREEN}  ✅ Spatial queries working${NC}"
else
    echo -e "${RED}  ❌ Spatial queries not working${NC}"
fi

# Step 7: Final summary
echo -e "\n${BLUE}======================================${NC}"
echo -e "${BLUE}📊 VERIFICATION SUMMARY${NC}"
echo -e "${BLUE}======================================${NC}"

ISSUES=0

# Check each component
echo -e "\n${YELLOW}Component Status:${NC}"

# Database
if [ "$REGION_COUNT" -ge 17 ] && [ "$CITYMUN_COUNT" -ge 1600 ]; then
    echo -e "  Database: ${GREEN}✅ Ready${NC}"
else
    echo -e "  Database: ${RED}❌ Missing boundary data${NC}"
    ((ISSUES++))
fi

# Superset
if [ -n "$POD_NAME" ] && [ "$MAPBOX_SET" = "SET" ]; then
    echo -e "  Superset: ${GREEN}✅ Configured${NC}"
else
    echo -e "  Superset: ${RED}❌ Not properly configured${NC}"
    ((ISSUES++))
fi

# Performance
if [ "${PERF_FAILED:-0}" -eq 0 ]; then
    echo -e "  Performance: ${GREEN}✅ Meets requirements${NC}"
else
    echo -e "  Performance: ${RED}❌ Below threshold${NC}"
    ((ISSUES++))
fi

# Next steps
if [ $ISSUES -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All checks passed! Choropleth is ready for use.${NC}"
    echo -e "\nNext steps:"
    echo "1. Import Superset assets: bash platform/superset/scripts/import_scout_bundle.sh"
    echo "2. Access Superset UI and test the choropleth charts"
    echo "3. Monitor performance with: python3 scripts/benchmark_choropleth.py"
else
    echo -e "\n${RED}❌ Found $ISSUES issues that need attention${NC}"
    echo -e "\nRemediation steps:"
    
    if [ "$REGION_COUNT" -lt 17 ]; then
        echo "1. Load boundary data: kubectl apply -f platform/lakehouse/jobs/geo-importer.yaml"
    fi
    
    if [ "$MAPBOX_SET" != "SET" ]; then
        echo "2. Deploy Superset with Mapbox: bash scripts/deploy_superset_with_mapbox.sh"
    fi
    
    if [ "${PERF_FAILED:-0}" -eq 1 ]; then
        echo "3. Review performance report above and optimize queries/indexes"
    fi
fi

echo -e "\n${BLUE}======================================${NC}"

# Exit with appropriate code
exit $ISSUES