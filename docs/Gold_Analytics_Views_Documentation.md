# Scout Analytics Gold Layer Views Documentation

## Overview
The Gold layer views provide business-ready, optimized data structures for the Scout Analytics Dashboard. These views are designed to be directly consumed by the DAL (Data Access Layer) service in the submodule architecture.

## Architecture
```
┌─────────────────────────┐
│   Analytics Dashboard   │
└───────────┬─────────────┘
            │
┌───────────▼─────────────┐
│   DAL Service (SQL)     │
└───────────┬─────────────┘
            │
┌───────────▼─────────────┐
│   Gold Views (10)       │
├─────────────────────────┤
│ • Dashboard KPIs        │
│ • Product Performance   │
│ • Campaign ROI          │
│ • Customer Segments     │
│ • Store Performance     │
│ • Sales Trends          │
│ • Inventory Analysis    │
│ • Category Insights     │
│ • Geographic Summary    │
│ • Time Series Metrics   │
└───────────┬─────────────┘
            │
┌───────────▼─────────────┐
│   Fact & Dimension      │
│   Tables (Star Schema)  │
└─────────────────────────┘
```

## Gold Views Reference

### 1. gold_dashboard_kpis
Executive-level KPIs with growth metrics and inventory status.

**Key Columns:**
- `transaction_count` - Total transactions (30-day)
- `unique_customers` - Distinct customers
- `total_revenue` - Total sales amount
- `revenue_growth_pct` - MoM revenue growth
- `customer_growth_pct` - MoM customer growth
- `total_inventory_value` - Current inventory value
- `low_stock_items` - Products below reorder point

**Usage:**
```sql
SELECT * FROM scout.gold_dashboard_kpis;
```

### 2. gold_product_performance
Product-level analytics with rankings and inventory status.

**Key Columns:**
- `product_id`, `product_name`, `brand`
- `units_sold`, `revenue` - 30-day metrics
- `current_stock`, `inventory_value`
- `revenue_rank`, `volume_rank` - Performance rankings
- `days_of_supply` - Inventory coverage
- `avg_selling_price`, `discount_rate`

**Usage:**
```sql
-- Top 10 products by revenue
SELECT * FROM scout.gold_product_performance 
WHERE revenue_rank <= 10;

-- Low stock products
SELECT * FROM scout.gold_product_performance 
WHERE days_of_supply < 7
ORDER BY revenue_rank;
```

### 3. gold_campaign_effectiveness
Marketing campaign ROI and effectiveness metrics.

**Key Columns:**
- `campaign_id`, `campaign_name`, `campaign_type`
- `revenue_generated`, `customers_reached`
- `roi_percentage` - Return on investment
- `cost_per_customer`, `cost_per_transaction`
- `campaign_status` - Active/Completed/Scheduled

**Usage:**
```sql
-- Best performing campaigns
SELECT * FROM scout.gold_campaign_effectiveness 
WHERE roi_percentage > 100
ORDER BY roi_percentage DESC;
```

### 4. gold_customer_segments
Customer segmentation with lifetime value analysis.

**Key Columns:**
- `customer_id`, `customer_name`, `customer_segment`
- `total_spent`, `transaction_count`
- `recency_status` - Active/At Risk/Dormant/Lost
- `customer_tier` - VIP/High Value/Standard
- `monthly_spend_avg`, `days_since_last_purchase`

**Usage:**
```sql
-- VIP customers
SELECT * FROM scout.gold_customer_segments 
WHERE customer_tier = 'VIP';

-- At-risk customers for retention
SELECT * FROM scout.gold_customer_segments 
WHERE recency_status = 'At Risk'
ORDER BY total_spent DESC;
```

### 5. gold_store_performance
Store-level metrics with regional comparisons.

**Key Columns:**
- `store_id`, `store_name`, `city`, `region`
- `total_revenue`, `transaction_count`
- `revenue_per_sqft` - Store efficiency
- `revenue_vs_region_avg` - Regional comparison
- `inventory_turnover` - Stock efficiency

