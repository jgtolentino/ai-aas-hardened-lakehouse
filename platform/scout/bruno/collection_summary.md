# Scout Analytics Bruno Test Collection

This collection provides comprehensive API testing for the Scout Analytics platform, including the new choropleth visualization features.

## Test Organization

Tests are numbered sequentially for proper execution order:

### 01-02: Authentication & Setup
- `01_auth.bru` - Supabase authentication
- `02_health.bru` - API health check

### 03-10: Core Data APIs
- `03_stores_list.bru` - Store listing
- `04_metrics_daily.bru` - Daily metrics retrieval
- `05_metrics_aggregate.bru` - Aggregated metrics
- `06_campaign_effectiveness.bru` - Campaign analysis
- `07_customer_insights.bru` - Customer behavior
- `08_store_performance.bru` - Store performance
- `09_regional_analysis.bru` - Regional breakdown
- `10_product_category.bru` - Product analysis

### 11-14: Data Ingestion
- `11_ingest_transaction.bru` - Transaction ingestion
- `12_ingest_campaign.bru` - Campaign data ingestion
- `13_ingest_bulk.bru` - Bulk data ingestion
- `14_ingest_validation.bru` - Ingestion validation

### 15-18: Superset Integration
- `15_superset_login.bru` - Superset authentication
- `16_superset_csrf.bru` - CSRF token retrieval
- `17_superset_dashboards.bru` - Dashboard access
- `18_superset_cache_warm.bru` - Cache warming

### 19: Security Tests
- `19_rls_negative.bru` - Row-level security validation

### 20-21: Choropleth Tests (NEW)
- `20_choropleth_smoke.bru` - Verify choropleth charts exist
- `21_mapbox_verify.bru` - Validate Mapbox configuration

## Running Tests

### Quick Start
```bash
# Run all tests with staging environment
bruno run platform/scout/bruno --env staging

# Run all tests with production environment
bruno run platform/scout/bruno --env production
```

### Using the Test Runner Script
```bash
# Run with default staging environment
./scripts/run_bruno_tests.sh

# Run with production environment
BRUNO_ENV=production ./scripts/run_bruno_tests.sh

# Run with JSON output for analysis
OUTPUT_FORMAT=json ./scripts/run_bruno_tests.sh

# Stop on first failure
FAIL_FAST=true ./scripts/run_bruno_tests.sh
```

### Run Specific Test Groups
```bash
# Authentication only
bruno run platform/scout/bruno --env staging --only "0[12]_*.bru"

# Choropleth tests only
bruno run platform/scout/bruno --env staging --only "2[01]_*.bru"

# Security tests only
bruno run platform/scout/bruno --env staging --only "19_*.bru"
```

## Environment Configuration

### Required Variables

Update `environments/production.bru` with your values:

```javascript
vars {
  // Supabase
  SUPABASE_URL: https://your-project.supabase.co
  SUPABASE_ANON_KEY: your_anon_key
  SUPABASE_SERVICE_KEY: your_service_key
  
  // Superset
  SUPERSET_BASE: https://superset.your-domain.com
  SUPERSET_USERNAME: admin
  SUPERSET_PASSWORD: your_password
  
  // Database (optional, for direct SQL tests)
  SCOUT_DB_HOST: your-db-host
  SCOUT_DB_PORT: 5432
  SCOUT_DB_NAME: scout_analytics
  SCOUT_DB_USER: scout_viewer
  SCOUT_DB_PASSWORD: your_db_password
}
```

## Test Coverage

### API Endpoints Tested
- ✅ `/auth/v1/token` - Authentication
- ✅ `/rest/v1/rpc/*` - RPC functions
- ✅ `/rest/v1/stores` - Store data
- ✅ `/rest/v1/metrics_*` - Various metric endpoints
- ✅ `/api/v1/security/login` - Superset login
- ✅ `/api/v1/chart/` - Superset charts
- ✅ `/api/v1/dashboard/` - Superset dashboards

### Features Validated
- ✅ Authentication flow
- ✅ Data retrieval accuracy
- ✅ Aggregation correctness
- ✅ Ingestion idempotency
- ✅ Row-level security
- ✅ Superset integration
- ✅ Choropleth visualization
- ✅ Mapbox configuration

### Performance Checks
- API response time < 1000ms (configurable)
- Query response time < 1500ms (configurable)
- Choropleth load time < 2500ms (configurable)

## CI/CD Integration

### GitHub Actions
```yaml
- name: Run Bruno Tests
  run: |
    npm install -g @usebruno/cli
    BRUNO_ENV=staging ./scripts/run_bruno_tests.sh
```

### GitLab CI
```yaml
test:bruno:
  script:
    - npm install -g @usebruno/cli
    - BRUNO_ENV=staging OUTPUT_FORMAT=json ./scripts/run_bruno_tests.sh
  artifacts:
    paths:
      - /tmp/bruno_*.json
```

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Check Supabase project is active
   - Verify API keys are correct
   - Ensure service key has proper permissions

2. **Superset Tests Fail**
   - Verify Superset is deployed
   - Check network connectivity
   - Ensure CSRF handling is enabled

3. **Choropleth Tests Fail**
   - Verify PostGIS is enabled
   - Check boundary data is loaded
   - Ensure Mapbox key is configured

### Debug Mode
```bash
# Run with verbose output
bruno run platform/scout/bruno --env staging --verbose

# Check specific test
bruno run platform/scout/bruno --env staging --only "20_choropleth_smoke.bru" --verbose
```

## Maintenance

### Adding New Tests
1. Create `.bru` file with sequential number
2. Follow naming convention: `XX_feature_name.bru`
3. Include proper assertions
4. Update this documentation

### Updating Environments
1. Edit `environments/*.bru` files
2. Never commit production credentials
3. Use environment variables where possible

## Performance Benchmarks

Expected performance (staging environment):
- Authentication: < 200ms
- Data queries: < 500ms
- Aggregations: < 1000ms
- Choropleth load: < 2000ms

Production should be faster due to:
- Better hardware
- Optimized indexes
- Cached queries
- CDN for static assets