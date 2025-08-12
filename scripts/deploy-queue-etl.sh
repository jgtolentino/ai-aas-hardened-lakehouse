#!/bin/bash
# Deploy Queue-Driven ETL Pipeline
# Production-safe with queue, DLQ, and monitoring

set -e

echo "🚀 Deploying Queue-Driven ETL Pipeline"
echo "====================================="

PROJECT_REF="${SUPABASE_PROJECT_REF:-cxzllzyxwpyptfretryc}"
DB_PASSWORD="${SUPABASE_DB_PASSWORD}"

if [[ -z "$DB_PASSWORD" ]]; then
  echo "❌ Missing SUPABASE_DB_PASSWORD environment variable"
  echo "Set it with: export SUPABASE_DB_PASSWORD=your_password"
  exit 1
fi

DB_URL="postgresql://postgres:${DB_PASSWORD}@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres?options=project%3D${PROJECT_REF}"

echo "📦 Project: $PROJECT_REF"

# Step 1: Apply migrations
echo -e "\n1️⃣ Applying database migrations..."
psql "$DB_URL" -v ON_ERROR_STOP=1 -f platform/scout/migrations/023_auto_etl_queue.sql
psql "$DB_URL" -v ON_ERROR_STOP=1 -f platform/scout/migrations/024_etl_hardening.sql

# Step 2: Verify queue setup
echo -e "\n2️⃣ Verifying queue setup..."
psql "$DB_URL" -c "SELECT * FROM scout.v_etl_pipeline_monitor;"

# Step 3: Test queue functionality
echo -e "\n3️⃣ Testing queue functionality..."
psql "$DB_URL" << 'EOF'
-- Simulate enqueueing a test file
INSERT INTO scout.etl_queue(bucket_id, name, size_bytes, status)
VALUES ('scout-ingest', 'edge-inbox/test.zip', 1024, 'QUEUED')
ON CONFLICT (bucket_id, name) DO NOTHING;

-- Check queue
SELECT id, bucket_id, name, status, attempts FROM scout.etl_queue 
WHERE name = 'edge-inbox/test.zip';

-- Clean up test
DELETE FROM scout.etl_queue WHERE name = 'edge-inbox/test.zip';
EOF

# Step 4: Process existing files
echo -e "\n4️⃣ Checking for existing files to queue..."
psql "$DB_URL" << 'EOF'
-- Queue existing files manually (one-time)
INSERT INTO scout.etl_queue(bucket_id, name, size_bytes, status)
SELECT 
  'scout-ingest',
  name,
  (metadata->>'size')::bigint,
  'QUEUED'
FROM storage.objects
WHERE bucket_id = 'scout-ingest'
  AND (name LIKE 'edge-inbox/%.zip' OR name LIKE 'email-attachments/%.zip')
ON CONFLICT (bucket_id, name) DO NOTHING;

-- Show queued files
SELECT bucket_id, name, size_bytes/1024/1024.0 as size_mb, status 
FROM scout.etl_queue 
ORDER BY enqueued_at DESC 
LIMIT 10;
EOF

# Step 5: Manual processing command
echo -e "\n5️⃣ Commands for manual processing:"
echo "======================================"
cat << 'COMMANDS'
# Process queue manually (one batch):
psql "$DB_URL" -c "SELECT * FROM scout.process_etl_queue(100);"

# Process all queued items:
psql "$DB_URL" -c "SELECT * FROM scout.auto_process_etl_pipeline();"

# Monitor pipeline:
psql "$DB_URL" -c "SELECT * FROM scout.v_etl_pipeline_monitor;"

# View recent queue activity:
psql "$DB_URL" -c "
  SELECT id, name, status, attempts, last_error, 
         started_at, finished_at,
         extract(epoch from (finished_at - started_at)) as duration_seconds
  FROM scout.etl_queue 
  ORDER BY id DESC 
  LIMIT 20;
"

# Retry failed items:
psql "$DB_URL" -c "SELECT * FROM scout.retry_failed_etl();"

# Check failures:
psql "$DB_URL" -c "
  SELECT bucket_id, name, error_msg, attempts, failed_at 
  FROM scout.etl_failures 
  ORDER BY failed_at DESC 
  LIMIT 10;
"
COMMANDS

# Step 6: Optional pg_cron setup
echo -e "\n6️⃣ To enable automatic processing every 2 minutes:"
echo "=================================================="
cat << 'CRON'
psql "$DB_URL" << 'SQL'
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule(
  'scout_etl_queue_every_2m', 
  '*/2 * * * *', 
  $$SELECT scout.process_etl_queue(250);$$
);

-- Verify cron job
SELECT * FROM cron.job WHERE jobname = 'scout_etl_queue_every_2m';
SQL
CRON

echo -e "\n✅ Queue-driven ETL pipeline deployed!"
echo "Files uploaded to scout-ingest/edge-inbox/ or /email-attachments/ will be automatically queued."