# Bronze to Gold End-to-End Verification Guide

## Overview

This guide provides **copy-paste-ready commands** to verify the complete Scout Analytics data pipeline from ZIP files through Bronze → Silver → Gold layers with **evidence-based validation**.

## 🚀 Quick Start (One Command)

```bash
# Complete end-to-end smoke test
npm run smoke
```

This will:
1. Generate sample ZIP files
2. Upload to Supabase Storage
3. Wait for ingest pipeline
4. Validate all layers with contract checks
5. Print pass/fail matrix

## 📋 Pre-flight Setup

### 1. Environment Variables
```bash
export SUPABASE_URL=https://your-project.supabase.co
export SUPABASE_ANON_KEY=eyJ...your-anon-key
export SERVICE_ROLE=eyJ...your-service-role-key
export USER_JWT=eyJ...optional-user-jwt
export INGEST_BUCKET=scout-ingest
```

### 2. Database Sanity Check
Run in Supabase SQL Editor:
```sql
-- Copy from scripts/db-preflight.sql
SELECT COUNT(*) AS products FROM scout.products;
SELECT COUNT(*) AS stores   FROM scout.stores;

-- Creates minimal seed data if tables empty
INSERT INTO scout.stores (id, name, region, city, barangay) 
SELECT * FROM (VALUES 
  (1, 'SM North EDSA', 'NCR', 'Quezon City', 'North Triangle'),
  (2, 'Robinsons Ermita', 'NCR', 'Manila', 'Ermita'),
  (3, 'Ayala Center Cebu', 'Central Visayas', 'Cebu City', 'Business Park'),
  (4, 'SM Davao', 'Davao Region', 'Davao City', 'Quimpo Boulevard'),
  (5, 'Gaisano Cagayan', 'Northern Mindanao', 'Cagayan de Oro', 'Carmen')
) AS seed(id, name, region, city, barangay)
WHERE NOT EXISTS (SELECT 1 FROM scout.stores LIMIT 1);
```

## 🔧 Manual Step-by-Step

### Step 1: Generate Sample ZIPs
```bash
# Generate with custom parameters
npm run bronze:generate -- --out dist/bronze --stores 5 --days 7 --rows 1200 --seed 42

# Check generated files
ls -la dist/bronze/*.zip
```

### Step 2: Upload to Storage (Manual)
```bash
# Set variables
ZIP=$(ls -1 dist/bronze/*.zip | head -n1)
PATH_IN_BUCKET=ingest/$(date +%F)/$(basename "$ZIP")

# Upload via curl (requires SERVICE_ROLE)
curl -sS -X POST "$SUPABASE_URL/storage/v1/object/$INGEST_BUCKET/$PATH_IN_BUCKET" \
  -H "Authorization: Bearer $SERVICE_ROLE" \
  -H "apikey: $SERVICE_ROLE" \
  -H "Content-Type: application/zip" \
  --data-binary @"$ZIP" | jq .

# Alternative: Upload via Supabase Dashboard
echo "Manual upload: Go to Storage > scout-ingest bucket and upload $ZIP"
```

### Step 3: Verify Ingest (Wait & Check)
```bash
# Wait for processing
sleep 10

# Check Silver item count
curl -sS -X GET "$SUPABASE_URL/rest/v1/silver_items_w_txn_store_api?select=count" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" | jq .
```

### Step 4: Run Contract Tests
```bash
# Run all RPC and Edge tests
npm run smoke:rpc
```

### Step 5: Database Assertions
Run in Supabase SQL Editor:
```sql
-- Copy from scripts/db-assertions.sql
-- Recent Bronze arrivals (last 15 min)
SELECT COUNT(*) AS bronze_txns
FROM scout.bronze_transactions
WHERE ingested_at >= now() - interval '15 minutes';

-- Gold daily aggregates
SELECT date, SUM(net_sales_amt) AS net_sales
FROM public.gold_sales_day_api
WHERE date >= current_date - 7
GROUP BY 1 ORDER BY 1 DESC LIMIT 7;

-- DQ health check
SELECT dq_health_bucket, COUNT(*) 
FROM scout.silver_dq_daily_summary
WHERE date = current_date
GROUP BY 1;
```

## 🧪 Available Test Scripts

### Core Scripts
```bash
npm run smoke              # Full end-to-end pipeline test
npm run smoke:rpc          # RPC + Edge tests only
npm run bronze:generate    # Generate sample ZIP files
npm run bronze:verify      # Verify Bronze layer schema/data
```

### With Parameters
```bash
# Custom generation
node scripts/generate-bronze-zip.js --out dist/bronze --stores 3 --days 5 --rows 800

# Verify with sample data
node scripts/verify-bronze-layer.js --generate-sample
```

