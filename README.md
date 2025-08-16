# 🏔️ AI-AAS Hardened Lakehouse

A production-grade monorepo for pseudonymous customer intelligence and transaction clustering analytics. Built with security-hardened infrastructure, geographic visualization capabilities, and enterprise-grade CI/CD pipelines.

## 🚀 Features

### Core Platform
- **Production-Grade Monorepo**: pnpm workspaces + Turborepo for build orchestration
- **Complete ETL/ELT Pipeline**: Bronze → Silver → Gold → Platinum architecture
- **Geographic Visualization**: PostGIS-powered choropleth maps with Mapbox integration  
- **Security Hardened**: RLS, Gatekeeper policies, network isolation
- **Cloud Native**: Kubernetes-ready with Helm charts, Docker images published to GHCR
- **API-First**: Automated deployment via Bruno API collections
- **Performance Optimized**: GIST indexes, materialized views, <1.5s query SLA
- **CI/CD Pipeline**: GitHub Actions with required checks, branch protection, and automated testing

### Microservices Architecture
- **API Service**: FastAPI (Python) - RESTful API endpoints
- **Worker Service**: Fastify (Node.js) - Background job processing
- **Brand Model Service**: FastAPI (Python) - RapidFuzz-powered brand detection
- **Edge Functions**: Supabase Edge Functions for real-time processing
- **Database**: PostgreSQL with pgvector extension for embeddings

### Dataset Publisher & Management (New! 🎉)
- **Usage Analytics Dashboard**: Comprehensive tracking of dataset downloads, API calls, and user engagement
- **Dataset Versioning**: Semantic versioning with rollback capabilities and lineage tracking
- **Cross-Region Replication**: Global dataset availability with cost optimization
- **Subscription Notifications**: Multi-channel alerts (email, webhook, in-app, SMS, Slack)
- **Parquet Export Support**: High-performance columnar format with schema validation
- **Edge Device Integration**: Secure token-based uploads from Raspberry Pi devices
- **Automated Testing**: Comprehensive test suites with CI/CD integration

### Enterprise Features
- **Multi-Tenant Support**: Complete data isolation with RLS policies
- **Monitoring & Alerts**: Real-time dataset freshness and quality monitoring
- **Cost Management**: Replication cost estimation and optimization
- **API Documentation**: Auto-generated docs with OpenAPI integration

## 📊 Complete Data Stack

### Core Components
- **Storage**: MinIO (S3-compatible object storage)
- **Table Format**: Apache Iceberg with Nessie catalog
- **Query Engine**: Trino (distributed SQL)
- **Transformation**: dbt (data build tool)
- **Orchestration**: Apache Airflow
- **Visualization**: Apache Superset with Deck.gl
- **Database**: PostgreSQL with PostGIS
- **API Layer**: Supabase (PostgREST)

### Supporting Infrastructure
- **Container Orchestration**: Kubernetes
- **Security**: OPA Gatekeeper, Network Policies
- **Monitoring**: Prometheus + Grafana
- **CI/CD**: GitHub Actions
- **API Testing**: Bruno
- **Model Context Protocol**: Claude MCP integration

## 🗂️ Production Monorepo Structure