**Usage:**
```sql
-- Top performing stores by region
SELECT * FROM scout.gold_store_performance 
ORDER BY region, total_revenue DESC;
```

### 6. gold_sales_trends
Time series sales data with moving averages.

**Key Columns:**
- `sale_date`, `day_of_week`
- `revenue`, `transactions`, `units_sold`
- `revenue_7d_avg`, `revenue_30d_avg` - Moving averages
- `revenue_yoy_change_pct` - Year-over-year growth
- `avg_transaction_value`, `discount_rate`

**Usage:**
```sql
-- Last 30 days trend
SELECT * FROM scout.gold_sales_trends 
WHERE sale_date >= CURRENT_DATE - 30
ORDER BY sale_date;
```

### 7. gold_inventory_analysis
Current inventory status with reorder recommendations.

**Key Columns:**
- `product_id`, `store_id`
- `current_stock`, `inventory_value`
- `stock_status` - Out of Stock/Low/Normal/Overstock
- `days_of_supply` - Based on sales velocity
- `reorder_recommendation` - Action needed

**Usage:**
```sql
-- Items needing reorder
SELECT * FROM scout.gold_inventory_analysis 
WHERE reorder_recommendation = 'Reorder Now'
ORDER BY inventory_value DESC;
```

### 8. gold_category_insights
Category performance with growth potential.

**Key Columns:**
- `category_id`, `category_name`, `department`
- `revenue`, `units_sold`
- `dept_revenue_share` - Market share within department
- `revenue_rank`, `dept_revenue_rank`
- `unsold_product_pct` - Growth opportunity

**Usage:**
```sql
-- Top categories by department
SELECT * FROM scout.gold_category_insights 
ORDER BY department, revenue DESC;
```

### 9. gold_geographic_summary
Regional and city-level aggregations.

**Key Columns:**
- `region`, `city`
- `store_count`, `total_revenue`
- `revenue_per_store` - Store productivity
- `revenue_market_share` - National share
- `inventory_turnover` - Regional efficiency

**Usage:**
```sql
-- Regional performance summary
SELECT region, 
       SUM(total_revenue) as region_revenue,
       SUM(store_count) as stores,
       AVG(revenue_per_store) as avg_store_revenue
FROM scout.gold_geographic_summary 
GROUP BY region
ORDER BY region_revenue DESC;
```

### 10. gold_time_series_metrics
Hourly and daily patterns for operational insights.

**Key Columns:**
- `hour_of_day`, `day_of_week`
- `transactions`, `revenue`, `unique_customers`
- `hour_classification` - Peak/Normal/Off-Peak
- `hourly_revenue_rank` - Busiest hours
- `hour_revenue_share` - % of daily revenue

**Usage:**
```sql
-- Peak hours analysis
SELECT hour_of_day, 
       AVG(revenue) as avg_revenue,
       AVG(transactions) as avg_transactions
FROM scout.gold_time_series_metrics 
WHERE hour_classification = 'Peak Hour'
GROUP BY hour_of_day
ORDER BY hour_of_day;
```

## Integration with DAL Service

The Gold views are designed to work seamlessly with the Scout Analytics DAL service:

```typescript
// Example DAL service integration
import { DALService } from './modules/scout/src/services';

// Get dashboard KPIs
const kpis = await DALService.getDashboardKPIs();
// This queries: SELECT * FROM scout.gold_dashboard_kpis

// Get product performance
const products = await DALService.getProductPerformance({
  limit: 20,
  category: 'Electronics'
});
// This queries: SELECT * FROM scout.gold_product_performance WHERE ...

// Get customer segments
const segments = await DALService.getCustomerSegments({
  tier: 'VIP'
});
// This queries: SELECT * FROM scout.gold_customer_segments WHERE ...
```

## Performance Optimization

### Indexes
The Gold views are optimized with indexes on the underlying fact tables:
- Date-based indexes for time series queries
- Foreign key indexes for joins
- Composite indexes for common filter combinations

### Materialization Strategy
For production environments with large data volumes, consider:
1. Converting critical views to materialized views
2. Setting up refresh schedules (hourly/daily)
3. Using table partitioning for fact tables

