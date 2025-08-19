# Scout Analytics Platform - Data Flow Architecture

## Overview

This document illustrates how data flows through the Scout Analytics Platform from ingestion to visualization, showing all dimension and fact tables involved in the process.

## High-Level Data Flow

```mermaid
graph TB
    subgraph "Data Sources"
        A1[SRP Scraping]
        A2[Retailer APIs]
        A3[Store Transactions]
        A4[IoT Sensors]
        A5[Audio Transcripts]
    end
    
    subgraph "Ingestion Layer"
        B1[Worker Jobs]
        B2[Edge Functions]
        B3[Brand Detector API]
    end
    
    subgraph "Bronze Layer (Raw)"
        C1[reference.srp_prices]
        C2[bronze.transcripts]
        C3[bronze.raw_transactions]
        C4[bronze.sensor_readings]
    end
    
    subgraph "Silver Layer (Validated)"
        D1[scout.brand_catalog]
        D2[scout.product_catalog]
        D3[scout.processed_transcripts]
        D4[scout_silver.transactions]
    end
    
    subgraph "Gold Layer (Business)"
        E1[scout_gold.dim_products]
        E2[scout_gold.dim_stores]
        E3[scout_gold.dim_customers]
        E4[scout_gold.dim_brands]
        E5[scout_gold.dim_time]
        E6[scout_gold.fact_transactions]
    end
    
    subgraph "Platinum Layer (Analytics)"
        F1[scout_platinum.brand_performance]
        F2[scout_platinum.store_analytics]
        F3[scout_platinum.customer_segments]
    end
    
    subgraph "Applications"
        G1[Scout Dashboard]
        G2[Brand Dashboard]
        G3[Retail Assistant]
    end
    
    A1 --> B1
    A2 --> B1
    A3 --> B2
    A4 --> B2
    A5 --> B3
    
    B1 --> C1
    B2 --> C3
    B2 --> C4
    B3 --> C2
    
    C1 --> D1
    C1 --> D2
    C2 --> D3
    C3 --> D4
    
    D1 --> E4
    D2 --> E1
    D3 --> E6
    D4 --> E6
    
    E1 --> F1
    E2 --> F2
    E3 --> F3
    E4 --> F1
    E5 --> F2
    E6 --> F1
    E6 --> F2
    E6 --> F3
    
    F1 --> G1
    F2 --> G1
    F3 --> G1
    F1 --> G2
    D3 --> G3
```

## Detailed Table Relationships

### Dimension Tables (scout_gold schema)

```mermaid
erDiagram
    dim_products {
        bigint product_id PK
        bigint brand_id FK
        text product_name
        text sku
        text category
        text subcategory
        decimal base_price
        boolean is_active
        timestamp created_at
        timestamp updated_at
    }
    
    dim_brands {
        bigint brand_id PK
        text brand_name
        text manufacturer
        text country_origin
        boolean is_tobacco
        boolean is_active
        timestamp created_at
    }
    
    dim_stores {
        bigint store_id PK
        text store_name
        text store_type
        text address
        text city
        text region
        point location
        boolean has_iot
        boolean is_active
        timestamp created_at
    }
    
    dim_customers {
        bigint customer_id PK
        text customer_type
        text segment
        jsonb demographics
        timestamp first_purchase
        timestamp last_purchase
    }
    
    dim_time {
        date date_key PK
        int year
        int quarter
        int month
        int week
        int day_of_week
        text month_name
        text day_name
        boolean is_weekend
        boolean is_holiday
    }
    
    dim_products ||--o{ dim_brands : "belongs to"
```

### Fact Tables

