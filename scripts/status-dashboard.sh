#!/bin/bash
# ============================================================================
# Scout System Status Dashboard
# Quick health check of all components
# ============================================================================

set -euo pipefail

echo "═══════════════════════════════════════════════════════════"
echo "             🚀 SCOUT SYSTEM STATUS DASHBOARD"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Database Status
echo "📊 DATABASE STATUS"
echo "─────────────────"
if [ -n "${PGURI:-}" ]; then
    psql "$PGURI" -c "
        SELECT 
            'Bronze Records' as metric,
            COUNT(*) as value
        FROM scout.bronze_edge_raw
        UNION ALL
        SELECT 
            'Unique Devices' as metric,
            COUNT(DISTINCT device_id)
        FROM scout.bronze_edge_raw
        UNION ALL
        SELECT 
            'Date Range' as metric,
            MIN(captured_at)::date || ' to ' || MAX(captured_at)::date
        FROM scout.bronze_edge_raw;
    " 2>/dev/null || echo "   ⚠️  Database connection failed"
else
    echo "   ⚠️  PGURI not set"
fi
echo ""

# Token System Status
echo "🔐 TOKEN SYSTEM"
echo "─────────────"
if [ -f collaborators.csv ]; then
    echo "   ✅ Collaborators file exists"
    echo "   📋 Configured users:"
    tail -n +2 collaborators.csv | awk -F',' '{print "      - "$1" ("$2", "$3"h)"}' 
else
    echo "   ⚠️  No collaborators.csv found"
fi
echo ""

# Scripts Status
echo "📜 DEPLOYMENT SCRIPTS"
echo "─────────────────"
echo "   Token Generation:"
[ -f scripts/generate-tokens-cli.sh ] && echo "      ✅ Bash generator ready" || echo "      ❌ Missing"
[ -f scripts/generate-tokens.py ] && echo "      ✅ Python generator ready" || echo "      ❌ Missing"
[ -f scripts/generate-uploader-token.js ] && echo "      ✅ Node generator ready" || echo "      ❌ Missing"
echo ""
echo "   Data Processing:"
[ -f scripts/batch-process-eugene-json.js ] && echo "      ✅ Batch processor ready" || echo "      ❌ Missing"
[ -f scripts/edge-upload.sh ] && echo "      ✅ Edge upload script ready" || echo "      ❌ Missing"
echo ""

# Documentation Status
echo "📚 DOCUMENTATION"
echo "─────────────"
if [ -d docs-site ]; then
    echo "   ✅ Docs site scaffolded"
    [ -f docs-site/package.json ] && echo "   ✅ Package.json configured" || echo "   ⚠️  Missing package.json"
else
    echo "   ⚠️  Docs site not found"
fi
echo ""

# Eugene's Data Status
echo "📦 EUGENE'S JSON DATA"
echo "─────────────────"
if [ -d /Users/tbwa/Downloads/json ]; then
    SCOUTPI_0002=$(find /Users/tbwa/Downloads/json/scoutpi-0002 -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
    SCOUTPI_0006=$(find /Users/tbwa/Downloads/json/scoutpi-0006 -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
    echo "   scoutpi-0002: $SCOUTPI_0002 files"
    echo "   scoutpi-0006: $SCOUTPI_0006 files"
    echo "   Total: $((SCOUTPI_0002 + SCOUTPI_0006)) files to process"
else
    echo "   ⚠️  JSON directory not found"
fi
echo ""

# Quick Actions
echo "═══════════════════════════════════════════════════════════"
echo "📋 QUICK ACTIONS:"
echo ""
echo "1. Generate Tokens:"
echo "   export SUPABASE_JWT_SECRET='your-secret'"
echo "   ./scripts/generate-tokens-cli.sh"
echo ""
echo "2. Process Eugene's Data:"
echo "   export PGURI='postgresql://postgres:[PASSWORD]@db.cxzllzyxwpyptfretryc.supabase.co:5432/postgres'"
echo "   node scripts/batch-process-eugene-json.js"
echo ""
echo "3. Deploy Docs:"
echo "   cd docs-site && npm run deploy"
echo ""
echo "═══════════════════════════════════════════════════════════"