Example:
```sql
-- Convert to materialized view
CREATE MATERIALIZED VIEW scout.gold_dashboard_kpis_mat AS
SELECT * FROM scout.gold_dashboard_kpis;

-- Create refresh schedule
CREATE OR REPLACE FUNCTION refresh_gold_views()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY scout.gold_dashboard_kpis_mat;
  -- Add other materialized views
END;
$$ LANGUAGE plpgsql;

-- Schedule with pg_cron
SELECT cron.schedule('refresh-gold-views', '0 * * * *', 'SELECT refresh_gold_views();');
```

## Deployment

### Prerequisites
1. Scout schema must exist
2. Fact and dimension tables must be created
3. Base data should be loaded for meaningful results

### Deployment Steps
```bash
# 1. Set database credentials
export SUPABASE_DB_PASSWORD="your-password"

# 2. Run deployment script
./scripts/deploy-gold-views.sh

# 3. Test the views
psql -h $DB_HOST -p $DB_PORT -d $DB_NAME -U $DB_USER -f test-gold-views.sql
```

### Rollback
If needed, views can be dropped without affecting underlying data:
```sql
-- Drop all Gold views
DROP VIEW IF EXISTS scout.gold_dashboard_kpis CASCADE;
DROP VIEW IF EXISTS scout.gold_product_performance CASCADE;
-- ... etc
```

## Security

### Access Control
```sql
-- Grant read access to application role
GRANT SELECT ON ALL TABLES IN SCHEMA scout TO app_role;

-- Revoke write access (views are read-only by nature)
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA scout FROM app_role;
```

### Row Level Security
For multi-tenant scenarios, implement RLS on base tables:
```sql
-- Example: Store-based access
ALTER TABLE scout.fact_sales ENABLE ROW LEVEL SECURITY;

CREATE POLICY store_access ON scout.fact_sales
  FOR SELECT
  USING (store_id IN (
    SELECT store_id FROM user_store_access 
    WHERE user_id = current_user_id()
  ));
```

## Monitoring

### Query Performance
```sql
-- Monitor slow queries on Gold views
SELECT 
  query,
  calls,
  mean_exec_time,
  total_exec_time
FROM pg_stat_statements
WHERE query LIKE '%gold_%'
ORDER BY mean_exec_time DESC
LIMIT 10;
```

### Usage Analytics
```sql
-- Track which views are used most
CREATE TABLE scout.view_usage_log (
  view_name TEXT,
  query_time TIMESTAMP DEFAULT NOW(),
  execution_time_ms INTEGER,
  user_id TEXT
);

-- Log usage in application
INSERT INTO scout.view_usage_log (view_name, execution_time_ms, user_id)
VALUES ('gold_dashboard_kpis', 125, 'app_user_123');
```

## Best Practices

1. **Always use views, not direct table access** - Views provide abstraction and can be optimized without changing the API
2. **Filter early** - Add WHERE clauses to reduce data processed
3. **Limit results** - Use LIMIT for dashboard queries
4. **Cache in application** - Gold views are relatively static, cache for 5-15 minutes
5. **Monitor performance** - Set up alerts for slow queries
6. **Document changes** - Update this documentation when modifying views

## Troubleshooting

### Common Issues

1. **"No data returned"**
   - Check if fact tables have data
   - Verify date ranges in WHERE clauses
   - Ensure proper joins between facts and dimensions

2. **"Query timeout"**
   - Check if indexes exist
   - Consider materialized views
   - Reduce date range or add filters

3. **"Permission denied"**
   - Verify user has SELECT grant on schema
   - Check RLS policies if enabled

### Debug Queries
```sql
-- Check if base tables have data
SELECT COUNT(*) FROM scout.fact_sales;
SELECT COUNT(*) FROM scout.dim_products;

-- Verify view definition
\d+ scout.gold_dashboard_kpis

-- Explain plan for slow queries
EXPLAIN ANALYZE SELECT * FROM scout.gold_product_performance;
```