```
ai-aas-hardened-lakehouse/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                      # DB/Build/Test workflow
│   │   ├── dataset-publisher-tests.yml # Package testing
│   │   ├── edge-functions.yml          # Edge function tests
│   │   ├── release-images.yml          # Docker image publishing to GHCR
│   │   └── security-scan.yml           # Security analysis
│   └── branch-protection.json          # Required status checks
│
├── apps/                               # Frontend applications
│   └── scout-dashboard/                # Retail analytics UI
│
├── db/                                 # Database layer
│   ├── migrations/                     # SQL migrations (000-999)
│   │   ├── 000_extensions.sql          # pgcrypto, pg_trgm, vector
│   │   ├── 100_scouts_dims.sql         # Dimension tables
│   │   ├── 200_scouts_bronze.sql       # Bronze layer
│   │   ├── 210_scouts_silver.sql       # Silver layer
│   │   └── 220_scouts_gold.sql         # Gold layer views
│   ├── seeds/                          # Seed data
│   └── views/                          # Database views
│
├── dq/                                 # Data quality
│   └── checks/                         # DQ validation scripts
│
├── infra/                              # Infrastructure
│   └── docker/
│       ├── compose.yml                 # Local dev environment
│       └── Dockerfile.base             # Base image with common deps
│
├── packages/                           # Shared packages
│   ├── shared-types/                   # TypeScript types
│   └── common-utils/                   # Utility functions
│
├── services/                           # Microservices
│   ├── api/                            # FastAPI REST service
│   │   ├── Dockerfile
│   │   ├── pyproject.toml
│   │   └── main.py
│   ├── worker/                         # Fastify background jobs
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   └── index.js
│   └── brand-model/                    # Brand detection service
│       ├── Dockerfile
│       ├── requirements.txt
│       └── main.py
│
├── scripts/                            # Operational scripts
│   ├── setup-db.sh                     # Database setup
│   └── verify-deployment.sh            # Deployment verification
│
├── pnpm-workspace.yaml                 # pnpm workspace config
├── turbo.json                          # Turborepo config
├── pnpm-lock.yaml                      # Lockfile
└── package.json                        # Root package.json
│
├── docs/
│   └── setup/
│       ├── choropleth_optimization.md  # Geographic visualization guide
│       └── mapbox_setup.md             # Mapbox configuration
│
├── helm-overlays/
│   └── superset-values-prod.yaml       # Production Helm values
│
├── observability/
│   ├── alerting/
│   │   └── slo-alerts.yaml            # SLO-based alerting rules
│   └── grafana-dashboards/
│       └── scout-slos.json            # Performance dashboards
│
├── platform/
│   ├── cloud-wire/                    # API-first cloud integration
│   │   ├── .env.example               # Environment template
│   │   ├── README.md                  # Cloud wire documentation
│   │   ├── bruno/                     # API test collection
│   │   │   ├── bruno.json
│   │   │   ├── environments/
│   │   │   │   └── production.bru
│   │   │   └── requests/
│   │   │       ├── 01_login.bru       # Superset authentication
│   │   │       ├── 02_csrf.bru        # CSRF token retrieval
│   │   │       ├── 03_create_db_conn.bru
│   │   │       ├── 04_import_bundle.bru
│   │   │       ├── 05_test_choropleth.bru
│   │   │       └── 06_verify_geo_data.bru
│   │   ├── mcp/                       # Model Context Protocol
│   │   │   ├── mcp.json              # MCP configuration
│   │   │   └── README.txt
│   │   ├── scripts/
│   │   │   └── run_cloud_wire.sh     # Automated deployment
│   │   └── superset/
│   │       └── assets/
│   │           ├── charts/            # Visualization definitions
│   │           ├── dashboards/        # Dashboard configurations
│   │           ├── datasets/          # Dataset mappings
│   │           └── databases/         # Database connections
│   │
│   ├── lakehouse/                     # Core lakehouse infrastructure
│   │   ├── dbt/
│   │   │   ├── dbt-cronjob.yaml      # dbt scheduler
│   │   │   ├── models/                # dbt transformations
│   │   │   └── profiles.yml
│   │   ├── jobs/
│   │   │   └── geo-importer.yaml     # Geographic boundary importer
│   │   ├── minio/
│   │   │   └── init-bucket.yaml      # S3 bucket initialization
│   │   ├── nessie/
│   │   │   └── values-oss.yaml       # Iceberg catalog config
│   │   └── trino/
│   │       └── values-oss.yaml        # Query engine config
│   │
│   ├── scout/                         # Scout Analytics Platform
│   │   ├── README.md
│   │   ├── deploy.sh                  # Deployment script
│   │   ├── bruno/                     # API test collection
│   │   │   ├── 01_auth.bru            # Authentication tests
│   │   │   ├── 02_health.bru          # Health checks
│   │   │   ├── ...                    # (03-21 test files)
│   │   │   ├── 20_choropleth_smoke.bru
│   │   │   ├── 21_mapbox_verify.bru
│   │   │   ├── collection_summary.md
│   │   │   └── environments/
│   │   │       ├── production.bru
│   │   │       └── staging.bru
│   │   ├── functions/                 # Edge functions  
│   │   │   ├── embed-batch.ts         # Batch embeddings
│   │   │   ├── genie-query.ts         # AI-powered queries
│   │   │   ├── usage-analytics/       # Dataset usage tracking
│   │   │   ├── dataset-versioning/    # Version control system
│   │   │   ├── cross-region-replication/ # Multi-region sync
│   │   │   ├── dataset-subscriptions/ # Notification system
│   │   │   ├── export-parquet/        # Parquet format export
│   │   │   └── superset-jwt-proxy/    # JWT authentication
│   │   │   ├── ingest-doc.ts          # Document ingestion
│   │   │   └── ingest-transaction.ts  # Transaction processing
│   │   ├── migrations/                # Database migrations
│   │   │   ├── 001_scout_enums_dims.sql      # Base schema
│   │   │   ├── 002_scout_bronze_silver.sql   # Bronze/Silver layers
│   │   │   ├── 003_scout_gold_views.sql      # Gold layer views
│   │   │   ├── 004_scout_platinum_features.sql # Advanced features
│   │   │   ├── 005_scout_rls_policies.sql    # Security policies
│   │   │   ├── 006_ingest_idempotency.sql    # Deduplication
│   │   │   ├── 007_gold_refresh.sql          # MV refresh logic
│   │   │   ├── 008_view_silver_last.sql      # Latest data views
│   │   │   ├── 009_perf_indexes.sql          # Performance indexes
│   │   │   ├── 010_geo_boundaries.sql        # PostGIS setup
│   │   │   ├── 011_geo_normalizers.sql       # Name normalization
│   │   │   ├── 012_geo_gold_views.sql        # Geographic views
│   │   │   ├── 013_geo_performance_indexes.sql # Spatial indexes
│   │   │   ├── 022_usage_analytics_schema.sql # Usage tracking
│   │   │   ├── 023_dataset_versioning_schema.sql # Version control
│   │   │   ├── 024_cross_region_replication_schema.sql # Multi-region
│   │   │   └── 025_dataset_subscription_schema.sql # Notifications
│   │   ├── quality/                   # Data quality
│   │   │   ├── checkpoints/
│   │   │   ├── expectations/
│   │   │   ├── great_expectations.yml
│   │   │   └── sql_quality_checks.sql
│   │   └── superset/
│   │       └── scout_dashboard.yaml   # Dashboard config
│   │
│   ├── security/                      # Security policies
│   │   ├── gatekeeper/               # Admission controllers
│   │   │   ├── constraints/
│   │   │   │   ├── forbid-latest-tags.yaml
│   │   │   │   └── require-probes.yaml
│   │   │   └── templates/
│   │   │       ├── k8scontainerprobes_template.yaml
│   │   │       └── no-latest-tags_template.yaml
│   │   └── netpol/                   # Network policies
│   │       ├── 01-trino-policies.yaml
│   │       └── 02-superset-policies.yaml
│   │
│   └── superset/                     # Visualization layer
│       ├── assets/
│       │   ├── charts/
│       │   │   ├── citymun_choropleth.yaml    # City-level map
│       │   │   └── region_choropleth.yaml     # Regional map
│       │   └── datasets/
│       │       ├── gold_citymun_choropleth.yaml
│       │       └── gold_region_choropleth.yaml
│       ├── config/
│       │   └── mapbox_config.py      # Map configuration
│       ├── docker/
│       │   ├── .env.example
│       │   └── superset_config_additions.py
│       ├── scripts/
│       │   ├── import_supabase_bundle.sh
│       │   └── import_trino_bundle.sh
│       └── superset_config.py        # Main configuration
│
├── scripts/                          # Operational scripts
│   ├── benchmark_choropleth.py       # Performance benchmarking
│   ├── benchmark_choropleth_hard.py  # Hard performance gates
│   ├── deploy_superset_with_mapbox.sh
│   ├── run_bruno_tests.sh           # Test automation
│   ├── test_choropleth_performance.sql
│   ├── verify_choropleth_complete.sh
│   └── verify_geo_deployment.sh
│
├── .gitignore
├── ARCHITECTURE_FLOW.md              # System architecture
├── DEPLOYMENT_CHECKLIST.md           # Deployment guide
├── DEPLOYMENT_STATUS.md              # Current status
├── FINAL_PROJECT_SUMMARY.md          # Project overview
├── Makefile                          # Build automation
├── README.md                         # This file
├── STRUCTURE_VALIDATION.md           # Validation rules
└── validate_deployment.sh            # Deployment validation
```

