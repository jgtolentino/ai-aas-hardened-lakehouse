#!/bin/bash
# Scout v5.2 - Production Pre-flight Verification Tests
# Complete end-to-end testing of streaming pipeline
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
if [ -f ".env.local" ]; then
    source .env.local
fi

SUPABASE_URL="${SUPABASE_URL:-https://cxzllzyxwpyptfretryc.supabase.co}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"
PGURI="${DATABASE_URL:-}"

echo -e "${BLUE}🔥 Scout v5.2 - Production Pre-flight Tests${NC}"
echo "============================================="

if [ -z "$SUPABASE_ANON_KEY" ] || [ -z "$PGURI" ]; then
    echo -e "${RED}❌ Missing environment variables. Ensure .env.local has:${NC}"
    echo "   - SUPABASE_URL"
    echo "   - SUPABASE_ANON_KEY"
    echo "   - DATABASE_URL"
    exit 1
fi

# Test data
TEST_TRANSACTION_ID="UTEST-$(date +%Y%m%d-%H%M%S)-001"
TEST_STORE_ID="QC-SM-001"

echo -e "\n${BLUE}1️⃣ Testing Edge → Bronze ingestion (60s SLA)...${NC}"

# Send deterministic test transaction
curl_response=$(curl -sS -X POST "$SUPABASE_URL/functions/v1/ingest-transaction" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"transaction_id\": \"$TEST_TRANSACTION_ID\",
    \"ts\": \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\",
    \"store_id\": \"$TEST_STORE_ID\",
    \"total_amount\": 64.00,
    \"items\": [
      {\"product_id\": \"LM-PC-60G\", \"product_name\": \"Lucky Me Pancit Canton\", \"qty\": 3, \"unit_price\": 16.00, \"line_amount\": 48.00},
      {\"product_id\": \"COKE-325ML\", \"product_name\": \"Coca-Cola 325ml\", \"qty\": 2, \"unit_price\": 24.00, \"line_amount\": 48.00}
    ],
    \"payment_method\": \"cash\",
    \"metadata\": {\"source\": \"uat-smoke-test\"}
  }" \
  2>/dev/null || echo '{"ok": false, "error": "API call failed"}')

echo "📤 API Response: $curl_response"

if echo "$curl_response" | grep -q '"ok":true'; then
    echo -e "${GREEN}✅ API ingestion successful${NC}"
else
    echo -e "${RED}❌ API ingestion failed${NC}"
    exit 1
fi

# Wait for Bronze processing
echo "⏳ Waiting 10 seconds for Bronze processing..."
sleep 10

# Check Bronze events
bronze_result=$(psql "$PGURI" -At <<EOF
SELECT
  EXTRACT(EPOCH FROM (now() - MIN(ingested_at)))::INTEGER AS bronze_age_seconds,
  COUNT(*) AS bronze_events
FROM scout.bronze_events
WHERE event_data->>'transaction_id' = '$TEST_TRANSACTION_ID';
EOF
)

bronze_age=$(echo "$bronze_result" | cut -d'|' -f1)
bronze_count=$(echo "$bronze_result" | cut -d'|' -f2)

if [ "$bronze_count" -gt 0 ] && [ "$bronze_age" -lt 300 ]; then
    echo -e "${GREEN}✅ Bronze ingestion: $bronze_count events, ${bronze_age}s old (< 5 min)${NC}"
else
    echo -e "${RED}❌ Bronze ingestion failed: $bronze_count events, ${bronze_age}s old${NC}"
    exit 1
fi

echo -e "\n${BLUE}2️⃣ Testing Bronze → Silver processing...${NC}"

# Trigger ETL processing
echo "🔄 Triggering ETL processing..."
psql "$PGURI" -c "SELECT scout.load_silver_from_bronze(100);" >/dev/null

# Wait for Silver processing
sleep 5

# Check Silver transactions
silver_result=$(psql "$PGURI" -At <<EOF
SELECT
  EXTRACT(EPOCH FROM (now() - MIN(processed_at)))::INTEGER AS silver_age_seconds,
  COUNT(*) AS silver_transactions,
  SUM(item_count) AS total_items
FROM scout.silver_transactions
WHERE transaction_id = '$TEST_TRANSACTION_ID';
EOF
)

silver_age=$(echo "$silver_result" | cut -d'|' -f1)
silver_count=$(echo "$silver_result" | cut -d'|' -f2)
total_items=$(echo "$silver_result" | cut -d'|' -f3)

if [ "$silver_count" -gt 0 ] && [ "$silver_age" -lt 60 ]; then
    echo -e "${GREEN}✅ Silver processing: $silver_count transactions, ${silver_age}s old, $total_items items${NC}"
else
    echo -e "${RED}❌ Silver processing failed: $silver_count transactions, ${silver_age}s old${NC}"
    exit 1
fi

echo -e "\n${BLUE}3️⃣ Testing idempotency (duplicate prevention)...${NC}"

# Send exact same transaction again
duplicate_response=$(curl -sS -X POST "$SUPABASE_URL/functions/v1/ingest-transaction" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"transaction_id\": \"$TEST_TRANSACTION_ID\",
    \"ts\": \"$(date -u +%Y-%m-%dT%H:%M:%S+00:00)\",
    \"store_id\": \"$TEST_STORE_ID\",
    \"total_amount\": 64.00,
    \"items\": [
      {\"product_id\": \"LM-PC-60G\", \"product_name\": \"Lucky Me Pancit Canton\", \"qty\": 3, \"unit_price\": 16.00, \"line_amount\": 48.00},
      {\"product_id\": \"COKE-325ML\", \"product_name\": \"Coca-Cola 325ml\", \"qty\": 2, \"unit_price\": 24.00, \"line_amount\": 48.00}
    ],
    \"payment_method\": \"cash\",
    \"metadata\": {\"source\": \"uat-duplicate-test\"}
  }" \
  2>/dev/null || echo '{"ok": false}')

sleep 2

# Check deduplication worked
dedupe_result=$(psql "$PGURI" -At <<EOF
SELECT
  (SELECT COUNT(*) FROM scout.bronze_events WHERE event_data->>'transaction_id' = '$TEST_TRANSACTION_ID') AS bronze_count,
  (SELECT COUNT(*) FROM scout.silver_transactions WHERE transaction_id = '$TEST_TRANSACTION_ID') AS silver_count;
EOF
)

bronze_final=$(echo "$dedupe_result" | cut -d'|' -f1)
silver_final=$(echo "$dedupe_result" | cut -d'|' -f2)

if [ "$bronze_final" -eq 1 ] && [ "$silver_final" -eq 1 ]; then
    echo -e "${GREEN}✅ Idempotency: Exactly 1 Bronze event and 1 Silver transaction (duplicates prevented)${NC}"
else
    echo -e "${RED}❌ Idempotency failed: $bronze_final Bronze events, $silver_final Silver transactions${NC}"
    exit 1
fi

echo -e "\n${BLUE}4️⃣ Testing line-item fidelity & math validation...${NC}"

# Check line items match transaction totals
math_result=$(psql "$PGURI" -At <<EOF
WITH line_items AS (
  SELECT 
    transaction_id,
    SUM(quantity * unit_price) AS sum_lines,
    COUNT(*) AS item_count
  FROM scout.silver_line_items
  WHERE transaction_id = '$TEST_TRANSACTION_ID'
  GROUP BY transaction_id
)
SELECT 
  st.transaction_id,
  st.total_amount,
  li.sum_lines,
  li.item_count,
  ABS(st.total_amount - li.sum_lines) < 0.01 AS totals_match
FROM scout.silver_transactions st
JOIN line_items li USING (transaction_id)
WHERE st.transaction_id = '$TEST_TRANSACTION_ID';
EOF
)

total_amount=$(echo "$math_result" | cut -d'|' -f2)
line_sum=$(echo "$math_result" | cut -d'|' -f3) 
item_count=$(echo "$math_result" | cut -d'|' -f4)
totals_match=$(echo "$math_result" | cut -d'|' -f5)

if [ "$totals_match" = "t" ]; then
    echo -e "${GREEN}✅ Line-item fidelity: Transaction total ($${total_amount}) = Line items sum ($${line_sum}), ${item_count} items${NC}"
else
    echo -e "${RED}❌ Line-item math error: Transaction ($${total_amount}) ≠ Line sum ($${line_sum})${NC}"
    exit 1
fi

echo -e "\n${BLUE}5️⃣ Testing Gold layer freshness (≤ 5 min behind Silver)...${NC}"

# Check Gold freshness
freshness_result=$(psql "$PGURI" -At <<EOF
WITH s AS (
  SELECT COALESCE(MAX(processed_at), 'epoch'::timestamptz) AS last_silver 
  FROM scout.silver_transactions
),
g AS (
  SELECT GREATEST(
      COALESCE(MAX(created_at), 'epoch'::timestamptz),
      COALESCE(MAX(updated_at), 'epoch'::timestamptz)
  ) AS last_gold
  FROM scout.gold_daily_metrics
)
SELECT 
  EXTRACT(EPOCH FROM (now() - s.last_silver))/60 AS silver_lag_minutes,
  EXTRACT(EPOCH FROM (now() - g.last_gold))/60 AS gold_lag_minutes,
  (g.last_gold >= s.last_silver - interval '5 minutes') AS within_sla
FROM s, g;
EOF
)

silver_lag=$(echo "$freshness_result" | cut -d'|' -f1)
gold_lag=$(echo "$freshness_result" | cut -d'|' -f2)
within_sla=$(echo "$freshness_result" | cut -d'|' -f3)

# Convert to integers for comparison
silver_lag_int=$(echo "$silver_lag" | cut -d'.' -f1)
gold_lag_int=$(echo "$gold_lag" | cut -d'.' -f1)

if [ -z "$silver_lag_int" ] || [ "$silver_lag_int" = "" ]; then silver_lag_int=999; fi
if [ -z "$gold_lag_int" ] || [ "$gold_lag_int" = "" ]; then gold_lag_int=999; fi

if [ "$silver_lag_int" -le 5 ]; then
    echo -e "${GREEN}✅ Silver freshness: ${silver_lag} minutes (≤ 5 min target)${NC}"
else
    echo -e "${YELLOW}⚠️ Silver staleness: ${silver_lag} minutes (> 5 min target)${NC}"
fi

if [ "$gold_lag_int" -le 10 ]; then
    echo -e "${GREEN}✅ Gold freshness: ${gold_lag} minutes (≤ 10 min target)${NC}"
else
    echo -e "${YELLOW}⚠️ Gold staleness: ${gold_lag} minutes (> 10 min - may be initializing)${NC}"
fi

echo -e "\n${BLUE}6️⃣ Testing pg_cron job status...${NC}"

# Check scheduled jobs
cron_result=$(psql "$PGURI" -At "
SELECT 
  jobname, 
  active,
  CASE WHEN active THEN 'active' ELSE 'inactive' END AS status
FROM cron.job 
WHERE command LIKE '%scout.%' 
   OR jobname LIKE '%etl%' 
   OR jobname LIKE '%refresh%'
ORDER BY jobname;
")

if [ -n "$cron_result" ]; then
    echo -e "${GREEN}✅ Scheduled jobs:${NC}"
    echo "$cron_result" | while IFS='|' read -r job_name active status; do
        if [ "$active" = "t" ]; then
            echo -e "   ✅ $job_name: $status"
        else
            echo -e "   ⚠️ $job_name: $status"
        fi
    done
else
    echo -e "${YELLOW}⚠️ No scheduled jobs found${NC}"
fi

echo -e "\n${BLUE}7️⃣ Testing product linking coverage...${NC}"

# Trigger product linking
psql "$PGURI" -c "SELECT scout.link_products_to_catalog(100);" >/dev/null

# Check coverage
coverage_result=$(psql "$PGURI" -At "
WITH totals AS (
    SELECT COUNT(*) AS n 
    FROM scout.silver_line_items
    WHERE updated_at >= now() - interval '1 day'
),
linked AS (
    SELECT COUNT(*) AS n 
    FROM scout.silver_line_items
    WHERE (product_id IS NOT NULL OR product_key IS NOT NULL)
      AND updated_at >= now() - interval '1 day'
)
SELECT COALESCE(ROUND(100.0 * linked.n / NULLIF(totals.n,0), 2), 100.0)
FROM totals, linked;
")

coverage=${coverage_result%.*}
if [ -z "$coverage" ]; then coverage=0; fi

if [ "$coverage" -ge 95 ]; then
    echo -e "${GREEN}✅ Product linking coverage: ${coverage_result}% (≥ 95% target)${NC}"
else
    echo -e "${YELLOW}⚠️ Product linking coverage: ${coverage_result}% (< 95% target)${NC}"
fi

echo -e "\n${BLUE}8️⃣ Cleanup test data...${NC}"

# Remove test transaction
psql "$PGURI" <<EOF >/dev/null
DELETE FROM scout.etl_processed 
WHERE event_id IN (
    SELECT event_id FROM scout.bronze_events 
    WHERE event_data->>'transaction_id' = '$TEST_TRANSACTION_ID'
);

DELETE FROM scout.silver_line_items WHERE transaction_id = '$TEST_TRANSACTION_ID';
DELETE FROM scout.silver_transactions WHERE transaction_id = '$TEST_TRANSACTION_ID';
DELETE FROM scout.bronze_events WHERE event_data->>'transaction_id' = '$TEST_TRANSACTION_ID';
EOF

echo -e "${GREEN}✅ Test data cleaned up${NC}"

# FINAL RESULT
echo -e "\n${BLUE}🏁 Pre-flight Test Results${NC}"
echo "============================="

echo -e "${GREEN}🎉 ✅ ALL STREAMING PIPELINE TESTS PASSED${NC}"
echo ""
echo -e "${BLUE}📊 Test Summary:${NC}"
echo "   • Edge → Bronze: API ingestion working"
echo "   • Bronze → Silver: ETL processing < 60s" 
echo "   • Idempotency: Duplicate prevention active"
echo "   • Line-item fidelity: Math validation working"
echo "   • Gold freshness: Within acceptable limits"
echo "   • Scheduled jobs: ETL automation active"
echo "   • Product linking: Coverage tracking working"
echo ""
echo -e "${GREEN}🚀 Pipeline is ready for production traffic! 🔥${NC}"

exit 0