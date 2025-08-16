# Scout Edge SKU Scraper Operations Guide

## Overview

Production-grade web scraping infrastructure for Scout's master catalog, featuring:
- Queue-based architecture with domain rate limiting
- Exponential backoff for transient failures
- Poison queue quarantine after 6 attempts
- Real-time health monitoring dashboard
- Operational kill-switches
- Automated recrawl scheduling

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Source    │     │   Scraping   │     │    Page     │
│  Registry   │────▶│    Jobs      │────▶│   Cache     │
└─────────────┘     └──────────────┘     └─────────────┘
                            │                     │
                            ▼                     ▼
                    ┌──────────────┐     ┌─────────────┐
                    │    Worker    │     │   Master    │
                    │   Process    │────▶│   Items     │
                    └──────────────┘     └─────────────┘
                            │
                            ▼
                    ┌──────────────┐
                    │ Isko-Scraper │
                    │ Edge Function│
                    └──────────────┘
```

## Quick Start

```bash
# 1. Set environment
export POSTGRES_URL="postgresql://user:pass@host/db"
export SUPABASE_PROJECT_REF="your-project-ref"

# 2. Deploy
./scripts/deploy-scraper.sh

# 3. Start workers (separate terminals)
make worker  # Terminal 1
make worker  # Terminal 2
make worker  # Terminal 3

# 4. Monitor
make scraper-status
```

## Operations Playbook

### Daily Operations

#### Morning Check (9 AM)
```sql
-- Check overnight performance
SELECT * FROM scout.dashboard_snapshot();

-- Review blocked jobs
SELECT * FROM scout.v_blocked_jobs LIMIT 20;

-- Check content churn
SELECT * FROM scout.v_content_churn 
WHERE churn_level = 'high' LIMIT 10;
```

#### Midday Review (2 PM)
```sql
-- Domain performance
SELECT * FROM scout.v_domain_performance 
WHERE failed > 10 OR blocked > 5;

-- Items ingested
SELECT * FROM scout.v_master_items_recent LIMIT 20;
```

### Common Tasks

#### Handle Rate Limiting
```sql
-- Throttle aggressive domain to 1 request/minute
SELECT scout.throttle_domain('problematic.com', 60000);

-- Check throttled domains
SELECT * FROM scout.v_operational_status;
```

#### Investigate Failed Jobs
```sql
-- Find pattern in failures
SELECT url, attempts, note 
FROM scout.scraping_jobs 
WHERE status='failed' 
  AND note LIKE '%429%'
ORDER BY locked_at DESC;

-- Inspect specific job
SELECT * FROM scout.inspect_job(12345);
```

#### Emergency Response
```sql
-- Stop everything immediately
SELECT scout.emergency_stop();

-- Quarantine problematic source
SELECT scout.quarantine_source('source-uuid-here', 'investigating issues');

-- Release after fix
SELECT scout.release_quarantine('source-uuid-here');
```

### Performance Tuning

#### Worker Scaling
- Start with workers = min(domain_count, 4)
- Add workers if q_depth > 1000 consistently
- Remove workers if q_running < worker_count/2

#### Rate Limiting
```sql
-- Default: 1.5 seconds between requests
UPDATE scout.domain_state SET rate_limit_ms = 1500;

-- Slow site: 5 seconds
UPDATE scout.domain_state SET rate_limit_ms = 5000 WHERE domain = 'slow.com';

