#!/bin/bash
# Deploy Automatic ETL Pipeline for Edge-Inbox
# No manual processing - fully automated with Storage Webhook

set -e

echo "🚀 Deploying Automatic ETL Pipeline"
echo "=================================="

# Check for required environment variables
if [[ -z "$SUPABASE_PROJECT_REF" ]]; then
  export SUPABASE_PROJECT_REF="cxzllzyxwpyptfretryc"
fi

echo "📦 Using project: $SUPABASE_PROJECT_REF"

# Step 1: Apply database migrations
echo -e "\n1️⃣ Applying database migrations..."
supabase db push --db-url "postgresql://postgres:postgres@localhost:54322/postgres" || {
  echo "Local migration failed, trying remote..."
  supabase db push --linked
}

# Step 2: Deploy Edge Function
echo -e "\n2️⃣ Deploying Edge Function..."
supabase functions deploy ingest-bronze \
  --project-ref $SUPABASE_PROJECT_REF \
  --no-verify-jwt

# Step 3: Set Edge Function secrets
echo -e "\n3️⃣ Setting Edge Function secrets..."
WEBHOOK_SECRET=$(openssl rand -hex 32)
echo "Generated webhook secret: $WEBHOOK_SECRET"

# Note: You need to set SUPABASE_SERVICE_ROLE_KEY manually
supabase secrets set \
  --project-ref $SUPABASE_PROJECT_REF \
  EDGE_WEBHOOK_SECRET=$WEBHOOK_SECRET

echo -e "\n⚠️  IMPORTANT: Set your service role key:"
echo "supabase secrets set --project-ref $SUPABASE_PROJECT_REF SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>"

# Step 4: Instructions for Storage Webhook
echo -e "\n4️⃣ Configure Storage Webhook in Dashboard:"
echo "============================================"
echo "1. Go to: https://app.supabase.com/project/$SUPABASE_PROJECT_REF/storage/buckets"
echo "2. Click on 'scout-ingest' bucket"
echo "3. Go to 'Webhooks' tab"
echo "4. Click 'Create webhook'"
echo "5. Configure:"
echo "   - Event: Object created"
echo "   - Path filter: edge-inbox/**"
echo "   - URL: https://$SUPABASE_PROJECT_REF.supabase.co/functions/v1/ingest-bronze"
echo "   - Headers:"
echo "     x-edge-webhook-secret: $WEBHOOK_SECRET"
echo "   - Timeout: 120s"
echo "   - Retries: Enable"

# Step 5: Test the pipeline
echo -e "\n5️⃣ Test Instructions:"
echo "===================="
echo "1. Upload a test ZIP to scout-ingest/edge-inbox/"
echo "2. Check function logs:"
echo "   supabase functions logs ingest-bronze --project-ref $SUPABASE_PROJECT_REF --follow"
echo "3. Check pipeline status:"
cat << 'EOF'
   
-- Check watermarks
SELECT * FROM scout.etl_watermarks ORDER BY processed_at DESC LIMIT 5;

-- Check bronze records
SELECT COUNT(*), MAX(ingested_at) FROM scout.bronze_edge_raw;

-- Check pipeline status
SELECT * FROM scout.v_etl_pipeline_status;
EOF

echo -e "\n✅ Deployment complete!"
echo "The pipeline will automatically process any ZIP file uploaded to scout-ingest/edge-inbox/"