# Scout Schema Documentation v3.0
*Last Updated: August 23, 2025 | Production Release*

## 📊 Executive Summary

The Scout Analytics platform has evolved to v3.0 with a comprehensive data warehouse implementation:

- **81 Base Tables** (vs 26 in v2)
- **120+ Analytics Views** 
- **Complete Master Data Layer**
- **Full ETL Pipeline with Queue Management**
- **Brand Detection & SKU Management**
- **Speech-to-Text Integration**
- **Web Scraping Capabilities**

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     DATA SOURCES                             │
├───────────────┬────────────────┬────────────────────────────┤
│ Email Attachments │ Storage Buckets │ Edge Devices │ APIs  │
└───────┬───────────┴──────┬─────────┴───────┬───────────────┘
        │                  │                  │
        ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│              BRONZE LAYER (4 tables)                         │
│  • bronze_transactions    • bronze_edge_raw                 │
│  • bronze_products        • bronze_events                   │
└───────────────────────────┬─────────────────────────────────┘
                            │
                ┌───────────▼───────────┐
                │   SILVER LAYER (1)    │
                │   silver_transactions  │
                └───────────┬───────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│               GOLD LAYER (3 tables)                          │
│  • gold_sari_sari_kpis                                      │
│  • scout_gold_transactions                                  │
│  • scout_gold_transaction_items                             │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│            ANALYTICS VIEWS (120+ views)                      │
│  • Dashboard Views        • Gold Analytics                  │
│  • Pipeline Monitoring    • DAL Views                       │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Database Structure

### 1. **Core Data Warehouse** (Star Schema)

#### Dimension Tables (8)
- `dim_date` - Date dimension with fiscal calendar
- `dim_time` - Time of day analysis
- `dim_stores` - Store locations (SCD Type 2)
- `dim_customers` - Customer profiles (SCD Type 2)
- `dim_products` - Product catalog (SCD Type 2)
- `dim_campaigns` - Marketing campaigns
- `dim_payment_methods` - Payment types
- `dim_geometries` - Geographic boundaries

#### Fact Tables (9)
- `fact_transactions` - Core transaction records
- `fact_transaction_items` - Line item details
- `fact_daily_sales` - Pre-aggregated daily metrics
- `fact_consumer_behavior` - Shopping behavior patterns
- `fact_basket_analysis` - Product affinity
- `fact_substitutions` - Product replacement patterns
- `fact_request_patterns` - Customer request analysis
- `fact_transaction_duration` - Transaction timing
- `fact_monthly_performance` - Monthly rollups

### 2. **Master Data Layer** (Reference Data) - NEW in v3

#### Master Tables (12)
- `master_brands` - Brand registry with TBWA client flag
- `master_categories` - Product taxonomy hierarchy
- `master_locations` - Philippines geographic hierarchy
- `master_ph_locations` - PSGC reference data
- `master_stores` - Store master including sari-sari
- `master_items` - Item catalog with barcodes
- `master_product_catalog` - Complete product reference
- `master_price_list` - Pricing by product/store type
- `master_customer_segments` - Segmentation definitions
- `master_promotions` - Promotional campaigns
- `master_suppliers` - Supplier information
- `master_brand_catalog` - Brand-category relationships

### 3. **Bridge Tables** (Many-to-Many) - NEW in v3
- `bridge_product_bundles` - Bundle definitions
- `bridge_product_substitutions` - Substitution mapping
- `bridge_store_campaigns` - Store-campaign assignments

### 4. **Data Pipeline Layers**

#### Bronze Layer (4 tables)
- `bronze_transactions` - Raw transaction landing
- `bronze_edge_raw` - Edge device data
- `bronze_products` - Scraped product data
- `bronze_events` - Event stream data

#### Silver Layer (1 table)
- `silver_transactions` - Cleansed transactions

#### Gold Layer (3 tables)
- `gold_sari_sari_kpis` - Store KPIs
- `scout_gold_transactions` - Optimized transactions
- `scout_gold_transaction_items` - Optimized items

### 5. **ETL Management** (6 tables)
- `etl_queue` - Job queue management
- `etl_watermarks` - Processing checkpoints
- `etl_failures` - Failure tracking
- `ingestion_log` - Audit trail
- `enrichment_queue` - Data enrichment jobs
- `report_queue` - Report generation queue