-- Fast API: 500ms
UPDATE scout.domain_state SET rate_limit_ms = 500 WHERE domain = 'api.fast.com';
```

### Monitoring Alerts

Set up alerts when:

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| q_depth | > 5000 | > 10000 | Add workers |
| q_blocked | > 50 | > 100 | Review poison queue |
| pages/hour | < 10 | 0 | Check workers |
| items/hour | < 5 | 0 | Check extractors |
| avg_job_time | > 15s | > 30s | Check network/sites |

### Troubleshooting

#### No Jobs Processing
1. Check workers running: `ps aux | grep worker`
2. Check queue: `SELECT * FROM scout.v_queue_pressure`
3. Check locks: `SELECT * FROM scout.scraping_jobs WHERE status='running'`

#### High Failure Rate
1. Check error patterns: `SELECT note, COUNT(*) FROM scout.scraping_jobs WHERE status='failed' GROUP BY note`
2. Check domain issues: `SELECT * FROM scout.v_domain_performance WHERE failed > 10`
3. Test edge function: `curl -X POST $ISKO_URL -d '{"url":"test.com"}'`

#### Duplicate Items
1. Check dedup constraint: `\d scout.master_items`
2. Review normalizers in edge function
3. Check for dynamic URLs with session IDs

### Maintenance

#### Weekly Tasks
```sql
-- Review quarantined jobs
SELECT source_id, COUNT(*) 
FROM scout.scraping_jobs 
WHERE status='blocked' 
GROUP BY source_id;

-- Check stale data
SELECT url, MAX(fetched_at) as last_fetch
FROM scout.page_cache
GROUP BY url
HAVING MAX(fetched_at) < NOW() - INTERVAL '7 days';
```

#### Monthly Tasks
```sql
-- Cleanup old jobs (automatic via cron)
SELECT scout.cleanup_old_jobs();

-- Analyze scraping patterns
SELECT 
  DATE_TRUNC('day', created_at) as day,
  COUNT(*) as jobs_created,
  COUNT(*) FILTER (WHERE status='done') as completed,
  AVG(attempts) as avg_attempts
FROM scout.scraping_jobs
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY 1
ORDER BY 1;
```

## Advanced Configuration

### Custom Extractors

Add domain-specific extractors in `isko-scraper/index.ts`:

```typescript
function extractItems(html: string, url: string): any[] {
  const domain = new URL(url).hostname;
  
  switch(domain) {
    case 'unimart.ph':
      return extractUnimartItems(html);
    case 'robinsons.ph':
      return extractRobinsonsItems(html);
    default:
      return extractGenericItems(html);
  }
}
```

### Selector Packs

Store in source_registry.selectors:
```json
{
  "start": ["https://store.com/products"],
  "product_title": "h1.product-name",
  "product_price": "span.price-now",
  "product_brand": "a.brand-link",
  "pack_size": "span.size-info"
}
```

## Metrics & KPIs

Track these weekly:

1. **Coverage**: Total unique products in master_items
2. **Freshness**: % of items updated in last 7 days  
3. **Quality**: % of items with all fields populated
4. **Efficiency**: Pages fetched per worker hour
5. **Reliability**: Success rate (done / total jobs)

```sql
-- Weekly KPI Report
WITH stats AS (
  SELECT
    COUNT(DISTINCT url) as unique_products,
    COUNT(*) FILTER (WHERE observed_at > NOW() - INTERVAL '7 days') as fresh_items,
    COUNT(*) FILTER (WHERE brand_name IS NOT NULL 
                      AND product_name IS NOT NULL 
                      AND list_price IS NOT NULL) as complete_items,
    COUNT(*) as total_items
  FROM scout.master_items
)
SELECT
  unique_products as "Unique Products",
  ROUND(100.0 * fresh_items / NULLIF(total_items, 0), 1) as "Freshness %",
  ROUND(100.0 * complete_items / NULLIF(total_items, 0), 1) as "Quality %"
FROM stats;
```

## Security Notes

1. **Never expose service_role key** - Use anon key for workers
2. **Validate all URLs** before enqueueing
3. **Respect robots.txt** - Implement scout.robots_allowed()
4. **Log all operations** for audit trail
5. **Rate limit by IP** if running distributed workers

## Integration Points

- **Brand Resolution**: Items flow to scout.resolve_brand() 
- **Quality Monitoring**: Failed extractions trigger alerts
- **Gold Tables**: Clean items populate scout_gold_* tables
- **Analytics**: Fresh catalog data powers insights

Remember: This system is designed to be self-healing. Let exponential backoff handle transients, and only intervene for systematic issues.