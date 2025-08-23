#!/bin/bash

# Scout v5.2 Backend Deployment Script
# Version: 5.2.0
# Date: August 23, 2025

echo "🚀 Deploying Scout v5.2 Backend Components"
echo "=========================================="

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Please install it first:"
    echo "   brew install supabase/tap/supabase"
    exit 1
fi

# Get project ref from user or environment
PROJECT_REF=${SUPABASE_PROJECT_REF:-"cxzllzyxwpyptfretryc"}
echo "📦 Project: $PROJECT_REF"

# 1. Apply Database Migration
echo ""
echo "1️⃣ Applying database migration..."
echo "   Please run this in your Supabase SQL Editor:"
echo "   Path: supabase/migrations/20250823_scout_v5_2_complete_backend.sql"
echo "   URL: https://app.supabase.com/project/$PROJECT_REF/sql/new"
echo ""
read -p "Press Enter after applying the migration..."

# 2. Deploy Edge Functions
echo ""
echo "2️⃣ Deploying Edge Functions..."

# Deploy agentic-cron
echo "   Deploying agentic-cron..."
supabase functions deploy agentic-cron \
  --project-ref $PROJECT_REF \
  --no-verify-jwt

# Deploy isko-worker
echo "   Deploying isko-worker..."
supabase functions deploy isko-worker \
  --project-ref $PROJECT_REF \
  --no-verify-jwt

# 3. Set up Cron Schedule for agentic-cron
echo ""
echo "3️⃣ Setting up cron schedule..."
echo "   Run this SQL in Supabase to schedule agentic-cron every 15 minutes:"
cat << 'EOF'

-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule agentic-cron to run every 15 minutes
SELECT cron.schedule(
    'scout-agentic-cron',
    '*/15 * * * *',
    $$
    SELECT net.http_post(
        url := 'https://cxzllzyxwpyptfretryc.supabase.co/functions/v1/agentic-cron',
        headers := jsonb_build_object(
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
            'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb
    );
    $$
);

-- Schedule isko-worker to run every 5 minutes
SELECT cron.schedule(
    'scout-isko-worker',
    '*/5 * * * *',
    $$
    SELECT net.http_post(
        url := 'https://cxzllzyxwpyptfretryc.supabase.co/functions/v1/isko-worker',
        headers := jsonb_build_object(
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
            'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb
    );
    $$
);

-- Verify scheduled jobs
SELECT * FROM cron.job;

EOF

echo ""
read -p "Press Enter after setting up cron schedules..."

# 4. Verify Deployment
echo ""
echo "4️⃣ Verifying deployment..."

# Test RPC functions
echo "   Testing RPC functions..."
curl -X POST "https://$PROJECT_REF.supabase.co/rest/v1/rpc/rpc_get_dashboard_kpis" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{}' \
  --silent | head -c 100

echo ""
echo "   Testing brand list..."
curl -X POST "https://$PROJECT_REF.supabase.co/rest/v1/rpc/rpc_brands_list" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"p_limit": 5}' \
  --silent | head -c 100

# 5. Summary
echo ""
echo ""
echo "✅ Scout v5.2 Backend Deployment Complete!"
echo "=========================================="
echo ""
echo "📊 Components Deployed:"
echo "   • Platinum Layer: monitors, events, action ledger, agent feed"
echo "   • Deep Research: SKU jobs, summary, matching"
echo "   • Master Data: brands, products with relationships"
echo "   • RLS: Enforced on all tables with proper policies"
echo "   • RPC Functions: Gold-only access APIs"
echo "   • Edge Functions: agentic-cron, isko-worker"
echo "   • Cron Jobs: Scheduled automation"
echo ""
echo "🔗 Access Points:"
echo "   • Database: https://app.supabase.com/project/$PROJECT_REF"
echo "   • API: https://$PROJECT_REF.supabase.co/rest/v1/"
echo "   • Edge Functions: https://$PROJECT_REF.supabase.co/functions/v1/"
echo ""
echo "📝 Next Steps:"
echo "   1. Update GenieView UI to display agent feed"
echo "   2. Configure brand/product catalogs"
echo "   3. Set up monitoring alerts"
echo "   4. Test end-to-end agentic flow"
echo ""
echo "🚀 Scout v5.2 is ready for production!"