### 6. **Data Collection & Enrichment** (5 tables)
- `stt_brand_dictionary` - Speech-to-text brand detection
- `scraped_items` - Web-scraped products
- `scrape_queue` - Scraping job queue
- `scrape_sessions` - Session tracking
- `scraper_config` - Site configurations

## 🔄 Major Changes from v2 to v3

### Added Components
1. **Master Data Layer** - Complete reference data management
2. **Bridge Tables** - Complex relationship handling
3. **Data Collection Tables** - STT and web scraping
4. **Extended ETL Management** - Queue and enrichment
5. **Analytics Views** - 120+ pre-built views

### Enhanced Features
- **Brand Detection**: Integrated STT brand dictionary
- **SKU Management**: Web scraping for product data
- **Geographic Data**: Complete Philippines hierarchy
- **Performance**: Pre-aggregated tables and views
- **Queue Management**: Robust ETL processing

## 📊 Analytics Views (120+)

### Dashboard Views
- `v_dashboard_*` (13 views) - Executive dashboards
- `dashboard_*` (15 views) - Operational dashboards

### Gold Analytics
- `gold_analytics` - Main aggregation
- `gold_kpi_daily` - Daily KPIs
- `gold_brand_share` - Brand market share
- `gold_customer_*` - Customer analytics
- `gold_geo_*` - Geographic analysis

### Pipeline Monitoring
- `v_pipeline_*` - Pipeline health
- `v_etl_*` - ETL monitoring
- `v_edge_*` - Edge device tracking

### Data Access Layer
- `v_dal_*` - API-ready views
- `dal_transactions_flat` - Denormalized view

## 🚀 API Endpoints

### Core Analytics
```sql
SELECT * FROM scout.get_dashboard_kpis();
SELECT * FROM scout.get_store_performance_summary();
SELECT * FROM scout.get_product_analytics();
```

### Gold Layer Refresh
```sql
SELECT scout.refresh_gold_metrics();
SELECT scout.refresh_daily_sales();
SELECT scout.refresh_gold_materialized_views();
```

### ETL Pipeline
```sql
SELECT scout.run_full_etl_pipeline();
SELECT scout.process_etl_queue();
SELECT scout.check_pipeline_health();
```

## 🔐 Security Features

- **Row-Level Security (RLS)** on sensitive tables
- **Audit Trail** via triggers
- **API Authentication** with token validation
- **Data Quality Controls** at each layer

## 🎯 Performance Optimizations

1. **Materialized Views** for frequently accessed data
2. **Table Partitioning** by date
3. **Strategic Indexes** on all foreign keys
4. **Pre-aggregated Tables** for dashboards
5. **Batch Processing** for ETL operations

## 📝 Deployment Information

- **Database**: Supabase PostgreSQL
- **Schema**: `scout`
- **Project URL**: `https://cxzllzyxwpyptfretryc.supabase.co`
- **Extensions**: pg_cron, pgvector (optional)
- **Storage**: Google Cloud Storage integration
- **Edge Functions**: Real-time processing

## 🔄 Migration from v2

### Compatibility
- All v2 tables remain intact
- Views provide backward compatibility
- No breaking changes to existing APIs

### Deprecation Schedule
- **November 21, 2025**: Singular table name views deprecated
- Use plural names for all new development

## 📚 Related Documentation

- [ETL Pipeline Guide](./ETL_PIPELINE_DOCUMENTATION.md)
- [API Reference](./API_DOCUMENTATION.md)
- [Dashboard Guide](./SCOUT_DASHBOARD_MODIFICATION_GUIDE.md)
- [Data Quality Report](../Scout%20Transaction%20Data%20-%20Quality%20Audit%20&%20EDA%20Report.html)

## 🛠️ Maintenance Scripts

```bash
# Validate schema
psql $DATABASE_URL -f validate_schema.sql

# Run ETL pipeline
psql $DATABASE_URL -c "SELECT scout.run_full_etl_pipeline();"

# Check pipeline health
psql $DATABASE_URL -c "SELECT * FROM scout.v_pipeline_health;"
```

## 📈 Current Statistics

- **Total Tables**: 81 base tables
- **Total Views**: 120+ analytics views
- **Data Volume**: ~2000 transactions/day
- **Pipeline Status**: ✅ Operational
- **Last Updated**: August 23, 2025

---

*This documentation reflects the production deployment as validated on August 23, 2025.*