```mermaid
erDiagram
    fact_transactions {
        bigint transaction_id PK
        bigint product_id FK
        bigint store_id FK
        bigint customer_id FK
        date transaction_date FK
        timestamp transaction_timestamp
        int quantity
        decimal unit_price
        decimal total_amount
        decimal discount_amount
        text payment_method
        text source_system
        jsonb metadata
    }
    
    fact_inventory {
        bigint inventory_id PK
        bigint product_id FK
        bigint store_id FK
        date snapshot_date FK
        int quantity_on_hand
        int quantity_reserved
        int reorder_point
        decimal cost_value
        timestamp last_updated
    }
    
    fact_brand_performance {
        bigint performance_id PK
        bigint brand_id FK
        bigint store_id FK
        date period_date FK
        decimal revenue
        int units_sold
        int transaction_count
        decimal market_share
        decimal growth_rate
    }
    
    fact_transactions ||--o{ dim_products : "contains"
    fact_transactions ||--o{ dim_stores : "occurs at"
    fact_transactions ||--o{ dim_customers : "made by"
    fact_transactions ||--o{ dim_time : "happens on"
```

## Data Processing Pipeline

### 1. Ingestion Phase

```sql
-- SRP Data Ingestion (Worker Job)
INSERT INTO reference.srp_prices (
    store_name, address, source, product, 
    current_price, promo_price, scraped_at
)
SELECT * FROM staging.srp_import;

-- Transaction Ingestion (Edge Function)
INSERT INTO bronze.raw_transactions (
    store_id, product_description, amount, 
    quantity, timestamp, metadata
)
VALUES ($1, $2, $3, $4, $5, $6);
```

### 2. Brand Detection & Enrichment

```sql
-- Process transcript through brand detector
SELECT scout.process_transcript(
    transaction_id := 'TXN-001',
    text_input := 'Kuya, may Lucky Me ba kayo?'
) AS result;

-- Result enriches transaction with brand
UPDATE scout_silver.transactions
SET 
    detected_brand_id = (result->>'brand_id')::bigint,
    brand_confidence = (result->>'confidence')::decimal
WHERE transaction_id = 'TXN-001';
```

### 3. Silver Layer Processing

```sql
-- Consolidate and validate products
INSERT INTO scout.product_catalog (
    brand_id, product_name, sku, category
)
SELECT DISTINCT
    b.brand_id,
    p.product_name,
    p.sku,
    p.category
FROM staging.product_import p
JOIN scout.brand_catalog b ON b.brand_name = p.brand_name
WHERE p.is_valid = true;
```

### 4. Gold Layer Transformation

```sql
-- Build fact table from silver
INSERT INTO scout_gold.fact_transactions (
    transaction_id, product_id, store_id, customer_id,
    transaction_date, transaction_timestamp,
    quantity, unit_price, total_amount
)
SELECT 
    t.transaction_id,
    p.product_id,
    s.store_id,
    COALESCE(c.customer_id, -1), -- Unknown customer
    DATE(t.timestamp),
    t.timestamp,
    t.quantity,
    t.unit_price,
    t.total_amount
FROM scout_silver.transactions t
JOIN scout_gold.dim_products p ON p.sku = t.product_sku
JOIN scout_gold.dim_stores s ON s.store_id = t.store_id
LEFT JOIN scout_gold.dim_customers c ON c.customer_id = t.customer_id
WHERE t.is_processed = false;
```

### 5. Platinum Layer Analytics

```sql
-- Aggregate brand performance
INSERT INTO scout_platinum.brand_performance (
    brand_id, store_id, period_date,
    revenue, units_sold, transaction_count
)
SELECT 
    p.brand_id,
    f.store_id,
    f.transaction_date,
    SUM(f.total_amount) as revenue,
    SUM(f.quantity) as units_sold,
    COUNT(DISTINCT f.transaction_id) as transaction_count
FROM scout_gold.fact_transactions f
JOIN scout_gold.dim_products p ON p.product_id = f.product_id
GROUP BY p.brand_id, f.store_id, f.transaction_date;
```

## Real-Time Data Flow

```mermaid
sequenceDiagram
    participant User
    participant Dashboard
    participant API
    participant EdgeFunc
    participant Database
    participant Detector
    
    User->>Dashboard: View real-time metrics
    Dashboard->>API: GET /api/gold/kpis
    API->>Database: Query fact_transactions
    Database-->>API: Return aggregated data
    API-->>Dashboard: JSON response
    Dashboard-->>User: Display KPIs
    
    User->>Dashboard: Submit transaction
    Dashboard->>EdgeFunc: POST /ingest-transaction
    EdgeFunc->>Detector: Detect brands
    Detector-->>EdgeFunc: Brand predictions
    EdgeFunc->>Database: Insert enriched data
    Database-->>EdgeFunc: Confirmation
    EdgeFunc-->>Dashboard: Success response
    Dashboard-->>User: Update view
```