## 📐 Complete Database Schema (DBML)

```dbml
// Scout Analytics Data Model
// Complete schema including all master data, transactional, and derived objects

Project ScoutAnalytics {
  database_type: 'PostgreSQL'
  Note: 'Hardened Lakehouse with Geographic Capabilities'
}

// ==========================================
// ENUMS & CUSTOM TYPES
// ==========================================

enum time_of_day {
  morning [note: '6 AM - 12 PM']
  afternoon [note: '12 PM - 6 PM']
  evening [note: '6 PM - 10 PM']
  night [note: '10 PM - 6 AM']
}

enum customer_type {
  new
  returning
  vip
  churned
}

enum product_category {
  beverages
  snacks
  personal_care
  household
  tobacco
  other
}

enum payment_method {
  cash
  gcash
  maya
  card
  other
}

enum campaign_type {
  promo
  seasonal
  loyalty
  flash_sale
  bundle
}

enum channel_type {
  store
  online
  wholesale
  b2b
}

enum income_class {
  '1st'
  '2nd'
  '3rd'
  '4th'
  '5th'
  '6th'
}

// ==========================================
// MASTER DATA TABLES (Dimensions)
// ==========================================

Table scout.dim_store {
  store_id TEXT [pk, note: 'Primary store identifier']
  store_name TEXT [not null]
  store_code TEXT [unique]
  channel channel_type [default: 'store']
  region TEXT
  province TEXT
  city TEXT
  barangay TEXT
  address TEXT
  latitude DECIMAL(10,8)
  longitude DECIMAL(11,8)
  cluster_id TEXT
  district_id TEXT
  is_active BOOLEAN [default: true]
  opened_date DATE
  closed_date DATE
  store_size_sqm INTEGER
  staff_count INTEGER
  
  // Geographic normalization columns
  citymun_psgc TEXT [note: 'Philippine Standard Geographic Code']
  province_psgc TEXT
  region_psgc TEXT
  
  created_at TIMESTAMP [default: 'NOW()']
  updated_at TIMESTAMP [default: 'NOW()']
  
  Indexes {
    store_code
    (latitude, longitude)
    citymun_psgc
    is_active
  }
}

Table scout.dim_product {
  product_id TEXT [pk]
  product_name TEXT [not null]
  product_code TEXT [unique]
  barcode TEXT
  category product_category
  subcategory TEXT
  brand TEXT
  supplier_id TEXT
  unit_of_measure TEXT
  pack_size INTEGER
  unit_cost DECIMAL(10,2)
  srp DECIMAL(10,2) [note: 'Suggested Retail Price']
  is_active BOOLEAN [default: true]
  launch_date DATE
  discontinue_date DATE
  
  created_at TIMESTAMP [default: 'NOW()']
  updated_at TIMESTAMP [default: 'NOW()']
  
  Indexes {
    product_code
    barcode
    category
    brand
    is_active
  }
}

Table scout.dim_customer {
  customer_id TEXT [pk]
  customer_code TEXT [unique]
  mobile_number TEXT
  email TEXT
  first_name TEXT
  last_name TEXT
  birthdate DATE
  gender TEXT
  customer_type customer_type
  loyalty_tier TEXT
  loyalty_points INTEGER [default: 0]
  first_purchase_date DATE
  last_purchase_date DATE
  total_lifetime_value DECIMAL(12,2)
  preferred_store_id TEXT
  preferred_payment payment_method
  
  created_at TIMESTAMP [default: 'NOW()']
  updated_at TIMESTAMP [default: 'NOW()']
  
  Indexes {
    customer_code
    mobile_number
    email
    customer_type
    loyalty_tier
  }
}

Table scout.dim_campaign {
  campaign_id TEXT [pk]
  campaign_name TEXT [not null]
  campaign_type campaign_type
  start_date DATE [not null]
  end_date DATE [not null]
  budget DECIMAL(12,2)
  target_sales DECIMAL(12,2)
  discount_percentage DECIMAL(5,2)
  discount_amount DECIMAL(10,2)
  min_purchase_amount DECIMAL(10,2)
  applicable_products TEXT[] [note: 'Array of product_ids']
  applicable_stores TEXT[] [note: 'Array of store_ids']
  is_active BOOLEAN
  
  created_at TIMESTAMP [default: 'NOW()']
  updated_at TIMESTAMP [default: 'NOW()']
  
  Indexes {
    campaign_type
    (start_date, end_date)
    is_active
  }
}

Table scout.dim_date {
  date_key DATE [pk]
  year INTEGER [not null]
  quarter INTEGER [not null]
  month INTEGER [not null]
  week INTEGER [not null]
  day_of_month INTEGER [not null]
  day_of_week INTEGER [not null]
  day_name TEXT [not null]
  month_name TEXT [not null]
  is_weekend BOOLEAN [not null]
  is_holiday BOOLEAN [default: false]
  holiday_name TEXT
  fiscal_year INTEGER
  fiscal_quarter INTEGER
  fiscal_month INTEGER
  
  Indexes {
    year
    (year, month)
    (year, quarter)
    is_holiday
  }
}

// ==========================================
// GEOGRAPHIC MASTER DATA
// ==========================================

Table scout.dim_geo_region {
  region_key TEXT [pk, note: 'Normalized region identifier']
  region_name TEXT [not null]
  region_psgc TEXT [unique]
  island_group TEXT [note: 'Luzon, Visayas, Mindanao']
  aliases TEXT[] [note: 'Alternative names (NCR, Metro Manila, etc.)']
  
  Indexes {
    region_psgc
  }
}

Table scout.dim_geo_province {
  province_psgc TEXT [pk]
  province_name TEXT [not null]
  region_key TEXT [not null]
  
  Indexes {
    region_key
  }
}

Table scout.dim_geo_citymun {
  citymun_psgc TEXT [pk]
  citymun_name TEXT [not null]
  province_psgc TEXT [not null]
  region_key TEXT [not null]
  is_city BOOLEAN [default: false]
  income_class income_class
  population INTEGER
  area_sqkm DECIMAL(10,2)
  
  Indexes {
    province_psgc
    region_key
    is_city
    income_class
  }
}

// Geographic boundary tables with PostGIS geometry
Table scout.geo_adm1_region {
  region_key TEXT [pk]
  region_name TEXT [not null]
  region_psgc TEXT
  geom GEOMETRY(MULTIPOLYGON, 4326) [not null]
  area_sqkm DECIMAL(10,2)
  population INTEGER
  created_at TIMESTAMP [default: 'NOW()']
  
  Indexes {
    geom [type: gist]
  }
}

Table scout.geo_adm2_province {
  province_psgc TEXT [pk]
  province_name TEXT [not null]
  region_key TEXT [not null]
  geom GEOMETRY(MULTIPOLYGON, 4326) [not null]
  area_sqkm DECIMAL(10,2)
  population INTEGER
  created_at TIMESTAMP [default: 'NOW()']
  
  Indexes {
    geom [type: gist]
    region_key
  }
}

Table scout.geo_adm3_citymun {
  citymun_psgc TEXT [pk]
  citymun_name TEXT [not null]
  province_psgc TEXT [not null]
  region_key TEXT [not null]
  geom GEOMETRY(MULTIPOLYGON, 4326) [not null]
  area_sqkm DECIMAL(10,2)
  population INTEGER
  created_at TIMESTAMP [default: 'NOW()']
  
  Indexes {
    geom [type: gist]
    province_psgc
    region_key
  }
}

// Simplified geometries for performance
Table scout.geo_adm1_region_gen {
  region_key TEXT [pk]
  geom GEOMETRY(MULTIPOLYGON, 4326) [not null, note: 'Simplified with ST_SimplifyPreserveTopology']
  
  Indexes {
    geom [type: gist]
  }
}

Table scout.geo_adm3_citymun_gen {
  citymun_psgc TEXT [pk]
  geom GEOMETRY(MULTIPOLYGON, 4326) [not null, note: 'Simplified geometry']
  
  Indexes {
    geom [type: gist]
  }
}

// ==========================================
// TRANSACTIONAL TABLES (Facts)
// ==========================================

Table scout.bronze_events {
  event_id UUID [pk, default: 'gen_random_uuid()']
  event_type TEXT [not null]
  event_data JSONB [not null]
  event_hash BYTEA [unique, note: 'SHA256 hash for deduplication']
  source_system TEXT
  ingested_at TIMESTAMP [default: 'NOW()']
  
  Indexes {
    event_type
    ingested_at
    event_hash
  }
}

Table scout.bronze_transactions {
  raw_id UUID [pk, default: 'gen_random_uuid()']
  transaction_data JSONB [not null]
  source_file TEXT
  loaded_at TIMESTAMP [default: 'NOW()']
  
  Indexes {
    loaded_at
  }
}

Table scout.silver_transactions {
  id UUID [pk, default: 'gen_random_uuid()']
  transaction_id TEXT [not null]
  store_id TEXT [not null]
  ts TIMESTAMP [not null]
  date_key DATE [not null]
  time_of_day time_of_day [not null]
  
  // Customer info
  customer_id TEXT
  customer_type customer_type
  
  // Transaction details
  total_amount DECIMAL(10,2) [not null]
  discount_amount DECIMAL(10,2) [default: 0]
  tax_amount DECIMAL(10,2) [default: 0]
  net_amount DECIMAL(10,2) [not null]
  payment_method payment_method
  
  // Product aggregates
  item_count INTEGER [not null]
  unique_products INTEGER [not null]
  units_per_transaction INTEGER [not null]
  basket_size INTEGER [not null]
  
  // Derived fields
  peso_value DECIMAL(10,2) [not null]
  product_category product_category
  handshake_triggered BOOLEAN [default: false]
  handshake_score DECIMAL(3,2)
  
  // Campaign tracking
  campaign_id TEXT
  campaign_influenced BOOLEAN [default: false]
  
  // Location enrichment  
  region TEXT
  province TEXT
  city TEXT
  
  // Processing metadata
  processed_at TIMESTAMP [default: 'NOW()']
  quality_score DECIMAL(3,2)
  
  Indexes {
    transaction_id
    store_id
    ts
    date_key
    customer_id
    campaign_id
    (store_id, date_key)
    (region, date_key)
  }
}

Table scout.silver_line_items {
  line_id UUID [pk, default: 'gen_random_uuid()']
  transaction_id TEXT [not null]
  product_id TEXT [not null]
  quantity INTEGER [not null]
  unit_price DECIMAL(10,2) [not null]
  line_amount DECIMAL(10,2) [not null]
  discount_amount DECIMAL(10,2) [default: 0]
  
  Indexes {
    transaction_id
    product_id
  }
}

// ==========================================
// ANALYTICAL VIEWS (Gold Layer)
// ==========================================

Table scout.gold_daily_metrics {
  date_key DATE [not null]
  store_id TEXT [not null]
  
  // Transaction metrics
  transaction_count INTEGER
  total_sales DECIMAL(12,2)
  total_discount DECIMAL(10,2)
  total_tax DECIMAL(10,2)
  net_sales DECIMAL(12,2)
  
  // Customer metrics
  unique_customers INTEGER
  new_customers INTEGER
  returning_customers INTEGER
  vip_customers INTEGER
  
  // Product metrics
  units_sold INTEGER
  unique_products_sold INTEGER
  avg_basket_size DECIMAL(5,2)
  avg_transaction_value DECIMAL(10,2)
  
  // Time distribution
  morning_sales DECIMAL(10,2)
  afternoon_sales DECIMAL(10,2)
  evening_sales DECIMAL(10,2)
  night_sales DECIMAL(10,2)
  
  // Campaign effectiveness
  campaign_transactions INTEGER
  campaign_sales DECIMAL(10,2)
  campaign_effectiveness DECIMAL(5,2)
  
  created_at TIMESTAMP [default: 'NOW()']
  
  Indexes {
    (date_key, store_id) [unique]
    date_key
    store_id
  }
}

Table scout.gold_region_choropleth {
  region_key TEXT [not null]
  region_name TEXT [not null]
  day DATE [not null]
  geom GEOMETRY(MULTIPOLYGON, 4326)
  
  // Metrics
  txn_count BIGINT
  active_stores BIGINT
  new_customers BIGINT
  peso_total DECIMAL(14,2)
  avg_transaction_value DECIMAL(10,2)
  
  // Time-based sales
  morning_sales DECIMAL(14,2)
  afternoon_sales DECIMAL(14,2)
  evening_sales DECIMAL(14,2)
  night_sales DECIMAL(14,2)
  
  // Demographics
  area_sqkm DECIMAL(10,2)
  population INTEGER
  revenue_per_capita DECIMAL(10,2)
  
  Indexes {
    (region_key, day)
    day
    geom [type: gist]
  }
}

// ==========================================
// FUNCTIONS & PROCEDURES
// ==========================================

// Event hash function for deduplication
Function scout.fn_event_hash(data JSONB) RETURNS BYTEA {
  Note: 'Generates SHA256 hash of JSON data for idempotent ingestion'
}

// Region normalization function
Function scout.norm_region(region_name TEXT) RETURNS TEXT {
  Note: 'Normalizes region names (NCR → Metro Manila, IV-A → CALABARZON, etc.)'
}

// City/Municipality PSGC lookup
Function scout.norm_citymun(city TEXT, province TEXT) RETURNS TEXT {
  Note: 'Returns PSGC code for city/municipality'
}

// Gold layer refresh with advisory lock
Function scout.refresh_gold() RETURNS VOID {
  Note: 'Refreshes gold layer materialized views with concurrency control'
}

// Transaction ingestion with deduplication
Function scout.ingest_transaction(data JSONB) RETURNS VOID {
  Note: 'Ingests transaction with automatic deduplication and enrichment'
}

// ==========================================
// MATERIALIZED VIEWS
// ==========================================

MaterializedView scout.mv_store_performance_30d {
  Note: 'Store performance metrics for last 30 days'
  refresh_strategy: 'CONCURRENTLY'
  refresh_interval: '1 hour'
}

MaterializedView scout.mv_product_velocity {
  Note: 'Fast-moving products by region and store'
  refresh_strategy: 'CONCURRENTLY'
  refresh_interval: '6 hours'
}

MaterializedView scout.mv_customer_segments {
  Note: 'Customer segmentation with RFM analysis'
  refresh_strategy: 'CONCURRENTLY'
  refresh_interval: 'daily'
}

// ==========================================
// RELATIONSHIPS
// ==========================================

Ref: scout.silver_transactions.store_id > scout.dim_store.store_id
Ref: scout.silver_transactions.customer_id > scout.dim_customer.customer_id
Ref: scout.silver_transactions.campaign_id > scout.dim_campaign.campaign_id
Ref: scout.silver_transactions.date_key > scout.dim_date.date_key

Ref: scout.silver_line_items.transaction_id > scout.silver_transactions.transaction_id
Ref: scout.silver_line_items.product_id > scout.dim_product.product_id

Ref: scout.dim_store.citymun_psgc > scout.dim_geo_citymun.citymun_psgc
Ref: scout.dim_geo_citymun.province_psgc > scout.dim_geo_province.province_psgc
Ref: scout.dim_geo_province.region_key > scout.dim_geo_region.region_key

Ref: scout.geo_adm1_region.region_key > scout.dim_geo_region.region_key
Ref: scout.geo_adm2_province.province_psgc > scout.dim_geo_province.province_psgc
Ref: scout.geo_adm3_citymun.citymun_psgc > scout.dim_geo_citymun.citymun_psgc

Ref: scout.gold_daily_metrics.store_id > scout.dim_store.store_id
Ref: scout.gold_daily_metrics.date_key > scout.dim_date.date_key

Ref: scout.gold_region_choropleth.region_key > scout.dim_geo_region.region_key
```

