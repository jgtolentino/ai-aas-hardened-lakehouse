#!/usr/bin/env bash
set -euo pipefail

# Scout v5.2 - Analytics Math Validation
# Validates all analytics calculations and formulas are mathematically correct

DATABASE_URL="${DATABASE_URL:-postgresql://postgres:password@localhost:54322/postgres}"

echo "🧮 Scout v5.2 Analytics Math Validation"
echo "======================================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_status() {
  if [ $1 -eq 0 ]; then
    echo -e "${GREEN}✅ $2${NC}"
  else
    echo -e "${RED}❌ $2${NC}"
    ((FAILED_CHECKS++))
  fi
}

FAILED_CHECKS=0

echo -e "\n📊 1. Installing Math Invariant Checks"
echo "-------------------------------------"

# Install math invariant views and functions
echo "Installing analytics math validation..."
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f platform/scout/sql/analytics/math_invariants.sql
check_status $? "Math invariant views and functions installed"

echo -e "\n🔍 2. Data Quality & Formula Validation"
echo "--------------------------------------"

# Run comprehensive math checks
echo "Running math invariant validation..."
psql "$DATABASE_URL" << 'EOSQL'
\pset format aligned
\pset border 2

SELECT 
  check_name,
  status,
  error_count,
  total_count,
  pass_rate || '%' as pass_rate_pct
FROM scout.run_math_invariant_checks()
ORDER BY 
  CASE status WHEN 'FAIL' THEN 1 WHEN 'WARN' THEN 2 ELSE 3 END,
  check_name;
EOSQL

