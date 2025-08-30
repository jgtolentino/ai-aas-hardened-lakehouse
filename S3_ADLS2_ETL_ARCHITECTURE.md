# S3/ADLS2 ETL Architecture for Scout Dashboard

## Overview
This document outlines how the ETL pipeline changes when using S3 bucket storage (or Azure Data Lake Storage Gen2) as the primary data source instead of direct database ingestion.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     EXTERNAL STORAGE LAYER                   │
├───────────────────┬────────────────┬────────────────────────┤
│   DEVELOPMENT     │    STAGING      │     PRODUCTION         │
│  S3: scout-sample │  S3: scout-stg  │  S3: scout-prod       │
│  Sample Data      │  Test Data      │  Real Data            │
└─────────┬─────────┴────────┬───────┴───────────┬────────────┘
          │                   │                   │
          └───────────┬───────┘                   │
                      ▼                           ▼
          ┌───────────────────────────────────────────────┐
          │         SUPABASE EDGE FUNCTION                │
          │         (s3-data-loader)                      │
          │  - Authenticates with S3/ADLS2                │
          │  - Reads Parquet/CSV/JSON files               │
          │  - Validates data quality                     │
          │  - Loads into Bronze layer                    │
          └─────────────────┬─────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    MEDALLION ARCHITECTURE                    │
├───────────────────────────────────────────────────────────── │
│  BRONZE LAYER (Raw)                                          │
│  - scout.bronze_transactions                                 │
│  - Stores raw data with metadata                            │
│  - No transformations, keeps original format                │
├───────────────────────────────────────────────────────────── │
│  SILVER LAYER (Cleaned)                                      │
│  - scout.silver_transactions                                 │
│  - Data type conversions                                    │
│  - Validation and quality checks                            │
│  - Deduplication                                            │
├───────────────────────────────────────────────────────────── │
│  GOLD LAYER (Business-Ready)                                 │
│  - scout.scout_gold_transactions                            │
│  - scout.scout_gold_transaction_items                       │
│  - Aggregated and enriched                                  │
│  - Ready for dashboard consumption                          │
├───────────────────────────────────────────────────────────── │
│  PLATINUM LAYER (Analytics)                                  │
│  - scout.platinum_monitors                                  │
│  - Advanced analytics and ML features                       │
└─────────────────────────────────────────────────────────────┘
```

## Key Changes with S3/ADLS2 Storage

### 1. **Data Source Management**

**Before (Direct Database):**
```sql
INSERT INTO scout_gold_transactions 
VALUES (...) 
-- Data directly inserted
```

**After (S3/ADLS2):**
```typescript
// Data flows through stages
S3 Bucket → Bronze Layer → Silver Layer → Gold Layer
```

### 2. **Environment Separation**

```sql
-- Storage Configuration
Development: s3://scout-sample-data/samples/
Staging:     s3://scout-staging-data/staging/
Production:  s3://scout-production-data/prod/
```

### 3. **Data Formats Supported**

- **Parquet** (Recommended): Columnar format, best compression
- **Delta Lake**: ACID transactions, time travel
- **CSV**: Simple, human-readable
- **JSON**: Flexible schema
- **Avro**: Schema evolution support

### 4. **ETL Pipeline Steps**

#### Step 1: External Storage → Bronze
```typescript
// Edge Function reads from S3
const s3Client = new S3Client({...})
const data = await s3Client.send(new GetObjectCommand({
  Bucket: 'scout-sample-data',
  Key: 'transactions/2024/01/data.parquet'
}))

// Insert raw data into Bronze
INSERT INTO scout.bronze_transactions (_raw_data, _source_file)
```

#### Step 2: Bronze → Silver (Cleaning)
```sql
-- Process Bronze to Silver
INSERT INTO scout.silver_transactions
SELECT 
  transaction_id,
  CAST(timestamp AS TIMESTAMPTZ),  -- Type conversion
  CAST(total_amount AS NUMERIC),    -- Validation
  COALESCE(payment_method, 'cash')  -- Default values
FROM scout.bronze_transactions
WHERE _raw_id NOT IN (processed)
```

#### Step 3: Silver → Gold (Business Logic)
```sql
-- Process Silver to Gold
INSERT INTO scout.scout_gold_transactions
SELECT 
  transaction_id,
  store_id,
  transaction_timestamp,
  total_amount,
  -- Business calculations
  CASE 
    WHEN total_amount > 1000 THEN 'high_value'
    ELSE 'standard'
  END as transaction_type
