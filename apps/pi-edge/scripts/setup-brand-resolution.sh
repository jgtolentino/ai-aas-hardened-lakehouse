#!/bin/bash
# Scout Edge: Complete Brand Resolution Setup Script

set -e

echo "Scout Edge Brand Resolution System Setup"
echo "========================================"

# Check environment
if [ -z "$POSTGRES_URL" ]; then
    echo "Error: POSTGRES_URL not set"
    echo "Please run: export POSTGRES_URL='postgresql://user:pass@host/db'"
    exit 1
fi

echo "1. Creating STT Brand Dictionary..."
psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 -f scripts/stt-brand-dictionary.sql

echo ""
echo "2. Setting up Brand Universe views..."
psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 -f scripts/brand-universe-setup.sql

echo ""
echo "3. Installing Brand Resolver trigger..."
psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 -f scripts/brand-resolver-trigger.sql

echo ""
echo "4. Installing Token Mining (optional)..."
psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 -f scripts/token-mining-trigger.sql

echo ""
echo "5. Running initial reports..."
psql "$POSTGRES_URL" <<SQL

-- Brand Universe Summary
SELECT 'Brand Universe Summary:' as report;
SELECT * FROM scout.v_brand_universe_summary;

-- Current Coverage
SELECT '' as blank;
SELECT 'Current Brand Coverage (Last 7 Days):' as report;
WITH stats AS (
  SELECT 
    COUNT(*) as total_items,
    COUNT(brand_name) as items_with_brand
  FROM public.scout_gold_transaction_items
  WHERE transaction_id IN (
    SELECT transaction_id 
    FROM public.scout_gold_transactions 
    WHERE ts_utc >= CURRENT_DATE - INTERVAL '7 days'
  )
)
SELECT 
  total_items,
  items_with_brand,
  ROUND(100.0 * items_with_brand / NULLIF(total_items, 0), 2) as brand_coverage_pct
FROM stats;

-- Top Unrecognized
SELECT '' as blank;
SELECT 'Top 10 Unrecognized Brand Values:' as report;
SELECT * FROM scout.v_brands_unrecognized LIMIT 10;

SQL

echo ""
echo "6. Running backfill on existing data..."
psql "$POSTGRES_URL" -c "SELECT * FROM scout.backfill_resolve_brands(5000);"

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. Export catalog for Pi: ./scripts/export-brand-catalog.sh"
echo "2. View reports: psql \$POSTGRES_URL -f scripts/brand-reports.sql"
echo "3. Monitor coverage: SELECT * FROM scout.v_brand_universe_summary;"