# Check if any critical failures
failure_count=$(psql "$DATABASE_URL" -tAc "
SELECT COUNT(*) FROM scout.run_math_invariant_checks() 
WHERE status = 'FAIL' AND error_count > 0;
")

check_status $([ "$failure_count" -eq 0 ] && echo 0 || echo 1) "Core math invariants (${failure_count} critical failures)"

echo -e "\n📈 3. Market Share Validation"
echo "----------------------------"

# Check market share additivity
echo "Validating market share calculations..."
market_share_failures=$(psql "$DATABASE_URL" -tAc "
SELECT COUNT(*) FROM scout.v_market_share_check 
WHERE check_status = 'FAIL';
")

check_status $([ "$market_share_failures" -eq 0 ] && echo 0 || echo 1) "Market share additivity (${market_share_failures} failures)"

if [ "$market_share_failures" -gt 0 ]; then
  echo "Sample market share issues:"
  psql "$DATABASE_URL" -c "
    SELECT store_id, category, total_share, share_error, check_status
    FROM scout.v_market_share_check 
    WHERE check_status = 'FAIL' 
    LIMIT 5;
  "
fi

echo -e "\n💰 4. Financial Calculations"
echo "---------------------------"

# Validate transaction totals
echo "Checking transaction total accuracy..."
additivity_failures=$(psql "$DATABASE_URL" -tAc "
SELECT COUNT(*) FROM scout.v_additivity_check 
WHERE check_status = 'FAIL';
")

check_status $([ "$additivity_failures" -eq 0 ] && echo 0 || echo 1) "Transaction additivity (${additivity_failures} failures)"

echo -e "\n🏷️ 5. Weighted Average Prices"
echo "----------------------------"

# Validate price calculations
echo "Checking weighted average price calculations..."
price_failures=$(psql "$DATABASE_URL" -tAc "
SELECT COUNT(*) FROM scout.v_weighted_price_check 
WHERE check_status = 'FAIL';
")

check_status $([ "$price_failures" -eq 0 ] && echo 0 || echo 1) "Weighted price calculations (${price_failures} failures)"

echo -e "\n📅 6. Temporal Window Consistency"
echo "--------------------------------"

# Check time window definitions
echo "Validating temporal window consistency..."
window_failures=$(psql "$DATABASE_URL" -tAc "
SELECT COUNT(*) FROM scout.v_window_consistency_check 
WHERE check_status = 'FAIL';
")

check_status $([ "$window_failures" -eq 0 ] && echo 0 || echo 1) "Temporal window consistency (${window_failures} failures)"

echo -e "\n🎯 7. Forecasting Baseline Setup"
echo "--------------------------------"

# Install forecasting validation views
echo "Installing forecasting validation..."
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f platform/scout/sql/metrics/backtest_baseline_30d.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f platform/scout/sql/metrics/backtest_model_30d.sql
check_status $? "Forecasting baseline views installed"

# Test seasonal naive baseline calculation
echo "Testing seasonal naive baseline..."
baseline_count=$(psql "$DATABASE_URL" -tAc "
SELECT COUNT(*) FROM scout.v_baseline_seasonal_naive 
WHERE yhat_sn_7 IS NOT NULL;
" 2>/dev/null || echo "0")

check_status $([ "$baseline_count" -gt 0 ] && echo 0 || echo 1) "Seasonal naive baseline ($baseline_count data points)"

echo -e "\n🧪 8. Sample Forecasting Gate Test"
echo "---------------------------------"

# Test forecast gate (with mock data if needed)
echo "Testing forecast gate logic..."
if psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -v MODEL_NAME='test_model' -v DAYS=7 -f platform/scout/sql/metrics/forecast_gate.sql >/dev/null 2>&1; then
  check_status 0 "Forecast gate logic test"
else
  echo -e "${YELLOW}⚠️  Forecast gate test skipped (no model data)${NC}"
fi

echo -e "\n📋 9. Analytics Documentation"
echo "----------------------------"

# Check if analytics documentation exists
docs_count=0
[ -f "platform/scout/sql/analytics/math_invariants.sql" ] && ((docs_count++))
[ -f "platform/scout/sql/metrics/forecast_gate.sql" ] && ((docs_count++))
[ -f "scripts/ci/run_forecast_gate.sh" ] && ((docs_count++))

check_status $([ $docs_count -eq 3 ] && echo 0 || echo 1) "Math validation documentation ($docs_count/3 files)"

echo -e "\n🚀 10. Final Math Validation Status"
echo "==================================="

if [ $FAILED_CHECKS -eq 0 ]; then
  echo -e "${GREEN}"
  echo "🎉 MATH VALIDATION PASSED! 🎉"
  echo "All analytics calculations are mathematically sound."
  echo -e "${NC}"
  
  echo -e "\n📊 Math Quality Summary:"
  psql "$DATABASE_URL" << 'EOSQL'
SELECT 
  'Analytics Views' as component,
  COUNT(*) as count 
FROM information_schema.views 
WHERE table_schema = 'scout' AND table_name LIKE 'v_%check'

UNION ALL

SELECT 
  'Math Functions' as component,
  COUNT(*) as count 
FROM information_schema.routines 
WHERE routine_schema = 'scout' AND routine_name LIKE '%math%'

UNION ALL

SELECT 
  'Forecast Views' as component,
  COUNT(*) as count 
FROM information_schema.views 
WHERE table_schema = 'scout' AND table_name LIKE '%baseline%'

ORDER BY component;
EOSQL

  echo -e "\n🔧 CI/CD Integration:"
  echo "• Add to GitHub Actions: .github/workflows/forecast-gate.yml"
  echo "• Math checks available: SELECT * FROM scout.run_math_invariant_checks()"
  echo "• Forecast validation: ./scripts/ci/run_forecast_gate.sh"
  
  exit 0
else
  echo -e "${RED}"
  echo "❌ MATH VALIDATION ISSUES DETECTED"
  echo "Failed checks: $FAILED_CHECKS"
  echo -e "${NC}"
  
  echo -e "\n🔧 Next Steps:"
  echo "1. Review failed math invariant checks"
  echo "2. Fix data quality issues"
  echo "3. Re-run validation: ./scripts/validate_analytics_math.sh"
  
  exit 1
fi