## 🔄 ETL/ELT Data Flow

### 1. **Bronze Layer** (Raw Data Ingestion)
```sql
-- Raw events with deduplication
scout.bronze_events → Immutable event store
scout.bronze_transactions → Raw transaction JSON
scout.bronze_store_master → Store metadata dumps
scout.bronze_product_catalog → Product catalog imports
```

### 2. **Silver Layer** (Cleaned & Enriched)
```sql
-- Validated and enriched data
scout.silver_transactions → Cleaned transactions with geographic enrichment
scout.silver_line_items → Transaction line item details
scout.silver_store_metrics → Real-time store performance
scout.silver_customer_segments → Customer behavior analysis
```

### 3. **Gold Layer** (Business Aggregates)
```sql
-- Pre-aggregated metrics for reporting
scout.gold_daily_metrics → Daily KPIs by store
scout.gold_weekly_metrics → Weekly trends
scout.gold_monthly_metrics → Monthly summaries
scout.gold_region_choropleth → Geographic aggregates for visualization
scout.gold_product_performance → Product velocity and trends
scout.gold_customer_ltv → Customer lifetime value
```

### 4. **Platinum Layer** (ML Features & Advanced Analytics)
```sql
-- ML-ready features and predictions
scout.feature_store → Engineered features for ML models
scout.prediction_outputs → Model predictions (churn, demand, etc.)
scout.anomaly_detection → Outlier detection results
scout.recommendation_engine → Product recommendations
```