## ✅ Success Criteria

The pipeline is healthy when:

### Bronze Layer
- ✅ `bronze_transactions` table has recent records
- ✅ `bronze_transaction_items` table populated  
- ✅ No ingestion errors in Edge Function logs

### Silver Layer  
- ✅ `silver_transactions_clean` view accessible
- ✅ DQ flags computed correctly
- ✅ Unit normalization working (kg, L, pc, bundle, sachet)
- ✅ Timezone conversion (UTC → Philippines local)

### Gold Layer
- ✅ All Gold views return data (`gold_txn_items_api`, `gold_sales_day_api`)
- ✅ Daily aggregates computed
- ✅ Geographic hierarchies populated
- ✅ Brand mix calculations working

### Data Quality
- ✅ DQ health index ≥ 75 (good/warn, not bad)
- ✅ Top issues tracked and reasonable
- ✅ DQ RPC functions working

## 🚨 Troubleshooting

### No Data in Silver/Gold
1. Check Bronze ingestion: `SELECT COUNT(*) FROM scout.bronze_transactions`
2. Check Edge Function logs: `supabase functions logs ingest-bronze`
3. Verify foreign key constraints (store_id, product_id exist)

### Storage Upload Fails
1. Check SERVICE_ROLE permissions
2. Verify bucket `scout-ingest` exists
3. Ensure bucket is configured for public access

### RPC Tests Fail
1. Check RLS policies are not blocking authenticated access
2. Verify JWT token has proper claims
3. Check PostgREST endpoint accessibility

### DQ Health Bad
1. Check for missing timestamps: `SELECT COUNT(*) WHERE dq_missing_ts = 1`
2. Review top issues: `SELECT * FROM scout.silver_dq_top_issues`
3. Validate reference data quality

## 🎯 Contract Validation

The smoke tests validate these contracts:

### Data Flow Contracts
- Bronze → Silver: Count ratio ≥ 0.95
- Silver → Gold: Count ratio ≥ 0.80  
- DQ Health: Average ≥ 50

### API Contracts
- All Gold views return HTTP 200
- RPC functions execute without error
- Data types match TypeScript interfaces

### Business Logic Contracts  
- Unit conversions: dozen → 12 pieces, g → kg
- Timezone: UTC timestamps → Philippines local
- Money sanitization: negative values → NULL
- Deduplication: latest record wins

## 🔄 Continuous Integration

### GitHub Actions
```yaml
# Manual trigger with parameters
name: smoke
on:
  workflow_dispatch:
    inputs:
      rows: { default: "1200" }
      days: { default: "7" }
```

### Local Development
```bash
# Quick verification during development  
npm run smoke:rpc

# Full pipeline test before deployment
npm run smoke
```

## 📊 Expected Output

### Successful Run
```
→ Step 1: Generate sample ZIPs
   ✓ Generated: dist/bronze/scout-data-1-2025-08-12.zip

→ Step 2: Baseline Silver count  
   count(silver_txn_items_api) = 0

→ Step 3: Upload to Storage
   ✓ Uploaded to scout-ingest/ingest/2025-08-12/scout-data-1-2025-08-12.zip

→ Step 4: Wait for ingest (poll Silver count delta)
   poll → 1847
   ✓ Ingest detected (+1847)

→ Step 5: RPC + Edge smoke
Progress: ..........

📋 Test Results:
================
✓ PASS gold_txn_items_api
✓ PASS gold_sales_day_api  
✓ PASS silver_dq_daily_summary_api
✓ PASS get_dq_health_rpc

📊 Summary:
Total: 10, Passed: 10, Failed: 0

✅ All tests passed - Bronze→Silver→Gold pipeline is healthy

SMOKE PASS ✓ End-to-end pipeline looks healthy.
```

## 🛡️ Guardrails

### Data Integrity
- **ID Mapping**: Only emit store_id/product_id that exist in reference tables
- **Deduplication**: Bronze loader dedupes via `(txn_id,item_seq)` constraints
- **Clock Skew**: Use embedded timestamps, not upload time

### Security
- **Storage Auth**: SERVICE_ROLE for uploads (server-side only)
- **RLS**: All views inherit row-level security from base tables  
- **Secrets**: No credentials in logs or client code

### Reliability  
- **Idempotency**: Re-uploading same ZIP doesn't double-insert
- **Error Handling**: Failed ingestion doesn't corrupt existing data
- **Monitoring**: DQ health gates prevent bad data propagation

---

🎉 **Ready to verify?** Run `npm run smoke` and watch the magic happen!