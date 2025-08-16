#!/bin/bash
# Scout Edge: Complete Quality Monitoring Setup

set -e

echo "Scout Edge Quality Monitoring Setup"
echo "==================================="

# Check environment
if [ -z "$POSTGRES_URL" ]; then
    echo "Error: POSTGRES_URL not set"
    exit 1
fi

echo "1. Setting up confusion matrix infrastructure..."
psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 -f scripts/confusion-matrix-setup.sql

echo ""
echo "2. Creating KPI views and functions..."
psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 -f scripts/confusion-kpis.sql

echo ""
echo "3. Setting up evaluation schedules..."
psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 -f scripts/evaluation-schedule.sql

echo ""
echo "4. Installing operational alerts..."
psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 -f scripts/operational-alerts.sql

echo ""
echo "5. Setting up Quality Sentinel..."
psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 -f scripts/quality-sentinel-setup.sql

echo ""
echo "6. Running initial sync and computation..."
psql "$POSTGRES_URL" <<SQL
-- Sync latest predictions
SELECT suqi.sync_brand_predictions();

-- Compute initial confusion matrix
SELECT suqi.compute_brand_confusion('24 hours');

-- Check system health
SELECT * FROM suqi.system_health_check();
SQL

echo ""
echo "7. Checking scheduled jobs..."
psql "$POSTGRES_URL" -c "SELECT * FROM suqi.v_scheduled_jobs;"

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. Deploy Quality Sentinel: supabase functions deploy quality-sentinel"
echo "2. Set GitHub secrets: SUPABASE_URL, SENTINEL_KEY, CLICKUP_TOKEN, GITHUB_TOKEN"
echo "3. Test manually: curl -X POST \$SUPABASE_URL/functions/v1/quality-sentinel -H 'x-sentinel-key: \$SENTINEL_KEY'"
echo "4. Monitor: SELECT * FROM suqi.v_brand_kpis;"