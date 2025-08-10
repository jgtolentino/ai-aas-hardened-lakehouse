#!/bin/bash
# Verify geographic deployment - boundaries, joins, and performance

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🌍 Scout Analytics Geographic Verification"
echo "========================================="

# Check if PGURI is set
if [ -z "${PGURI:-}" ]; then
    echo -e "${RED}❌ PGURI environment variable not set${NC}"
    echo "Please set: export PGURI='postgresql://user:pass@host:port/database'"
    exit 1
fi

echo -e "\n${YELLOW}1. Checking PostGIS extension...${NC}"
POSTGIS_VERSION=$(psql "$PGURI" -t -c "SELECT PostGIS_Version();" 2>/dev/null || echo "NOT INSTALLED")
if [[ "$POSTGIS_VERSION" == *"NOT INSTALLED"* ]]; then
    echo -e "${RED}❌ PostGIS not installed${NC}"
    exit 1
else
    echo -e "${GREEN}✅ PostGIS installed: $POSTGIS_VERSION${NC}"
fi

echo -e "\n${YELLOW}2. Checking boundary data...${NC}"
REGION_COUNT=$(psql "$PGURI" -t -c "SELECT COUNT(*) FROM scout.geo_adm1_region;" 2>/dev/null || echo "0")
PROVINCE_COUNT=$(psql "$PGURI" -t -c "SELECT COUNT(*) FROM scout.geo_adm2_province;" 2>/dev/null || echo "0")
CITYMUN_COUNT=$(psql "$PGURI" -t -c "SELECT COUNT(*) FROM scout.geo_adm3_citymun;" 2>/dev/null || echo "0")

echo "  Regions (ADM1): $REGION_COUNT"
echo "  Provinces (ADM2): $PROVINCE_COUNT"
echo "  Cities/Municipalities (ADM3): $CITYMUN_COUNT"

if [ "$REGION_COUNT" -lt 17 ] || [ "$PROVINCE_COUNT" -lt 80 ] || [ "$CITYMUN_COUNT" -lt 1600 ]; then
    echo -e "${RED}❌ Boundary data incomplete. Expected: 17+ regions, 80+ provinces, 1600+ cities/municipalities${NC}"
    echo "Run: kubectl apply -f platform/lakehouse/jobs/geo-importer.yaml"
else
    echo -e "${GREEN}✅ Boundary data loaded${NC}"
fi