FROM scout.silver_transactions
WHERE is_valid = true
```

## Benefits of S3/ADLS2 Architecture

### 1. **Scalability**
- Store unlimited data in S3/ADLS2
- Pay only for what you store
- No database size limitations

### 2. **Cost Optimization**
- S3 Glacier for archival: $0.004/GB/month
- Intelligent tiering: Automatic cost optimization
- Reduced database storage costs

### 3. **Data Lake Benefits**
- Keep raw data forever
- Reprocess historical data when needed
- Support multiple formats simultaneously

### 4. **Environment Isolation**
```yaml
Development:
  - Uses sample data bucket
  - No production data access
  - Safe for testing

Production:
  - Separate bucket with encryption
  - Access controls via IAM
  - Audit logging enabled
```

## Implementation Guide

### 1. Setup S3 Buckets

```bash
# Create buckets
aws s3 mb s3://scout-sample-data
aws s3 mb s3://scout-production-data

# Set lifecycle policies
aws s3api put-bucket-lifecycle-configuration \
  --bucket scout-production-data \
  --lifecycle-configuration file://lifecycle.json
```

### 2. Configure Storage in Database

```sql
-- Add storage configuration
INSERT INTO scout.external_storage_config (
  environment, 
  storage_type, 
  s3_bucket,
  s3_access_key_id,
  s3_secret_access_key
) VALUES (
  'production',
  's3',
  'scout-production-data',
  encrypt('YOUR_ACCESS_KEY'),
  encrypt('YOUR_SECRET_KEY')
);
```

### 3. Deploy Edge Function

```bash
# Deploy the S3 data loader
supabase functions deploy s3-data-loader \
  --project-ref YOUR_PROJECT_REF
```

### 4. Schedule ETL Jobs

```sql
-- Create scheduled job for daily load
INSERT INTO scout.etl_pipelines (
  pipeline_name,
  source_path_pattern,
  schedule_cron
) VALUES (
  'daily_transaction_load',
  'transactions/dt={date}/*.parquet',
  '0 2 * * *'  -- 2 AM daily
);
```

## Data Flow Example

### Sample Data Structure in S3:
```
s3://scout-sample-data/
├── samples/
│   ├── transactions/
│   │   ├── 2024/
│   │   │   ├── 01/
│   │   │   │   ├── 01/
│   │   │   │   │   └── data.parquet
│   │   │   │   ├── 02/
│   │   │   │   │   └── data.parquet
│   ├── items/
│   │   └── 2024/
│   └── customers/
│       └── segments.parquet
```

### Production Data Structure:
```
s3://scout-production-data/
├── prod/
│   ├── transactions/
│   │   ├── dt=2024-01-15/
│   │   │   ├── part-00000.parquet
│   │   │   ├── part-00001.parquet
│   │   │   └── _SUCCESS
│   ├── incremental/
│   │   └── hour=2024-01-15-14/
│   └── archive/
│       └── 2023/
```

## Monitoring & Observability

### ETL Job Monitoring
```sql
-- Check ETL job status
SELECT 
  pipeline_name,
  status,
  records_processed,
  duration_seconds,
  error_message
FROM scout.etl_monitoring
WHERE started_at >= CURRENT_DATE
ORDER BY started_at DESC;
```

### Data Quality Checks
```sql
-- Monitor data quality
SELECT 
  layer,
  COUNT(*) as record_count,
  AVG(data_quality_score) as avg_quality
FROM scout.data_lake_registry
GROUP BY layer;
```

## Cost Comparison

### Traditional Database Storage:
- Database storage: $0.13/GB/month
- 1TB monthly cost: $130
- Performance degradation with size

### S3-Based Architecture:
- S3 Standard: $0.023/GB/month
- S3 Infrequent Access: $0.0125/GB/month
- S3 Glacier: $0.004/GB/month
- 1TB monthly cost: $23 (Standard) or $4 (Glacier)

## Security Considerations

1. **Encryption**
   - S3 server-side encryption (SSE-S3)
   - Customer-managed keys (SSE-KMS)
   - Client-side encryption for sensitive data

2. **Access Control**
   - IAM roles for Edge Functions
   - Bucket policies for least privilege
   - VPC endpoints for private connectivity

3. **Audit Logging**
   - CloudTrail for S3 access logs
   - Supabase audit logs for data access
   - ETL job history tracking

## Migration Path

### Phase 1: Development (Week 1)
- Setup sample data bucket
- Deploy Edge Functions
- Test with sample data

### Phase 2: Staging (Week 2)
- Mirror production data structure
- Performance testing
- Data quality validation

### Phase 3: Production (Week 3-4)
- Gradual migration of historical data
- Parallel run with existing system
- Cutover and monitoring

## Conclusion

Using S3/ADLS2 as the primary data source provides:
- **10x cost reduction** for data storage
- **Unlimited scalability**
- **Better data governance** with clear layer separation
- **Flexibility** to reprocess historical data
- **Environment isolation** for safer development

The Scout Dashboard can now handle enterprise-scale data while maintaining low operational costs and high performance.