## Key Data Transformations

### 1. Brand Resolution
```
Raw: "Lucky Me Pancit Canton Original 60g"
  ↓ Brand Detector
Detected: brand_id: 123, brand_name: "Lucky Me", confidence: 0.95
  ↓ Catalog Lookup
Enriched: manufacturer: "Monde Nissin", category: "Instant Noodles"
```

### 2. Geographic Enrichment
```
Raw: store_address: "123 Ayala Ave, Makati"
  ↓ Geocoding
Enriched: region: "NCR", city: "Makati", coordinates: [14.5547, 121.0244]
  ↓ Boundary Match
Tagged: barangay: "Bel-Air", district: "CBD"
```

### 3. Customer Segmentation
```
Raw: transaction_history: [{...}, {...}, {...}]
  ↓ Analytics
Segment: "Frequent Buyer", demographics: {gender: "female", age_group: "25-34"}
  ↓ Scoring
Value: lifetime_value: 45000, churn_risk: "low"
```

## Dashboard Data Access Patterns

### Executive Dashboard (scout_gold views)
```sql
-- Real-time KPIs
CREATE VIEW scout_gold.v_executive_dashboard AS
SELECT 
    COUNT(DISTINCT f.transaction_id) as total_transactions,
    COUNT(DISTINCT f.store_id) as active_stores,
    COUNT(DISTINCT f.customer_id) as unique_customers,
    SUM(f.total_amount) as total_revenue,
    AVG(f.total_amount) as avg_transaction_value
FROM scout_gold.fact_transactions f
WHERE f.transaction_date >= CURRENT_DATE - INTERVAL '30 days';

-- Brand Performance
CREATE VIEW scout_gold.v_brand_performance AS
SELECT 
    b.brand_name,
    COUNT(DISTINCT f.transaction_id) as transaction_count,
    SUM(f.total_amount) as revenue,
    AVG(f.total_amount) as avg_transaction_value
FROM scout_gold.fact_transactions f
JOIN scout_gold.dim_products p ON p.product_id = f.product_id
JOIN scout_gold.dim_brands b ON b.brand_id = p.brand_id
GROUP BY b.brand_name;
```

### Geographic Analysis
```sql
-- Regional Distribution
CREATE VIEW scout_gold.v_regional_sales AS
SELECT 
    s.region,
    s.city,
    COUNT(DISTINCT f.transaction_id) as transactions,
    SUM(f.total_amount) as revenue,
    COUNT(DISTINCT f.customer_id) as customers
FROM scout_gold.fact_transactions f
JOIN scout_gold.dim_stores s ON s.store_id = f.store_id
GROUP BY s.region, s.city;
```

## Data Quality Checks

```sql
-- Completeness
SELECT 
    'fact_transactions' as table_name,
    COUNT(*) as total_rows,
    COUNT(product_id) as non_null_products,
    COUNT(store_id) as non_null_stores,
    COUNT(customer_id) as non_null_customers
FROM scout_gold.fact_transactions;

-- Referential Integrity
SELECT 
    COUNT(*) as orphaned_transactions
FROM scout_gold.fact_transactions f
LEFT JOIN scout_gold.dim_products p ON p.product_id = f.product_id
WHERE p.product_id IS NULL;
```

## Performance Optimization

1. **Partitioning**: Fact tables partitioned by transaction_date
2. **Indexing**: B-tree indexes on all foreign keys
3. **Materialized Views**: Pre-aggregated metrics refresh hourly
4. **Compression**: Historical partitions use ZSTD compression
5. **Caching**: Redis cache for frequently accessed dimensions

## Summary

The Scout Analytics Platform processes data through a medallion architecture (Bronze → Silver → Gold → Platinum), with clear separation between raw ingestion, validation/enrichment, business modeling, and analytics layers. The star schema in the Gold layer provides optimal query performance for dashboard visualizations while maintaining data quality and consistency.