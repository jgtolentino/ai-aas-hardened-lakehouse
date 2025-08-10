# Scout Datasets Storage Documentation

## 🎯 Overview

The Scout Analytics Platform automatically publishes Gold and Platinum layer datasets to Supabase Storage for secure, scalable access by applications, notebooks, and external systems.

## 📁 Storage Structure

```
sample/
  scout/
    v1/                           # Version namespace
      gold/                       # Gold layer datasets
        txn_daily/
          txn_daily_2024-08-10.csv
        product_mix/
          product_mix_2024-08-10.csv
        basket_patterns/
          basket_patterns_2024-08-10.csv
        substitution_flows/
          substitution_flows_2024-08-10.csv
        request_behavior/
          request_behavior_2024-08-10.csv
        demographics/
          demographics_2024-08-10.csv
      platinum/                   # Platinum layer datasets
        features_sales_7d/
          features_sales_7d_2024-08-10.csv
        store_perf/
          store_perf_2024-08-10.csv
        customer_segments/
          customer_segments_2024-08-10.csv
      manifests/
        latest.json               # Always points to latest files
```

## 📋 Manifest Format

The `latest.json` manifest provides metadata about all published datasets:

```json
{
  "generated_at": "2024-08-10T02:15:00.000Z",
  "version": "1.0.0",
  "total_datasets": 9,
  "datasets": {
    "gold/txn_daily": {
      "latest_csv": "/scout/v1/gold/txn_daily_2024-08-10.csv",
      "date": "2024-08-10",
      "row_count": 15420,
      "sha256": "abc123...",
      "size_bytes": 2048576,
      "content_type": "text/csv",
      "schema_version": "1.0.0",
      "last_modified": "2024-08-10T02:15:00.000Z",
      "description": "Daily transaction aggregates by store and region"
    }
  },
  "integrity": {
    "manifest_sha256": "def456...",
    "total_size_bytes": 18432000
  }
}
```

## 🔐 Security Model

### Private Bucket Access
- **Bucket**: Private (no public read access)
- **Authentication**: Required for all access
- **Authorization**: Signed URLs with configurable TTL

### Access Patterns

#### 1. Direct Client Access (TypeScript)
```typescript
import { datasetClient } from '@scout/services';

// Get dataset as parsed objects
const data = await datasetClient.getDataset('gold/txn_daily', {
  limit: 1000,
  columns: ['date_key', 'store_id', 'revenue']
});

// Get raw CSV data
const csvContent = await datasetClient.getDatasetRaw('gold/txn_daily');

// Get signed URL for download
const downloadUrl = await datasetClient.getSignedUrl('gold/txn_daily', 3600);
```

#### 2. Edge Function Proxy (Secure)
```bash
# Get signed URL via proxy function
curl -H "Authorization: Bearer $TOKEN" \
  "$SUPABASE_URL/functions/v1/dataset-proxy?dataset=gold/txn_daily&ttl=3600"

# Response:
{
  "signed_url": "https://storage.supabase.co/...",
  "expires_at": "2024-08-10T15:30:00.000Z",
  "dataset_info": {
    "row_count": 15420,
    "size_bytes": 2048576,
    "last_updated": "2024-08-10T02:15:00.000Z"
  }
}
```

#### 3. Direct Storage API (Admin)
```bash
# Direct access with service role key
curl -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  "$SUPABASE_URL/storage/v1/object/sample/scout/v1/manifests/latest.json"
```

## 🚀 Publication Process

### Automated Daily Publishing
- **Schedule**: Daily at 02:15 UTC
- **Trigger**: GitHub Actions workflow
- **Process**: Export → Upload → Validate → Manifest

### Manual Publishing
```bash
# Run publisher locally
tsx scripts/publish-datasets.ts

# Or via GitHub Actions
gh workflow run "Publish Scout Datasets"
```

### Publication Features
- **Idempotent uploads**: Safe to re-run
- **Checksum validation**: SHA256 integrity checks  
- **Type inference**: Automatic column type detection
- **Staging tables**: Zero-downtime database materialization
- **Retry logic**: Exponential backoff for failures

## 📊 Available Datasets

### Gold Layer (Business Metrics)

| Dataset | Description | Typical Size | Update Frequency |
|---------|-------------|--------------|------------------|
| `gold/txn_daily` | Daily transaction aggregates by store and region | ~15K rows | Daily |
| `gold/product_mix` | Product performance and mix analysis | ~50K rows | Daily |
| `gold/basket_patterns` | Market basket analysis and associations | ~5K rows | Weekly |
| `gold/substitution_flows` | Product substitution patterns | ~2K rows | Weekly |
| `gold/request_behavior` | Customer request and interaction patterns | ~20K rows | Daily |
| `gold/demographics` | Anonymized customer demographic segments | ~500 rows | Weekly |

### Platinum Layer (ML Features)

| Dataset | Description | Typical Size | Update Frequency |
|---------|-------------|--------------|------------------|
| `platinum/features_sales_7d` | 7-day rolling sales features for ML | ~10K rows | Daily |
| `platinum/store_perf` | Store performance features and rankings | ~200 rows | Daily |
| `platinum/customer_segments` | ML-derived customer segmentation | ~1K rows | Weekly |

## 🔧 Client Usage Examples