## 🚀 Quick Start

### Prerequisites
- Node.js 20+
- pnpm 9+ (`npm install -g pnpm`)
- Docker & Docker Compose
- PostgreSQL 14+ with pgvector extension
- Python 3.8+
- GitHub CLI (for releases)

### 1. Clone and Setup
```bash
git clone https://github.com/jgtolentino/ai-aas-hardened-lakehouse.git
cd ai-aas-hardened-lakehouse

# Install dependencies
pnpm install

# Setup environment
cp .env.example .env
# Edit .env with your database credentials
```

### 2. Local Development
```bash
# Start all services with Docker Compose
docker compose -f infra/docker/compose.yml up -d

# Services will be available at:
# - PostgreSQL: localhost:5432
# - API Service: http://localhost:8000
# - Worker Service: http://localhost:3000
# - Brand Model: http://localhost:8001

# Run database migrations
./scripts/setup-db.sh

# Build all packages
pnpm run build

# Run tests
pnpm run test
```

### 3. Production Deployment
```bash
# Build Docker images
pnpm run docker:build

# Run CI/CD checks locally
pnpm run ci:check

# Deploy to production
git push origin main

# Images are automatically published to GHCR:
# ghcr.io/jgtolentino/ai-aas-hardened-lakehouse-api:latest
# ghcr.io/jgtolentino/ai-aas-hardened-lakehouse-worker:latest
# ghcr.io/jgtolentino/ai-aas-hardened-lakehouse-brand-model:latest
```

