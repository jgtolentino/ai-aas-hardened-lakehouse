# Scout Sari-sari Intelligence Platform

Production-grade data platform for real-time sari-sari store transaction analytics with exact field mappings and dashboard requirements.

## 🚀 New: Scout Databank Dashboard & MCP Integration

- **Scout Databank**: Advanced analytics dashboard integrated as git submodule at `platform/scout/scout-databank/`
- **MCP Servers**: Playwright and Puppeteer automation configured for testing
- **AI Reasoning**: Comprehensive tracking and monitoring system
- See [MCP_CONFIGURATION.md](MCP_CONFIGURATION.md) for details

## 📊 Data Contract

Every transaction MUST include these fields (immutable API contract):

### Core Transaction Data
- `id`: Unique transaction identifier
- `store_id`: Store identifier
- `timestamp`: UTC ISO-8601 datetime
- `location`: Object with barangay, city, province, region

### Product Information
- `product_category`: Category classification
- `brand_name`: Brand of primary product
- `sku`: Stock keeping unit
- `units_per_transaction`: Quantity sold
- `peso_value`: Transaction value (computed if missing)
- `basket_size`: Total items in basket
- `combo_basket`: Array of {sku, quantity}

### Counter Interaction
- `request_mode`: verbal/pointing/indirect
- `request_type`: branded/unbranded/point/indirect
- `suggestion_accepted`: boolean

### Demographics & Dynamics
- `gender`: male/female/unknown
- `age_bracket`: 18-24/25-34/35-44/45-54/55+/unknown
- `substitution_event`: {occurred, from_sku, to_sku, reason}
- `duration_seconds`: Transaction duration
- `campaign_influenced`: boolean
- `handshake_score`: 0-1 engagement score

### Commerce Context
- `is_tbwa_client`: boolean
- `payment_method`: cash/gcash/maya/credit/other
- `customer_type`: regular/occasional/new/unknown
- `store_type`: urban_high/urban_medium/residential/rural/transport/other
- `economic_class`: A/B/C/D/E/unknown

## 🏗️ Architecture

### Data Layers
1. **Bronze**: Raw ingestion (append-only)
2. **Silver**: Validated, typed, constraints enforced
3. **Gold**: Business intelligence views/MVs
4. **Platinum**: ML feature store

### Technology Stack
- **OLTP**: Supabase PostgreSQL
- **Ingestion**: Edge Functions with Zod validation
- **Quality**: Great Expectations + SQL checks
- **Visualization**: Apache Superset
- **Testing**: Bruno API collections

## 🚀 Quick Start

### 1. Apply Migrations
```bash
# Run in Supabase SQL Editor in order:
platform/scout/migrations/001_scout_enums_dims.sql
platform/scout/migrations/002_scout_bronze_silver.sql
platform/scout/migrations/003_scout_gold_views.sql
platform/scout/migrations/004_scout_platinum_features.sql
```

### 2. Deploy Edge Function
```bash
supabase functions deploy ingest-transaction \
  --no-verify-jwt \
  --import-map platform/scout/functions/import_map.json
```

### 3. Import Superset Dashboard
```bash
superset import-dashboards -p platform/scout/superset/scout_dashboard.yaml
```

### 4. Schedule Refreshes
```sql
-- Enable pg_cron
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Refresh Gold views every 5 minutes
SELECT cron.schedule('refresh-scout-gold', '*/5 * * * *', 
  'SELECT scout.refresh_gold_views()');

-- Refresh Platinum features every hour
SELECT cron.schedule('refresh-scout-platinum', '0 * * * *', 
  'SELECT scout.refresh_platinum_features()');
```

## 📈 Dashboard Sections

### 1. Transaction Trends
- Daily revenue trend by region
- Time of day heatmap
- Geographic performance map

### 2. Product Mix & SKU Analysis
- Top 20 SKUs by revenue
- Category distribution pie chart
- Pareto analysis (80/20 rule)

### 3. Basket & Substitution Analysis
- Co-occurrence Sankey diagram
- Basket size distribution
- Substitution flow visualization

### 4. Consumer Behavior
- Request mode sunburst
- Suggestion acceptance rates
- Interaction duration analysis

### 5. Consumer Profiling
- Demographics treemap
- Age/gender distributions
- Economic class breakdown

### 6. AI Recommendations Panel
- Momentum tracking (high/growing/stable/declining)
- Substitution insights
- Stock optimization alerts

## 🧪 Testing

### Run Bruno Tests
```bash
cd platform/scout/bruno
bruno run --env development
```

### Test Scenarios
1. Valid single transaction
2. Transaction with substitution
3. Batch transactions
4. Missing required fields (should fail)
5. Basket size mismatch (warning)

## 📊 Data Quality

### Automated Checks
- **Schema validation**: Zod in Edge Function
- **Consistency checks**: Basket size, substitution completeness
- **Reasonableness**: Price bounds, duration limits
- **Freshness**: Alert if no data >1 hour

### SQL Quality Queries
```sql
-- Run monitoring view
SELECT * FROM scout.v_data_quality_metrics;

-- Check for issues
SELECT * FROM scout.data_quality_issues 
WHERE severity = 'error' 
AND created_at >= CURRENT_DATE;
```

### Great Expectations
```bash
# Run daily checkpoint
great_expectations checkpoint run daily_quality_check
```

## 🔧 Performance Optimization

### Indexes Applied
- Time-based: `btree(ts)`, `(store_id, ts)`, `(region, ts)`
- Geographic: `(barangay, ts)`, `(city, ts)`
- Product: `(category, ts)`, `(brand_name, ts)`
- Basket analysis: `gin(combo_basket)` if array type used
- Substitution: `(from_sku, to_sku)`

### Partitioning Strategy
When volume exceeds 10M rows:
```sql
-- Convert to partitioned table
ALTER TABLE scout.silver_transactions 
PARTITION BY RANGE (date_trunc('month', ts));
```

## 🔒 Security

### Row Level Security
```sql
-- Enable RLS
ALTER TABLE scout.silver_transactions ENABLE ROW LEVEL SECURITY;

-- Policy example for multi-tenant
CREATE POLICY tenant_isolation ON scout.silver_transactions
FOR ALL USING (tenant_id = current_setting('app.tenant_id'));
```

### API Authentication
- Edge Functions use Supabase Auth
- Service role key for ingestion only
- Anon key for read operations

## 📈 SLOs

- **Query Performance**: p95 < 2s for Gold views
- **Ingestion Latency**: < 10s end-to-end
- **Data Freshness**: < 5 min for materialized views
- **Availability**: 99.9% uptime for API

## 🚨 Monitoring & Alerts

### Key Metrics
- Minutes since last transaction
- Daily transaction count
- Active stores count
- Error/warning count
- Data completeness %

### Alert Thresholds
- No data > 1 hour: CRITICAL
- Error rate > 5%: HIGH
- MV refresh failure: MEDIUM
- Slow queries > 5s: LOW

## 📚 Additional Resources

- [Supabase Docs](https://supabase.com/docs)
- [Superset User Guide](https://superset.apache.org/docs/intro)
- [Great Expectations](https://greatexpectations.io/)