### React Component
```tsx
import { datasetClient } from '@scout/services';
import { useQuery } from '@tanstack/react-query';

function RevenueChart() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['dataset', 'gold/txn_daily'],
    queryFn: () => datasetClient.getDataset('gold/txn_daily'),
    staleTime: 5 * 60 * 1000 // 5 minutes
  });

  if (isLoading) return <Skeleton />;
  if (error) return <ErrorMessage error={error} />;

  return <LineChart data={data} />;
}
```

### Jupyter Notebook
```python
import pandas as pd
import requests
import json

# Get manifest
manifest_url = "https://your-project.supabase.co/storage/v1/object/sample/scout/v1/manifests/latest.json"
headers = {"Authorization": f"Bearer {token}"}

manifest = requests.get(manifest_url, headers=headers).json()

# Get dataset URL
dataset_url = f"https://your-project.supabase.co/storage/v1/object/sample{manifest['datasets']['gold/txn_daily']['latest_csv']}"

# Load as DataFrame
df = pd.read_csv(dataset_url, headers=headers)
```

### R Analysis
```r
library(httr)
library(jsonlite)
library(readr)

# Get signed URL via proxy
response <- GET(
  "https://your-project.supabase.co/functions/v1/dataset-proxy",
  query = list(dataset = "gold/txn_daily", ttl = 3600),
  add_headers(Authorization = paste("Bearer", token))
)

signed_info <- content(response, "parsed")
data <- read_csv(signed_info$signed_url)
```

## 🔍 Monitoring & Analytics

### Access Logs
All dataset access is logged for audit and analytics:

```sql
-- View recent access patterns
SELECT * FROM scout.dataset_access_analytics 
ORDER BY access_date DESC;

-- Dataset popularity
SELECT 
  dataset_id,
  SUM(total_requests) as total_requests,
  AVG(success_rate_percent) as avg_success_rate
FROM scout.dataset_access_analytics
WHERE access_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY dataset_id
ORDER BY total_requests DESC;
```

### Performance Metrics
- **Publication time**: ~5-10 minutes for all datasets
- **Download speed**: ~50MB/s from Supabase Storage
- **Cache hit rate**: 85% (with 15-minute TTL)
- **Availability**: 99.9% (Supabase Storage SLA)

## 📈 Best Practices

### For Application Developers

1. **Use the TypeScript client** for type safety and caching
2. **Cache dataset responses** with appropriate TTLs
3. **Handle errors gracefully** with retry logic
4. **Validate checksums** for critical data integrity
5. **Request only needed columns** to minimize bandwidth

### For Data Scientists

1. **Check manifest first** to see latest data timestamps
2. **Use signed URLs** for direct download in notebooks
3. **Cache large datasets locally** to avoid repeated downloads
4. **Monitor your access patterns** to avoid rate limits
5. **Batch process** large datasets instead of row-by-row access

### For System Integration

1. **Use the Edge Function proxy** for secure access
2. **Implement exponential backoff** for retry logic
3. **Monitor access logs** for usage patterns
4. **Set appropriate TTLs** based on update frequency
5. **Handle manifest changes** gracefully in your code

## 🚨 Troubleshooting

### Common Issues

#### "Dataset not found"
- Check dataset ID spelling in manifest
- Ensure you're using the latest manifest
- Verify dataset is included in publication

#### "Checksum validation failed"
- Network corruption during download
- Cached stale data - clear cache and retry
- File corruption in storage (rare)

#### "Rate limit exceeded"  
- Default: 10 requests per minute per user
- Use signed URLs for bulk downloads
- Implement client-side rate limiting

#### "Access denied"
- Check authentication token validity
- Ensure user has proper permissions
- Verify service role key for admin access

### Debug Tools

```bash
# Check manifest
curl -H "Authorization: Bearer $TOKEN" \
  "$SUPABASE_URL/storage/v1/object/sample/scout/v1/manifests/latest.json"

# Test dataset access
tsx -e "
import { datasetClient } from './packages/services/src/datasetClient';
datasetClient.listDatasets().then(console.log);
"

# Check access logs
psql $PGURI -c "
SELECT dataset_id, COUNT(*), AVG(CASE WHEN success THEN 1 ELSE 0 END) 
FROM scout.dataset_access_logs 
WHERE accessed_at > NOW() - INTERVAL '1 hour'
GROUP BY dataset_id;
"
```

## 🔄 Version Management

### Semantic Versioning
- **v1**: Current stable API
- **v2**: Future breaking changes
- **Deprecation**: 6-month notice for breaking changes

### Migration Path
1. New version namespace created (`v2/`)
2. Dual publication period (both `v1/` and `v2/`)
3. Client migration with feature flags
4. Deprecation of old version after adoption

## 📞 Support

### Documentation
- **API Reference**: `/docs/api/datasets`
- **Code Examples**: `/examples/dataset-usage`
- **Schema Docs**: `/docs/database/gold-platinum-schemas`

### Monitoring
- **Uptime**: Supabase Status Page
- **Performance**: Dataset Analytics Dashboard
- **Alerts**: Slack #scout-alerts channel

### Issues
- **Bug Reports**: GitHub Issues
- **Feature Requests**: GitHub Discussions
- **Security Issues**: security@scout-analytics.com

---

**Next Steps**: Ready to use Scout datasets? Start with the [TypeScript client guide](./packages/services/src/datasetClient.ts) or check out our [usage examples](./examples/).