## 🔧 Development Workflow

### Branch Protection
The `main` branch is protected with required status checks:
- ✅ DB/Build/Test - Database migrations and build verification
- ✅ Dataset Publisher Tests - Package unit and integration tests  
- ✅ Security Scan - CodeQL and dependency scanning

### Making Changes
```bash
# Create feature branch
git checkout -b feature/your-feature

# Make changes and test locally
pnpm run dev

# Run linting and type checking
pnpm run lint
pnpm run typecheck

# Create pull request
gh pr create --title "feat: your feature" --body "Description of changes"

# After approval and checks pass, merge
gh pr merge --squash
```

### CI/CD Pipeline
1. **Pull Request**: Runs all tests and checks
2. **Merge to main**: 
   - Builds and publishes Docker images to GHCR
   - Tags with commit SHA and 'latest'
   - Deploys to staging (if configured)
3. **Release**: Create GitHub release to trigger production deployment

## 📊 Performance Metrics

### Query Performance SLAs
- **Simple aggregations**: P95 < 100ms
- **Geographic queries**: P95 < 1.5s
- **Choropleth rendering**: P95 < 2.5s end-to-end
- **Dashboard load**: P95 < 3s

### Data Pipeline SLAs
- **Ingestion latency**: < 30s from source to Bronze
- **Silver processing**: < 2 minutes
- **Gold refresh**: < 5 minutes
- **Data freshness**: < 10 minutes end-to-end

