#!/bin/bash
# Scout Edge: Deploy Production-Grade SKU Scraper

set -e

echo "Scout Edge SKU Scraper Deployment"
echo "================================="

# Check for required environment variables
if [ -z "$POSTGRES_URL" ]; then
    echo "Error: POSTGRES_URL not set"
    echo "Example: export POSTGRES_URL='postgresql://user:pass@host/db'"
    exit 1
fi

if [ -z "$SUPABASE_PROJECT_REF" ]; then
    echo "Error: SUPABASE_PROJECT_REF not set"
    exit 1
fi

echo ""
echo "1. Running database migrations..."
for migration in platform/scout/migrations/02[6-9]_*.sql platform/scout/migrations/03[0-2]_*.sql; do
    echo "  - Applying $(basename $migration)"
    psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 -f "$migration"
done

echo ""
echo "2. Deploying isko-scraper edge function..."
supabase functions deploy isko-scraper --project-ref "$SUPABASE_PROJECT_REF"

echo ""
echo "3. Checking system health..."
psql "$POSTGRES_URL" -c "SELECT * FROM scout.dashboard_snapshot();"

echo ""
echo "4. Setting up initial test data..."
psql "$POSTGRES_URL" -c "SELECT scout.seed_jobs_from_sources(true);"

echo ""
echo "Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Set environment variables:"
echo "   export PG_REST='https://$SUPABASE_PROJECT_REF.supabase.co/rest/v1'"
echo "   export ISKO_URL='https://$SUPABASE_PROJECT_REF.supabase.co/functions/v1/isko-scraper'"
echo "   export SUPABASE_ANON='your-anon-key'"
echo ""
echo "2. Start workers:"
echo "   make worker"
echo ""
echo "3. Monitor:"
echo "   make scraper-status"
echo ""
echo "4. Dashboard:"
echo "   psql \$POSTGRES_URL -c 'SELECT * FROM scout.dashboard_snapshot();'"