#!/bin/bash
# Apply ETL Hardening Migration + Verify

set -e

echo "🚀 Applying ETL Hardening Migration"
echo "==================================="

# Apply migration
echo "1️⃣ Applying migration 024..."
psql "postgresql://postgres:Postgres_26@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres?options=project%3Dcxzllzyxwpyptfretryc" \
  -v ON_ERROR_STOP=1 \
  -f platform/scout/migrations/024_etl_hardening_source_file_tracking.sql

# Quick health check
echo -e "\n2️⃣ Health check..."
psql "postgresql://postgres:Postgres_26@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres?options=project%3Dcxzllzyxwpyptfretryc" \
  -v ON_ERROR_STOP=1 \
  -c "select * from scout.pipeline_health_check();"

# Check ZIP pipeline status
echo -e "\n3️⃣ ZIP pipeline status..."
psql "postgresql://postgres:Postgres_26@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres?options=project%3Dcxzllzyxwpyptfretryc" \
  -v ON_ERROR_STOP=1 \
  -c "select * from scout.v_zip_pipeline_status order by finished_at desc nulls last limit 10;"

echo -e "\n✅ Migration applied successfully!"
echo "📋 Use docs-site/docs/operations/pipeline-verification.md for ongoing monitoring"