### Scale Tested
- **Transaction volume**: 100M+ records
- **Geographic coverage**: 1,600+ cities/municipalities
- **Concurrent users**: 500+
- **Storage**: 10TB+ raw data

## 🔐 Security Features

### Database Security
- **Row-Level Security (RLS)**: Multi-tenant isolation
- **Column-Level Encryption**: PII data protection
- **Audit Logging**: Complete query audit trail
- **Secret Rotation**: Automated credential rotation

### Infrastructure Security
- **Network Policies**: Zero-trust networking
- **OPA Gatekeeper**: Policy-as-code admission control
- **mTLS**: Service-to-service encryption
- **RBAC**: Fine-grained access control

### Application Security
- **CSRF Protection**: Enabled for all state-changing operations
- **JWT Authentication**: Short-lived tokens with refresh
- **API Rate Limiting**: DDoS protection
- **Input Validation**: SQL injection prevention

## 🛠️ Operations

### Available Scripts
```bash
# Development
pnpm run dev          # Start all services in dev mode
pnpm run build        # Build all packages
pnpm run test         # Run all tests
pnpm run lint         # Lint all code
pnpm run typecheck    # TypeScript checking

# Docker
pnpm run docker:build # Build all images
pnpm run docker:push  # Push to registry

# Database
pnpm run db:migrate   # Run migrations
pnpm run db:seed      # Seed test data
pnpm run dq:check     # Run data quality checks
```

### Service Endpoints
- **API Service**: http://localhost:8000/docs (Swagger UI)
- **Worker Service**: http://localhost:3000/health
- **Brand Model**: http://localhost:8001/docs
- **PostgreSQL**: localhost:5432

