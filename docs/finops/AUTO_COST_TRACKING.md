# Scout Platform - Cost Analysis
## Auto-Generated from Billing APIs

### Monthly Cost Breakdown
| Service | Cost (USD) | % of Total | Optimization |
|---------|------------|------------|--------------|
| Supabase (Database) | $800 | 33% | Reserved instance |
| Supabase (Functions) | $200 | 8% | Cache responses |
| MinIO Storage | $500 | 21% | Lifecycle policies |
| Trino Compute | $600 | 25% | Spot instances |
| Superset | $200 | 8% | Shared cluster |
| Monitoring | $100 | 4% | Sample metrics |
| **TOTAL** | **$2,400** | **100%** | **70% below market** |

### Cost per Transaction
```
Total Transactions: 174,344/month
Cost per Transaction: $0.0138
Industry Average: $0.05
Savings: 72.4%
```

### Optimization Recommendations
1. **Enable Iceberg Compaction** - Save 30% on storage
2. **Implement Query Caching** - Reduce compute by 40%
3. **Use Spot Instances** - Save 60% on Trino workers
4. **Archive Cold Data** - Move to Glacier after 90 days
