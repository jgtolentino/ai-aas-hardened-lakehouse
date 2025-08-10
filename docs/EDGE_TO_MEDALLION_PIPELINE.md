# Edge Device to Medallion Architecture Pipeline

## Overview

This document outlines the complete data flow from Raspberry Pi 5 edge devices through the Bronze → Silver → Gold → Platinum medallion architecture.

## Current State

### Storage Landing Zone
- **Bucket**: `sample`
- **Path**: `scout/v1/bronze/` (raw edge data lands here)
- **Access**: Via `storage_uploader` role with limited permissions

### Missing Components
1. Automated ingestion from storage → bronze tables
2. dbt models for bronze → silver → gold → platinum transformations
3. Orchestration (Airflow/Prefect/GitHub Actions)
4. Data quality checks
5. Monitoring and alerting

## Target Architecture

### 1. Bronze Layer (Raw Data)
```sql
-- Bronze table for raw edge data
CREATE TABLE scout.bronze_edge_raw (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    raw_data JSONB NOT NULL,
    file_size_bytes BIGINT,
    checksum TEXT,
    ingested_at TIMESTAMPTZ DEFAULT NOW(),
    processing_status TEXT DEFAULT 'pending',
    
    -- Partitioning by date for performance
    created_at TIMESTAMPTZ DEFAULT NOW()
) PARTITION BY RANGE (created_at);

-- Create monthly partitions
CREATE TABLE scout.bronze_edge_raw_2024_01 PARTITION OF scout.bronze_edge_raw
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
```

### 2. Silver Layer (Cleansed & Normalized)
```sql
-- dbt model: models/silver/edge/silver_edge_transactions.sql
{{ config(
    materialized='incremental',
    unique_key='transaction_id',
    on_schema_change='fail'
) }}

WITH parsed_data AS (
    SELECT 
        id as bronze_id,
        device_id,
        file_name,
        -- Extract common fields from JSON
        raw_data->>'transaction_id' as transaction_id,
        raw_data->>'store_id' as store_id,
        (raw_data->>'timestamp')::timestamptz as transaction_timestamp,
        (raw_data->>'amount')::decimal(10,2) as amount,
        raw_data->>'currency' as currency,
        raw_data->>'payment_method' as payment_method,
        -- Keep full payload for future needs
        raw_data as full_payload,
        ingested_at,
        created_at
    FROM {{ ref('bronze_edge_raw') }}
    WHERE processing_status = 'pending'
    {% if is_incremental() %}
        AND created_at > (SELECT MAX(created_at) FROM {{ this }})
    {% endif %}
)

SELECT * FROM parsed_data
WHERE transaction_id IS NOT NULL
```

### 3. Gold Layer (Business Aggregates)
```sql
-- dbt model: models/gold/edge/gold_store_daily_summary.sql
{{ config(
    materialized='table',
    indexes=[
        {'columns': ['store_id', 'transaction_date'], 'unique': true}
    ]
) }}

SELECT 
    store_id,
    DATE(transaction_timestamp) as transaction_date,
    COUNT(DISTINCT transaction_id) as transaction_count,
    COUNT(DISTINCT device_id) as active_devices,
    SUM(amount) as total_revenue,
    AVG(amount) as avg_transaction_value,
    MODE() WITHIN GROUP (ORDER BY payment_method) as most_common_payment,
    MIN(transaction_timestamp) as first_transaction_time,
    MAX(transaction_timestamp) as last_transaction_time,
    CURRENT_TIMESTAMP as last_updated
FROM {{ ref('silver_edge_transactions') }}
GROUP BY store_id, DATE(transaction_timestamp)
```

### 4. Platinum Layer (ML Features)
```sql
-- dbt model: models/platinum/edge/platinum_store_features.sql
{{ config(
    materialized='table',
    post_hook='CREATE INDEX idx_plat_store_features ON {{ this }} (store_id)'
) }}

WITH store_metrics AS (
    SELECT 
        store_id,
        -- Time-based features
        AVG(transaction_count) as avg_daily_transactions,
        STDDEV(transaction_count) as stddev_daily_transactions,
        AVG(total_revenue) as avg_daily_revenue,
        
        -- Trend features (7-day moving average)
        AVG(transaction_count) OVER (
            PARTITION BY store_id 
            ORDER BY transaction_date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) as ma7_transactions,
        
        -- Seasonality features
        EXTRACT(DOW FROM transaction_date) as day_of_week,
        AVG(CASE WHEN EXTRACT(DOW FROM transaction_date) IN (0,6) 
            THEN transaction_count END) as weekend_avg,
        AVG(CASE WHEN EXTRACT(DOW FROM transaction_date) NOT IN (0,6) 
            THEN transaction_count END) as weekday_avg
            
    FROM {{ ref('gold_store_daily_summary') }}
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY store_id
)

SELECT * FROM store_metrics
```

## Implementation Pipeline