### Docker Images
Published automatically to GitHub Container Registry:
```bash
# Pull latest images
docker pull ghcr.io/jgtolentino/ai-aas-hardened-lakehouse-api:latest
docker pull ghcr.io/jgtolentino/ai-aas-hardened-lakehouse-worker:latest
docker pull ghcr.io/jgtolentino/ai-aas-hardened-lakehouse-brand-model:latest
```

## 📚 Documentation

- [Architecture Overview](ARCHITECTURE_FLOW.md)
- [Monorepo Structure](docs/monorepo-structure.md)
- [CI/CD Pipeline](docs/cicd-pipeline.md)
- [Database Schema](docs/database-schema.md)
- [API Documentation](services/api/README.md)
- [Deployment Guide](DEPLOYMENT_CHECKLIST.md)
- [Security Hardening](docs/security/hardening-guide.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Install dependencies: `pnpm install`
4. Make changes and test: `pnpm run test`
5. Commit changes (`git commit -m 'feat: add amazing feature'`)
6. Push to branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Commit Message Format
Follow conventional commits:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `chore:` Maintenance
- `test:` Tests
- `refactor:` Code refactoring

### Pull Request Requirements
- All CI checks must pass
- Code review approval required
- Branch must be up-to-date with main
- Commits will be squashed on merge

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details

## 🙏 Acknowledgments

Built with best-in-class open source technologies:
- **Apache Superset** - Modern data exploration and visualization
- **PostGIS** - Spatial and geographic objects for PostgreSQL
- **Apache Trino** - Fast distributed SQL query engine
- **Apache Iceberg** - High-performance table format
- **dbt** - Transform data in your warehouse
- **MinIO** - High-performance object storage
- **Bruno** - Fast and Git-friendly API client

Special thanks to the Philippine Statistics Authority for PSGC geographic codes.

## 🚨 Recent Updates

### v2.0.0 - Monorepo Migration (January 2025)
- Migrated from submodules to production-grade monorepo structure
- Implemented pnpm workspaces + Turborepo for build orchestration
- Added comprehensive CI/CD with GitHub Actions
- Set up automated Docker image publishing to GHCR
- Implemented branch protection with required status checks
- Stabilized all workflows and fixed dependency issues

---

🚀 **Production Grade Monorepo** | 🔐 **Enterprise Hardened** | 🌍 **Geographic Enabled** | 📊 **Complete Data Stack**

For questions or support, please open an issue or contact the maintainers.

<!-- AUTO-GEN:STRUCTURE START -->
## Project Structure (auto)

```
project-root/
├─ apps/
│  ├─ docs/
│  ├─ pi-edge/
│  │  ├─ docs/
│  │  ├─ edge-device/
│  │  ├─ fixtures/
│  │  ├─ node_modules/
│  │  ├─ packages/
│  │  ├─ platform/
│  │  ├─ public/
│  │  ├─ samples/
│  │  ├─ scripts/
│  │  ├─ sql/
│  │  ├─ src/
│  │  ├─ supabase/
│  ├─ scout-dashboard/
│  │  ├─ node_modules/
├─ services/
│  ├─ api/
│  │  ├─ node_modules/
│  ├─ brand-model/
│  ├─ worker/
│  │  ├─ node_modules/
├─ packages/
│  ├─ contracts/
│  │  ├─ node_modules/
│  │  ├─ sql/
│  │  ├─ src/
│  ├─ services/
│  │  ├─ src/
│  ├─ shared-types/
│  ├─ types/
│  ├─ utils-js/
│  ├─ utils-py/
├─ db/
│  ├─ migrations/
│  ├─ seeds/
│  ├─ tests/
├─ dq/
│  ├─ checks/
│  ├─ views/
├─ supabase/
│  ├─ config/
│  ├─ functions/
│  │  ├─ export-platinum/
│  │  ├─ ingest-bronze/
│  ├─ migrations/
│  ├─ storage/
├─ infra/
│  ├─ docker/
│  ├─ k8s/
│  │  ├─ base/
│  │  ├─ overlays/
│  ├─ terraform/
│  │  ├─ envs/
│  │  ├─ modules/
├─ monitoring/
│  ├─ grafana-dashboards/
│  ├─ prometheus/
├─ security/
│  ├─ policies/
│  ├─ sops/
│  ├─ threat-model/
├─ .github/workflows/
```

<!-- AUTO-GEN:STRUCTURE END -->

<!-- AUTO-GEN:SERVICES START -->
## Services & Ports (auto)

| Service | Exposed Ports |
|---|---|
| `postgres` | 5432->5432 |
| `api` | 8000->8000 |
| `worker` | 3000->3000 |
| `brand-model` | 8001->8001 |


<!-- AUTO-GEN:SERVICES END -->

<!-- AUTO-GEN:WORKFLOWS START -->
## Active Workflows (auto)

- `ci.yml`
- `dataset-publisher-tests.yml`
- `edge-functions.yml`
- `readme-guard.yml`
- `release-images.yml`
- `security-scan.yml`
- `storage-buckets.yml`

<!-- AUTO-GEN:WORKFLOWS END -->
