#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$PWD}"
cd "$ROOT"

EXPECTATIONS=".inventory/EXPECTATIONS.json"
INVENTORY="out/supabase_inventory.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Validating Supabase inventory against expectations..."

if [[ ! -f "$EXPECTATIONS" ]]; then
  echo -e "${RED}❌ Missing expectations file: $EXPECTATIONS${NC}"
  exit 1
fi

if [[ ! -f "$INVENTORY" ]]; then
  echo -e "${RED}❌ Missing inventory file: $INVENTORY${NC}"
  echo "   Run ./scripts/inventory/inventory.sh first"
  exit 1
fi

# Helper functions
get_expected() { jq -r ".$1" "$EXPECTATIONS"; }
get_actual() { jq -r ".$1" "$INVENTORY"; }
get_tolerance() { jq -r ".tolerance.$1" "$EXPECTATIONS"; }

EXIT_CODE=0
VIOLATIONS=()

# Validation functions
validate_count() {
  local name="$1"
  local expected_key="$2"
  local actual_key="$3"
  local tolerance_key="$4"
  
  local expected=$(get_expected "$expected_key")
  local actual=$(get_actual "$actual_key")
  local tolerance=$(get_tolerance "$tolerance_key")
  
  if [[ "$expected" == "null" || "$actual" == "null" || "$tolerance" == "null" ]]; then
    echo -e "${YELLOW}⚠️  $name: Missing data (expected=$expected, actual=$actual, tolerance=$tolerance)${NC}"
    return 0
  fi
  
  local diff=$((actual - expected))
  local abs_diff=${diff#-}  # absolute value
  
  if (( abs_diff <= tolerance )); then
    echo -e "${GREEN}✅ $name: $actual (expected $expected ±$tolerance)${NC}"
  else
    echo -e "${RED}❌ $name: $actual (expected $expected ±$tolerance, deviation: $diff)${NC}"
    VIOLATIONS+=("$name: actual=$actual expected=$expected±$tolerance deviation=$diff")
    EXIT_CODE=1
  fi
}

validate_min() {
  local name="$1"
  local min_key="$2"
  local actual_key="$3"
  
  local min_expected=$(get_expected "$min_key")
  local actual=$(get_actual "$actual_key")
  
  if [[ "$min_expected" == "null" || "$actual" == "null" ]]; then
    echo -e "${YELLOW}⚠️  $name: Missing data (min=$min_expected, actual=$actual)${NC}"
    return 0
  fi
  
  if (( actual >= min_expected )); then
    echo -e "${GREEN}✅ $name: $actual (min $min_expected)${NC}"
  else
    echo -e "${RED}❌ $name: $actual (min $min_expected required)${NC}"
    VIOLATIONS+=("$name: actual=$actual minimum=$min_expected")
    EXIT_CODE=1
  fi
}

validate_array_contains() {
  local name="$1"
  local expected_key="$2"
  local actual_key="$3"
  
  local expected_json=$(jq -c ".$expected_key" "$EXPECTATIONS")
  local actual_json=$(jq -c ".$actual_key" "$INVENTORY")
  
  if [[ "$expected_json" == "null" || "$actual_json" == "null" ]]; then
    echo -e "${YELLOW}⚠️  $name: Missing data${NC}"
    return 0
  fi
  
  local missing=()
  while IFS= read -r item; do
    if ! echo "$actual_json" | jq -e "map(.name) | contains([\"$item\"])" >/dev/null; then
      missing+=("$item")
    fi
  done < <(echo "$expected_json" | jq -r '.[]')
  
  if (( ${#missing[@]} == 0 )); then
    echo -e "${GREEN}✅ $name: All expected items present${NC}"
  else
    echo -e "${RED}❌ $name: Missing items: ${missing[*]}${NC}"
    VIOLATIONS+=("$name: missing=${missing[*]}")
    EXIT_CODE=1
  fi
}

# Run validations
echo ""
echo "Edge Functions:"
validate_count "Edge Functions" "edge_functions_expected" "edge_functions | length" "edge_functions_max_deviation"

echo ""
echo "Migrations:"
validate_min "Main Migrations" "migrations_min" "migrations.main | length"

echo ""
echo "Database Schemas:"
validate_array_contains "Required Schemas" "schemas_expected" "db.schemas"

echo ""
echo "Table Counts:"
validate_min "Scout Tables" "table_count_scout_min" "db.table_counts | map(select(.schema==\"scout\")) | .[0].tables // 0"

echo ""
echo "Medallion Architecture:"
validate_min "Bronze Tables" "medallion_bronze_min" "db.medallion_counts.bronze"
validate_min "Silver Tables" "medallion_silver_min" "db.medallion_counts.silver" 
validate_min "Gold Tables" "medallion_gold_min" "db.medallion_counts.gold"
validate_min "Platinum Tables" "medallion_platinum_min" "db.medallion_counts.platinum"

echo ""
echo "Security Policies:"
validate_min "Scout RLS Policies" "policies_scout_min" "db.policies | length"

# Summary
echo ""
echo "========================================="
if (( EXIT_CODE == 0 )); then
  echo -e "${GREEN}✅ All validations passed!${NC}"
  echo "   Inventory matches expectations within tolerance"
else
  echo -e "${RED}❌ ${#VIOLATIONS[@]} validation(s) failed:${NC}"
  printf '   - %s\n' "${VIOLATIONS[@]}"
  echo ""
  echo "   Fix the issues or update expectations in:"
  echo "   $EXPECTATIONS"
fi
echo "========================================="

exit $EXIT_CODE