### Phase 1: Storage → Bronze Ingestion
```python
# scripts/ingest_from_storage.py
import os
from supabase import create_client
import pandas as pd
import json
from datetime import datetime

def ingest_bronze_from_storage():
    """Ingest files from storage to bronze tables"""
    
    supabase = create_client(
        os.environ['SUPABASE_URL'],
        os.environ['SUPABASE_SERVICE_KEY']
    )
    
    # List files in bronze storage
    files = supabase.storage.from_('sample').list('scout/v1/bronze/')
    
    for file in files:
        if file['name'].endswith(('.json', '.csv')):
            # Download file
            data = supabase.storage.from_('sample').download(f"scout/v1/bronze/{file['name']}")
            
            # Parse based on file type
            if file['name'].endswith('.json'):
                content = json.loads(data)
            else:  # CSV
                content = pd.read_csv(data).to_dict('records')
            
            # Insert to bronze table
            for record in content:
                supabase.table('bronze_edge_raw').insert({
                    'device_id': record.get('device_id', 'unknown'),
                    'file_name': file['name'],
                    'file_path': f"scout/v1/bronze/{file['name']}",
                    'raw_data': record,
                    'file_size_bytes': file['metadata']['size'],
                    'checksum': file['metadata'].get('eTag'),
                    'processing_status': 'pending'
                }).execute()
            
            # Move file to processed folder
            supabase.storage.from_('sample').move(
                f"scout/v1/bronze/{file['name']}",
                f"scout/v1/bronze/processed/{datetime.now().strftime('%Y%m%d')}/{file['name']}"
            )
```

### Phase 2: Orchestration Setup

#### Option A: GitHub Actions (Simplest)
```yaml
# .github/workflows/edge-data-pipeline.yml
name: Edge Data Pipeline

on:
  schedule:
    - cron: '*/15 * * * *'  # Every 15 minutes
  workflow_dispatch:

jobs:
  ingest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Ingest Bronze
        run: python scripts/ingest_from_storage.py
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_SERVICE_KEY: ${{ secrets.SUPABASE_SERVICE_KEY }}
      
      - name: Run dbt transformations
        run: |
          dbt run --models +silver_edge_transactions
          dbt run --models +gold_store_daily_summary
          dbt run --models +platinum_store_features
          dbt test
```

#### Option B: Supabase Edge Functions (Real-time)
```typescript
// supabase/functions/process-edge-upload/index.ts
import { serve } from "https://deno.land/std/http/server.ts"

serve(async (req) => {
  // Triggered by storage webhook on file upload
  const { bucket, name } = await req.json()
  
  if (bucket === 'sample' && name.startsWith('scout/v1/bronze/')) {
    // Download and process file
    const { data } = await storage.from(bucket).download(name)
    
    // Insert to bronze table
    await supabase.from('bronze_edge_raw').insert({
      file_path: name,
      raw_data: JSON.parse(data),
      processing_status: 'pending'
    })
    
    // Trigger dbt Cloud job via API
    await fetch('https://cloud.getdbt.com/api/v2/jobs/YOUR_JOB_ID/run/', {
      method: 'POST',
      headers: {
        'Authorization': `Token ${DBT_CLOUD_TOKEN}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ cause: 'Edge data upload' })
    })
  }
})
```

### Phase 3: Data Quality & Monitoring

```sql
-- Create data quality checks
CREATE TABLE scout.data_quality_checks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    check_name TEXT NOT NULL,
    table_name TEXT NOT NULL,
    check_query TEXT NOT NULL,
    expected_result TEXT,
    actual_result TEXT,
    passed BOOLEAN,
    executed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Example quality check
INSERT INTO scout.data_quality_checks (check_name, table_name, check_query)
VALUES 
    ('bronze_completeness', 'bronze_edge_raw', 
     'SELECT COUNT(*) FROM bronze_edge_raw WHERE raw_data IS NULL'),
    ('silver_freshness', 'silver_edge_transactions',
     'SELECT MAX(created_at) > NOW() - INTERVAL ''1 hour'' FROM silver_edge_transactions'),
    ('gold_accuracy', 'gold_store_daily_summary',
     'SELECT COUNT(*) FROM gold_store_daily_summary WHERE total_revenue < 0');
```

## Next Implementation Steps

1. **Create Bronze Ingestion Script**
   ```bash
   cd /Users/tbwa/ai-aas-hardened-lakehouse
   # Create scripts/ingest_from_storage.py
   # Create bronze table migration
   ```

2. **Setup dbt Models**
   ```bash
   cd platform/scout
   dbt init edge_analytics
   # Create models for silver, gold, platinum layers
   ```

3. **Configure Orchestration**
   - GitHub Actions for scheduled runs
   - Or Supabase Edge Functions for real-time

4. **Add Monitoring**
   - Data quality checks
   - Pipeline failure alerts
   - Usage analytics

5. **Documentation**
   - Update architecture diagrams
   - Create runbooks
   - Add to CLAUDE.md

## Benefits of This Architecture

1. **Scalability**: Partitioned tables handle growing data
2. **Reliability**: Retry logic and quality checks
3. **Flexibility**: Raw data preserved in bronze
4. **Performance**: Incremental processing
5. **Observability**: Full audit trail

## Security Considerations

- Edge devices only write to storage (not database)
- Storage → Database ingestion uses service role
- All transformations run server-side
- No direct edge → database connections