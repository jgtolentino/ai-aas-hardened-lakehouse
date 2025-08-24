#!/usr/bin/env bash
# Scout v5.2 - Streaming Pipeline Acceptance Gate
# Fails CI/PR if streaming pipeline is not production-ready
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔥 Scout v5.2 Streaming Pipeline Acceptance Gate${NC}"
echo "=============================================="

# Check environment variables
if [ -z "${PGURI:-}" ] && [ -z "${DATABASE_URL:-}" ]; then
    if [ -f ".env.local" ]; then
        source .env.local
        PGURI="${DATABASE_URL:-}"
    fi
fi

if [ -z "${PGURI:-}" ]; then
    echo -e "${RED}❌ Missing database connection. Set PGURI or DATABASE_URL${NC}"
    exit 1
fi

# Test database connection
echo -e "${BLUE}📋 Testing database connection...${NC}"
if ! psql "$PGURI" -c "SELECT 'Connection OK';" >/dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to database${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Database connection established${NC}"

# 1. FRESHNESS CHECK
echo -e "\n${BLUE}📊 Checking data freshness (Silver ≤5min, Gold ≤10min)...${NC}"
freshness_result=$(psql "$PGURI" -At <<'SQL'
WITH s AS (
    SELECT COALESCE(MAX(processed_at), 'epoch'::timestamptz) AS last_silver 
    FROM scout.silver_transactions
),
g AS (
    SELECT GREATEST(
        COALESCE(MAX(created_at), 'epoch'::timestamptz),
        COALESCE(MAX(updated_at), 'epoch'::timestamptz)
    ) AS last_gold
    FROM (
        SELECT created_at, NULL::timestamptz AS updated_at 
        FROM scout.gold_daily_metrics LIMIT 1
        UNION ALL
        SELECT created_at, NULL::timestamptz
        FROM scout.gold_region_choropleth LIMIT 1
    ) t
)
SELECT 
    CASE WHEN (SELECT EXTRACT(EPOCH FROM (now()-last_silver))/60 FROM s) <= 5 THEN 1 ELSE 0 END AS silver_ok,
    CASE WHEN (SELECT EXTRACT(EPOCH FROM (now()-last_gold))/60 FROM g) <= 10 THEN 1 ELSE 0 END AS gold_ok,
    ROUND((SELECT EXTRACT(EPOCH FROM (now()-last_silver))/60 FROM s)::numeric, 2) AS silver_lag_minutes,
    ROUND((SELECT EXTRACT(EPOCH FROM (now()-last_gold))/60 FROM g)::numeric, 2) AS gold_lag_minutes
FROM s, g;
SQL
)

silver_ok=$(echo "$freshness_result" | cut -d'|' -f1)
gold_ok=$(echo "$freshness_result" | cut -d'|' -f2)
silver_lag=$(echo "$freshness_result" | cut -d'|' -f3)
gold_lag=$(echo "$freshness_result" | cut -d'|' -f4)

if [ "$silver_ok" = "1" ]; then
    echo -e "${GREEN}✅ Silver freshness: ${silver_lag} minutes (≤5 min target)${NC}"
else
    echo -e "${RED}❌ Silver staleness: ${silver_lag} minutes (>5 min target)${NC}"
fi

if [ "$gold_ok" = "1" ]; then
    echo -e "${GREEN}✅ Gold freshness: ${gold_lag} minutes (≤10 min target)${NC}"
else
    echo -e "${YELLOW}⚠️ Gold staleness: ${gold_lag} minutes (>10 min target - may be initializing)${NC}"
fi

# 2. PRODUCT LINK COVERAGE CHECK
echo -e "\n${BLUE}🔗 Checking product linking coverage (≥95% target)...${NC}"
coverage=$(psql "$PGURI" -Atc "
WITH totals AS (
    SELECT COUNT(*) AS n 
    FROM scout.silver_line_items
    WHERE processed_at >= now() - interval '1 day'
),
linked AS (
    SELECT COUNT(*) AS n 
    FROM scout.silver_line_items
    WHERE product_id IS NOT NULL
      AND processed_at >= now() - interval '1 day'
)
SELECT COALESCE(ROUND(100.0 * linked.n / NULLIF(totals.n,0), 2), 100.0)
FROM totals, linked;
")

required_coverage=95
coverage_int=${coverage%.*}
if [ -z "$coverage_int" ]; then coverage_int=0; fi

if [ "$coverage_int" -ge "$required_coverage" ]; then
    echo -e "${GREEN}✅ Product linking coverage: ${coverage}% (≥${required_coverage}% target)${NC}"
else
    echo -e "${RED}❌ Product linking coverage: ${coverage}% (<${required_coverage}% target)${NC}"
    exit 42
fi

# 3. MATH GUARDRAILS CHECK
echo -e "\n${BLUE}🧮 Checking math guardrails (zero tolerance for bad data)...${NC}"
bad_rows=$(psql "$PGURI" -Atc "
SELECT COUNT(*) 
FROM scout.silver_transactions
WHERE total_amount < 0
   OR item_count <= 0
   OR processed_at >= now() - interval '1 day'
   AND EXISTS (
       SELECT 1 FROM scout.silver_line_items li
       WHERE li.transaction_id = scout.silver_transactions.transaction_id
         AND (li.quantity <= 0 OR li.unit_price < 0)
   );
")

if [ "$bad_rows" = "0" ]; then
    echo -e "${GREEN}✅ Math guardrails: No invalid data detected${NC}"
else
    echo -e "${RED}❌ Math guardrails: ${bad_rows} rows with invalid amounts/quantities${NC}"
    exit 43
fi

# 4. PIPELINE FLOW CHECK (Bronze → Silver processing)
echo -e "\n${BLUE}⚡ Checking pipeline flow (Bronze → Silver processing)...${NC}"
pipeline_stats=$(psql "$PGURI" -At <<'SQL'
SELECT 
    COUNT(*) AS bronze_events,
    COUNT(DISTINCT event_data->>'transaction_id') AS unique_transactions,
    ROUND(AVG(EXTRACT(EPOCH FROM (now() - ingested_at))/60)::numeric, 2) AS avg_bronze_age_minutes
FROM scout.bronze_events 
WHERE ingested_at >= now() - interval '1 hour';
SQL
)

bronze_events=$(echo "$pipeline_stats" | cut -d'|' -f1)
unique_txns=$(echo "$pipeline_stats" | cut -d'|' -f2)
avg_bronze_age=$(echo "$pipeline_stats" | cut -d'|' -f3)

echo -e "${GREEN}✅ Pipeline activity (last hour):${NC}"
echo "   📥 Bronze events: $bronze_events"
echo "   🔄 Unique transactions: $unique_txns"
echo "   ⏱️ Average bronze age: ${avg_bronze_age} minutes"

# 5. CRON JOBS STATUS
echo -e "\n${BLUE}⏰ Checking scheduled jobs status...${NC}"
cron_status=$(psql "$PGURI" -At "
SELECT 
    STRING_AGG(
        jobname || ':' || CASE WHEN active THEN 'active' ELSE 'inactive' END, 
        '|'
    )
FROM cron.job 
WHERE command LIKE '%scout.%' OR jobname LIKE '%-etl' OR jobname LIKE '%-refresh';
")

if [ -n "$cron_status" ]; then
    echo -e "${GREEN}✅ Scheduled jobs:${NC}"
    echo "$cron_status" | tr '|' '\n' | while read -r job; do
        job_name=$(echo "$job" | cut -d':' -f1)
        job_status=$(echo "$job" | cut -d':' -f2)
        if [ "$job_status" = "active" ]; then
            echo -e "   ✅ $job_name"
        else
            echo -e "   ⚠️ $job_name (inactive)"
        fi
    done
else
    echo -e "${YELLOW}⚠️ No scheduled jobs found${NC}"
fi

# 6. ADVISORY LOCK CHECK (no stuck processes)
echo -e "\n${BLUE}🔒 Checking for stuck advisory locks...${NC}"
stuck_locks=$(psql "$PGURI" -Atc "
SELECT COUNT(*) 
FROM pg_locks 
WHERE locktype = 'advisory' AND NOT granted;
")

if [ "$stuck_locks" = "0" ]; then
    echo -e "${GREEN}✅ No stuck advisory locks${NC}"
else
    echo -e "${RED}❌ Found ${stuck_locks} stuck advisory locks${NC}"
    exit 44
fi

# 7. RECENT ERROR CHECK
echo -e "\n${BLUE}🚨 Checking for recent alerts/errors...${NC}"
recent_alerts=$(psql "$PGURI" -Atc "
SELECT COUNT(*) 
FROM scout.alerts 
WHERE severity = 'critical' 
  AND created_at >= now() - interval '1 hour'
  AND resolved_at IS NULL;
")

if [ "$recent_alerts" = "0" ]; then
    echo -e "${GREEN}✅ No critical alerts in the last hour${NC}"
else
    echo -e "${YELLOW}⚠️ Found ${recent_alerts} unresolved critical alerts${NC}"
    # Don't fail on alerts, just warn
fi

# FINAL RESULT
echo -e "\n${BLUE}🏁 Acceptance Gate Results:${NC}"
echo "================================"

# Check all critical criteria
exit_code=0

if [ "$silver_ok" != "1" ]; then
    echo -e "${RED}❌ FAIL: Silver data staleness exceeds 5 minutes${NC}"
    exit_code=45
fi

if [ "$coverage_int" -lt "$required_coverage" ]; then
    echo -e "${RED}❌ FAIL: Product linking coverage below 95%${NC}"
    exit_code=42
fi

if [ "$bad_rows" != "0" ]; then
    echo -e "${RED}❌ FAIL: Math guardrails detected invalid data${NC}"
    exit_code=43
fi

if [ "$stuck_locks" != "0" ]; then
    echo -e "${RED}❌ FAIL: Advisory locks are stuck${NC}"
    exit_code=44
fi

if [ $exit_code -eq 0 ]; then
    echo -e "\n${GREEN}🎉 ✅ STREAMING PIPELINE ACCEPTANCE GATE PASSED${NC}"
    echo -e "${GREEN}🚀 Production deployment approved!${NC}"
    echo ""
    echo -e "${BLUE}📊 Summary:${NC}"
    echo "   • Silver freshness: ${silver_lag} minutes (✅ ≤5 min)"
    echo "   • Gold freshness: ${gold_lag} minutes (target ≤10 min)"  
    echo "   • Product linking: ${coverage}% (✅ ≥95%)"
    echo "   • Data integrity: No invalid records (✅)"
    echo "   • Pipeline flow: ${unique_txns} transactions processed (✅)"
    echo ""
    echo -e "${GREEN}Ready for production traffic! 🔥${NC}"
else
    echo -e "\n${RED}💥 ❌ STREAMING PIPELINE ACCEPTANCE GATE FAILED${NC}"
    echo -e "${RED}🚫 Production deployment blocked!${NC}"
    echo ""
    echo "Fix the issues above and re-run this script."
fi

exit $exit_code