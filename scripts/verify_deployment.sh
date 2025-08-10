#!/bin/bash
set -euo pipefail

echo "=== Deployment Verification Script ==="
echo "Running post-deployment checks..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check required environment variables
required_vars=(
    "PGURI"
    "SUPERSET_BASE"
    "SUPERSET_USER"
    "SUPERSET_PASSWORD"
    "SUPABASE_URL"
    "SUPABASE_SERVICE_ROLE_KEY"
)

echo -e "\n${YELLOW}1. Checking environment variables...${NC}"
missing_vars=0
for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
        echo -e "${RED}✗ Missing: $var${NC}"
        ((missing_vars++))
    else
        echo -e "${GREEN}✓ Found: $var${NC}"
    fi
done

if [ $missing_vars -gt 0 ]; then
    echo -e "${RED}ERROR: Missing $missing_vars required environment variables${NC}"
    exit 1
fi

# 2. Check database connectivity and Gold table data
echo -e "\n${YELLOW}2. Checking database and Gold table...${NC}"
gold_count=$(psql "$PGURI" -tAc "SELECT COUNT(*) FROM scout.gold_txn_daily" 2>/dev/null || echo "0")
if [ "$gold_count" -gt 0 ]; then
    echo -e "${GREEN}✓ Gold table has $gold_count rows${NC}"
    revenue=$(psql "$PGURI" -tAc "SELECT to_char(SUM(total_peso_value)::numeric, 'FM999,999,990.00') FROM scout.gold_txn_daily" || echo "0")
    echo -e "${GREEN}  Total revenue: ₱$revenue${NC}"
else
    echo -e "${RED}✗ Gold table is empty${NC}"
fi

# 3. Check Superset authentication
echo -e "\n${YELLOW}3. Checking Superset authentication...${NC}"
TOKEN=$(curl -sX POST "$SUPERSET_BASE/api/v1/security/login" \
    -H 'Content-Type: application/json' \
    -d "{\"username\":\"$SUPERSET_USER\",\"password\":\"$SUPERSET_PASSWORD\",\"provider\":\"db\",\"refresh\":true}" \
    2>/dev/null | jq -r .access_token || echo "")

if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
    echo -e "${GREEN}✓ Superset authentication successful${NC}"
else
    echo -e "${RED}✗ Superset authentication failed${NC}"
    exit 1
fi

# 4. Check Superset datasets binding
echo -e "\n${YELLOW}4. Checking Superset dataset bindings...${NC}"
datasets=$(curl -s "$SUPERSET_BASE/api/v1/dataset/?q=%7B%22page_size%22:1000%7D" \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null || echo "{}")

scout_datasets=$(echo "$datasets" | jq -r '.result[]? | select(.schema == "scout") | .table_name' | wc -l)
if [ "$scout_datasets" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $scout_datasets datasets bound to scout schema${NC}"
    echo "$datasets" | jq -r '.result[]? | select(.schema == "scout") | "\(.table_name) → \(.database.database_name)"' | head -5
else
    echo -e "${RED}✗ No datasets found in scout schema${NC}"
fi

# 5. Check critical dashboards
echo -e "\n${YELLOW}5. Checking critical dashboards...${NC}"
if [ -f "platform/superset/critical_dash_ids.txt" ]; then
    while IFS= read -r dash_id; do
        [[ "$dash_id" =~ ^#.*$ ]] && continue
        [[ -z "$dash_id" ]] && continue
        
        response=$(curl -sX GET "$SUPERSET_BASE/api/v1/dashboard/$dash_id" \
            -H "Authorization: Bearer $TOKEN" 2>/dev/null || echo "{}")
        
        if echo "$response" | jq -e '.result.dashboard_title' >/dev/null 2>&1; then
            title=$(echo "$response" | jq -r '.result.dashboard_title')
            echo -e "${GREEN}✓ Dashboard $dash_id: $title${NC}"
        else
            echo -e "${RED}✗ Dashboard $dash_id not found${NC}"
        fi
    done < platform/superset/critical_dash_ids.txt
else
    echo -e "${YELLOW}⚠ No critical dashboard IDs configured${NC}"
fi

# 6. Summary
echo -e "\n${YELLOW}=== Verification Summary ===${NC}"
echo -e "Database: ${GREEN}Connected${NC}"
echo -e "Gold Data: $([ "$gold_count" -gt 0 ] && echo -e "${GREEN}Present${NC}" || echo -e "${RED}Missing${NC}")"
echo -e "Superset: ${GREEN}Authenticated${NC}"
echo -e "Datasets: $([ "$scout_datasets" -gt 0 ] && echo -e "${GREEN}Bound${NC}" || echo -e "${RED}Not bound${NC}")"

# Exit with appropriate code
if [ "$gold_count" -eq 0 ] || [ "$scout_datasets" -eq 0 ]; then
    exit 1
fi
exit 0