echo -e "\n${YELLOW}3. Checking geometry validity...${NC}"
INVALID_COUNT=$(psql "$PGURI" -t -c "
    SELECT COUNT(*) 
    FROM scout.geo_adm3_citymun 
    WHERE NOT ST_IsValid(geom);" 2>/dev/null || echo "0")

if [ "$INVALID_COUNT" -gt 0 ]; then
    echo -e "${RED}❌ Found $INVALID_COUNT invalid geometries${NC}"
    echo "Fix with: UPDATE scout.geo_adm3_citymun SET geom = ST_MakeValid(geom) WHERE NOT ST_IsValid(geom);"
else
    echo -e "${GREEN}✅ All geometries valid${NC}"
fi

echo -e "\n${YELLOW}4. Checking simplified geometries...${NC}"
SIMPLIFIED_COUNT=$(psql "$PGURI" -t -c "SELECT COUNT(*) FROM scout.geo_adm3_citymun_gen;" 2>/dev/null || echo "0")
if [ "$SIMPLIFIED_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No simplified geometries found${NC}"
    echo "Generate with: psql \$PGURI -f platform/scout/migrations/011_geo_adm3.sql"
else
    echo -e "${GREEN}✅ Simplified geometries available: $SIMPLIFIED_COUNT${NC}"
fi

echo -e "\n${YELLOW}5. Checking GIST indexes...${NC}"
INDEX_COUNT=$(psql "$PGURI" -t -c "
    SELECT COUNT(*) 
    FROM pg_indexes 
    WHERE schemaname = 'scout' 
    AND tablename LIKE 'geo_%' 
    AND indexdef LIKE '%USING gist%';" 2>/dev/null || echo "0")

if [ "$INDEX_COUNT" -lt 6 ]; then
    echo -e "${RED}❌ Missing GIST indexes (found $INDEX_COUNT, expected 6+)${NC}"
    echo "Create with: psql \$PGURI -f platform/scout/migrations/013_geo_performance_indexes.sql"
else
    echo -e "${GREEN}✅ GIST indexes present: $INDEX_COUNT${NC}"
fi

echo -e "\n${YELLOW}6. Testing join coverage (ADM3)...${NC}"
psql "$PGURI" -c "
WITH m AS (SELECT DISTINCT citymun_psgc FROM scout.gold_citymun_daily WHERE citymun_psgc IS NOT NULL),
     g AS (SELECT citymun_psgc FROM scout.geo_adm3_citymun)
SELECT
  'Metrics cities' as type,
  (SELECT COUNT(*) FROM m) as total,
  (SELECT COUNT(*) FROM m WHERE citymun_psgc IN (SELECT citymun_psgc FROM g)) as matched,
  (SELECT COUNT(*) FROM m WHERE citymun_psgc NOT IN (SELECT citymun_psgc FROM g)) as unmatched;"

echo -e "\n${YELLOW}7. Testing join coverage (ADM1)...${NC}"
psql "$PGURI" -c "
SELECT 
  'Unmatched regions' as issue,
  COUNT(*) as count,
  STRING_AGG(DISTINCT region_key, ', ') as examples
FROM scout.gold_region_daily
WHERE region_key NOT IN (SELECT region_key FROM scout.geo_adm1_region)
HAVING COUNT(*) > 0;"

echo -e "\n${YELLOW}8. Performance test - Region choropleth query...${NC}"
START_TIME=$(date +%s.%N)
psql "$PGURI" -c "
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT 
    region_key,
    region_name,
    ST_AsGeoJSON(geom) as geojson,
    SUM(peso_total) as total_sales,
    SUM(txn_count) as total_transactions
FROM scout.gold_region_choropleth
WHERE day >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY region_key, region_name, geom;" > /tmp/region_perf.json

END_TIME=$(date +%s.%N)
EXEC_TIME=$(echo "$END_TIME - $START_TIME" | bc)

# Extract planning and execution times from EXPLAIN output
PLANNING_TIME=$(jq -r '.[0]."Planning Time"' /tmp/region_perf.json 2>/dev/null || echo "N/A")
EXECUTION_TIME=$(jq -r '.[0]."Execution Time"' /tmp/region_perf.json 2>/dev/null || echo "N/A")

echo "  Total time: ${EXEC_TIME}s"
echo "  Planning time: ${PLANNING_TIME}ms"
echo "  Execution time: ${EXECUTION_TIME}ms"

# Check if performance meets criteria
if (( $(echo "$EXEC_TIME < 1.5" | bc -l) )); then
    echo -e "${GREEN}✅ Region choropleth query performance acceptable${NC}"
else
    echo -e "${RED}❌ Region choropleth query too slow (>1.5s)${NC}"
fi

echo -e "\n${YELLOW}9. Performance test - City choropleth query...${NC}"
START_TIME=$(date +%s.%N)
psql "$PGURI" -c "
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    citymun_psgc,
    citymun_name,
    LENGTH(ST_AsGeoJSON(geom)) as geojson_size
FROM scout.gold_citymun_choropleth
WHERE region_key = 'NCR'
  AND day >= CURRENT_DATE - INTERVAL '7 days'
LIMIT 50;" > /tmp/city_perf.txt

END_TIME=$(date +%s.%N)
EXEC_TIME=$(echo "$END_TIME - $START_TIME" | bc)

echo "  Query time: ${EXEC_TIME}s"

if (( $(echo "$EXEC_TIME < 0.5" | bc -l) )); then
    echo -e "${GREEN}✅ City choropleth query performance acceptable${NC}"
else
    echo -e "${YELLOW}⚠️  City choropleth query slower than ideal (>0.5s)${NC}"
fi

echo -e "\n${YELLOW}10. Checking geometry size reduction...${NC}"
psql "$PGURI" -c "
SELECT 
    'Original' as type,
    ROUND(AVG(ST_NPoints(geom))) as avg_points,
    ROUND(AVG(LENGTH(ST_AsGeoJSON(geom)))/1024) as avg_kb
FROM scout.geo_adm3_citymun
UNION ALL
SELECT 
    'Simplified' as type,
    ROUND(AVG(ST_NPoints(geom))) as avg_points,
    ROUND(AVG(LENGTH(ST_AsGeoJSON(geom)))/1024) as avg_kb
FROM scout.geo_adm3_citymun_gen;"

echo -e "\n${YELLOW}11. Sample GeoJSON output...${NC}"
psql "$PGURI" -c "
SELECT 
    region_key,
    LEFT(ST_AsGeoJSON(geom), 100) || '...' as geojson_sample
FROM scout.geo_adm1_region
LIMIT 3;"

# Summary
echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Geographic Deployment Verification Complete${NC}"
echo -e "${GREEN}=========================================${NC}"

# Clean up
rm -f /tmp/region_perf.json /tmp/city_perf.txt

# Exit with appropriate code
if [ "$REGION_COUNT" -lt 17 ] || [ "$INVALID_COUNT" -gt 0 ] || [ "$INDEX_COUNT" -lt 6 ]; then
    exit 1
else
    exit 0
fi