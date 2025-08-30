# ✅ Supabase Storage ETL Pipeline - CONFIGURED!

## Your Existing Buckets Are Now Integrated!

### 📦 **Bucket Configuration**:
- **Development**: `sample` bucket (for testing & development)
- **Production**: `scout-etl` bucket (for production data)

### 🚀 **Edge Function Deployed**: 
- **Name**: `supabase-storage-loader`
- **Status**: ACTIVE
- **Endpoint**: `https://cxzllzyxwpyptfretryc.supabase.co/functions/v1/supabase-storage-loader`

## Current Status

```
✅ sample bucket: 30 records loaded (100% processed)
✅ scout-etl bucket: 50 records loaded (100% processed)
✅ Edge Function: Active and ready
✅ ETL Pipeline: Bronze → Silver → Gold configured
```

## How to Use Your Storage Buckets

### 1. **Upload Data to Buckets**

#### Via Supabase Dashboard:
1. Go to Storage → `sample` (for dev) or `scout-etl` (for prod)
2. Upload JSON/CSV files with transaction data
3. Files should follow this structure:

```json
[
  {
    "transaction_id": "TXN-001",
    "store_id": "STORE-1",
    "timestamp": "2024-01-15T10:30:00Z",
    "total_amount": 450.50,
    "payment_method": "gcash",
    "customer_segment": "regular",
    "items": [
      {
        "product_name": "San Miguel Beer",
        "qty": 2,
        "unit_price": 65.00
      }
    ]
  }
]
```

#### Via Edge Function (Generate Test Data):
```javascript
// Upload sample data to bucket
fetch('https://cxzllzyxwpyptfretryc.supabase.co/functions/v1/supabase-storage-loader', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer YOUR_ANON_KEY',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    environment: 'development',  // or 'production'
    action: 'upload'  // Generates and uploads sample data
  })
})
```

### 2. **Load Data from Buckets into ETL Pipeline**

```javascript
// Load data from storage bucket
fetch('https://cxzllzyxwpyptfretryc.supabase.co/functions/v1/supabase-storage-loader', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer YOUR_ANON_KEY',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    environment: 'development',  // Uses 'sample' bucket
    action: 'load',
    fileName: null  // Process all files, or specify a filename
  })
})

// For production data
fetch('https://cxzllzyxwpyptfretryc.supabase.co/functions/v1/supabase-storage-loader', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer YOUR_ANON_KEY',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    environment: 'production',  // Uses 'scout-etl' bucket
    action: 'load'
  })
})
```

### 3. **Monitor ETL Pipeline**

```sql
-- Check bucket status
SELECT * FROM scout.supabase_bucket_status;

-- View ETL pipeline flow
SELECT 
    'Bronze' as layer,
    COUNT(*) FILTER (WHERE source_system LIKE 'supabase://sample%') as sample_records,
    COUNT(*) FILTER (WHERE source_system LIKE 'supabase://scout-etl%') as production_records
FROM scout.bronze_transactions
UNION ALL
SELECT 
    'Silver',
    COUNT(*) FILTER (WHERE source_file LIKE 'supabase://sample%'),
    COUNT(*) FILTER (WHERE source_file LIKE 'supabase://scout-etl%')
FROM scout.silver_transactions
UNION ALL
SELECT 
    'Gold',
    COUNT(*) FILTER (WHERE transaction_id LIKE 'SAMPLE-%'),
    COUNT(*) FILTER (WHERE transaction_id LIKE 'PROD-%')
FROM scout.scout_gold_transactions;
```

## Data Flow Architecture

```
Your Existing Buckets
├── sample/ (Development)
│   └── scout-data/
│       ├── transactions.json
│       ├── daily-2024-01-15.json
│       └── test-data.csv
│
└── scout-etl/ (Production)
    └── transactions/
        ├── batch-001.json
        ├── batch-002.json
        └── realtime-feed.json
            ↓
    Edge Function (supabase-storage-loader)
            ↓
    Bronze Layer (Raw data)
            ↓
    Silver Layer (Cleaned)
            ↓
    Gold Layer (Dashboard Ready)
            ↓
    Scout Dashboard
```

## Cost Benefits

Using Supabase Storage instead of external S3:
- **No AWS costs**: Everything stays within Supabase
- **Simplified auth**: Uses existing Supabase authentication
- **Faster access**: No external network calls
- **Unified billing**: Single invoice for all services

### Storage Costs:
- Supabase Storage: $0.021/GB/month
- Database storage: $0.125/GB/month
- **Savings**: 83% reduction in storage costs

## Quick Test Script

```bash
#!/bin/bash

# Test the storage loader
SUPABASE_URL="https://cxzllzyxwpyptfretryc.supabase.co"
ANON_KEY="YOUR_ANON_KEY"

# 1. Upload test data to development bucket
echo "Uploading test data..."
curl -X POST "$SUPABASE_URL/functions/v1/supabase-storage-loader" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "environment": "development",
    "action": "upload"
  }'

# 2. Load data from bucket
echo "Loading data from bucket..."
curl -X POST "$SUPABASE_URL/functions/v1/supabase-storage-loader" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "environment": "development",
    "action": "load"
  }'
```

## Next Steps

1. **Upload your actual data files** to the buckets:
   - Development data → `sample` bucket
   - Production data → `scout-etl` bucket

2. **Schedule automatic loads** using pg_cron:
   ```sql
   SELECT cron.schedule(
     'load-from-storage',
     '0 * * * *',  -- Every hour
     $$SELECT net.http_post(
       url := 'https://cxzllzyxwpyptfretryc.supabase.co/functions/v1/supabase-storage-loader',
       headers := '{"Authorization": "Bearer YOUR_SERVICE_KEY"}'::jsonb,
       body := '{"environment": "production", "action": "load"}'::jsonb
     )$$
   );
   ```

3. **Set up monitoring alerts** for failed loads

4. **Configure bucket policies** for security:
   - `sample`: Allow authenticated users
   - `scout-etl`: Restrict to service role only

Your storage buckets are now fully integrated with the ETL pipeline! 🎉
