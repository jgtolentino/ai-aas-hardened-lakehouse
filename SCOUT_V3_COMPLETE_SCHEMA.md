# Scout Analytics Platform v3.0 - Complete Schema & API Documentation

## 📋 Table of Contents
1. [Schema Overview](#schema-overview)
2. [Database Objects](#database-objects)
3. [ETL Pipeline](#etl-pipeline)
4. [API Documentation](#api-documentation)
5. [Data Flow Architecture](#data-flow-architecture)
6. [Security & RLS](#security--rls)

---

## 🏗️ Schema Overview

### Medallion Architecture Layers

```sql
-- Scout v3 uses a medallion architecture with 4 layers:
-- Bronze → Silver → Gold → Platinum

CREATE SCHEMA IF NOT EXISTS scout;       -- Main operational schema
CREATE SCHEMA IF NOT EXISTS bronze;      -- Raw data ingestion
CREATE SCHEMA IF NOT EXISTS silver;      -- Cleansed & standardized
CREATE SCHEMA IF NOT EXISTS gold;        -- Business-ready aggregates
CREATE SCHEMA IF NOT EXISTS platinum;    -- AI & predictive analytics
```

---

## 📊 Database Objects

### 1. BRONZE LAYER - Raw Data Ingestion

```sql
-- =====================================================
-- BRONZE LAYER: Raw data landing zone
-- =====================================================

-- Raw transaction ingestion from edge devices
CREATE TABLE IF NOT EXISTS scout.bronze_edge_raw (
    source_file TEXT NOT NULL,
    entry_name TEXT NOT NULL,
    txn_id TEXT,
    payload JSONB NOT NULL,
    ingested_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (source_file, entry_name)
);

-- Bronze transactions staging
CREATE TABLE IF NOT EXISTS scout.bronze_transactions (
    raw_id BIGSERIAL PRIMARY KEY,
    source_system VARCHAR(50),
    raw_data JSONB NOT NULL,
    ingestion_timestamp TIMESTAMP DEFAULT NOW(),
    processing_status VARCHAR(20) DEFAULT 'pending',
    error_message TEXT
);

-- Bronze products staging
CREATE TABLE IF NOT EXISTS scout.bronze_products (
    raw_id BIGSERIAL PRIMARY KEY,
    source_system VARCHAR(50),
    raw_data JSONB NOT NULL,
    ingestion_timestamp TIMESTAMP DEFAULT NOW(),
    processing_status VARCHAR(20) DEFAULT 'pending'
);

-- Indexes for bronze layer
CREATE INDEX idx_bronze_edge_source ON scout.bronze_edge_raw(source_file);
CREATE INDEX idx_bronze_edge_txn ON scout.bronze_edge_raw(txn_id);
CREATE INDEX idx_bronze_trans_status ON scout.bronze_transactions(processing_status);
CREATE INDEX idx_bronze_trans_timestamp ON scout.bronze_transactions(ingestion_timestamp);
```

### 2. SILVER LAYER - Cleansed Data

```sql
-- =====================================================
-- SILVER LAYER: Cleansed and standardized data
-- =====================================================

-- Silver transactions (validated and enriched)
CREATE TABLE IF NOT EXISTS scout.silver_transactions (
    txn_id TEXT PRIMARY KEY,
    data JSONB NOT NULL,
    loaded_at TIMESTAMPTZ DEFAULT NOW(),
    source_file TEXT NOT NULL
);

-- Silver data quality metrics
CREATE TABLE IF NOT EXISTS scout.silver_dq_metrics (
    metric_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(100),
    metric_name VARCHAR(100),
    metric_value NUMERIC,
    measured_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for silver layer
CREATE INDEX idx_silver_trans_source ON scout.silver_transactions(source_file);
CREATE INDEX idx_silver_trans_loaded ON scout.silver_transactions(loaded_at);
CREATE INDEX idx_silver_trans_data ON scout.silver_transactions USING gin(data);
```

### 3. GOLD LAYER - Fact & Dimension Tables

```sql
-- =====================================================
-- GOLD LAYER: Business-ready star schema
-- =====================================================

-- FACT TABLES
-- Main transaction fact table
CREATE TABLE IF NOT EXISTS scout.fact_transactions (
    transaction_id VARCHAR(50) PRIMARY KEY,
    store_id VARCHAR(20) NOT NULL,
    customer_id VARCHAR(50),
    campaign_id VARCHAR(50),
    transaction_date DATE NOT NULL,
    transaction_time TIME NOT NULL,
    total_amount NUMERIC(12,2) NOT NULL,
    discount_amount NUMERIC(12,2) DEFAULT 0,
    tax_amount NUMERIC(12,2),
    payment_method VARCHAR(50),
    status scout.txn_status NOT NULL,
    source_file TEXT NOT NULL,
    
    -- Dimension keys for star schema
    date_key INTEGER,
    time_key INTEGER,
    store_key INTEGER,
    customer_key INTEGER,
    campaign_key INTEGER,
    payment_key INTEGER,
    
    -- Additional fields for AI/ML
    items JSONB DEFAULT '[]'::JSONB,
    transcript TEXT,
    brand_detection_status VARCHAR(20) DEFAULT 'pending',
    customer_gender VARCHAR(10),
    customer_age_group VARCHAR(20),
    confidence_demographics NUMERIC(3,2),
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Transaction items fact table
CREATE TABLE IF NOT EXISTS scout.fact_transaction_items (
    transaction_id VARCHAR(50) NOT NULL,
    line_item_id INTEGER NOT NULL,
    sku VARCHAR(50) NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    line_amount NUMERIC(12,2) NOT NULL,
    discount_amount NUMERIC(10,2) DEFAULT 0,
    source_file TEXT NOT NULL,
    
    -- Product enrichment
    product_key INTEGER,
    brand_name VARCHAR(100),
    brand_id INTEGER,
    category_name VARCHAR(100),
    category_id INTEGER,
    detection_method VARCHAR(50),
    confidence NUMERIC(3,2),
    
    created_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (transaction_id, line_item_id)
);

-- Daily sales aggregate fact
CREATE TABLE IF NOT EXISTS scout.fact_daily_sales (
    date_key INTEGER NOT NULL,
    store_key INTEGER NOT NULL,
    product_key INTEGER NOT NULL,
    transaction_count INTEGER DEFAULT 0,
    quantity_sold INTEGER DEFAULT 0,
    gross_sales NUMERIC(12,2) DEFAULT 0,
    net_sales NUMERIC(12,2) DEFAULT 0,
    unique_customers INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (date_key, store_key, product_key)
);

-- DIMENSION TABLES
-- Date dimension
CREATE TABLE IF NOT EXISTS scout.dim_date (
    date_key INTEGER PRIMARY KEY,
    full_date DATE UNIQUE NOT NULL,
    year INTEGER NOT NULL,
    quarter INTEGER NOT NULL,
    month INTEGER NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    month_short VARCHAR(3) NOT NULL,
    week_of_year INTEGER NOT NULL,
    day_of_month INTEGER NOT NULL,
    day_of_week INTEGER NOT NULL,
    day_name VARCHAR(20) NOT NULL,
    day_short VARCHAR(3) NOT NULL,
    is_weekend BOOLEAN NOT NULL,
    is_holiday BOOLEAN DEFAULT FALSE,
    holiday_name VARCHAR(100),
    fiscal_year INTEGER,
    fiscal_quarter INTEGER,
    fiscal_month INTEGER
);

-- Time dimension
CREATE TABLE IF NOT EXISTS scout.dim_time (
    time_key INTEGER PRIMARY KEY,
    full_time TIME UNIQUE NOT NULL,
    hour INTEGER NOT NULL,
    minute INTEGER NOT NULL,
    second INTEGER NOT NULL,
    hour_12 INTEGER NOT NULL,
    am_pm VARCHAR(2) NOT NULL,
    time_of_day VARCHAR(20) NOT NULL,
    business_hours BOOLEAN NOT NULL,
    peak_hours BOOLEAN NOT NULL
);

-- Store dimension
CREATE TABLE IF NOT EXISTS scout.dim_stores (
    store_key SERIAL PRIMARY KEY,
    store_id VARCHAR(20) UNIQUE NOT NULL,
    store_name VARCHAR(200),
    store_type VARCHAR(50),
    barangay VARCHAR(100),
    city VARCHAR(100),
    province VARCHAR(100),
    region VARCHAR(50),
    island_group VARCHAR(20),
    store_size VARCHAR(20),
    economic_class VARCHAR(10),
    urban_rural VARCHAR(10),
    date_opened DATE,
    date_closed DATE,
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE,
    is_current BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    -- Additional fields
    district VARCHAR(100),
    operating_hours VARCHAR(50),
    manager_name VARCHAR(100),
    latitude NUMERIC(10,7),
    longitude NUMERIC(10,7)
);

-- Customer dimension
CREATE TABLE IF NOT EXISTS scout.dim_customers (
    customer_key SERIAL PRIMARY KEY,
    customer_id VARCHAR(50) UNIQUE NOT NULL,
    customer_name VARCHAR(200),
    customer_type VARCHAR(50),
    gender VARCHAR(10),
    age_group VARCHAR(20),
    income_bracket VARCHAR(50),
    economic_class VARCHAR(10),
    barangay VARCHAR(100),
    city VARCHAR(100),
    province VARCHAR(100),
    customer_segment VARCHAR(50),
    preferred_payment VARCHAR(50),
    first_purchase_date DATE,
    last_purchase_date DATE,
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE,
    is_current BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    -- Additional CRM fields
    loyalty_tier VARCHAR(20) DEFAULT 'Bronze',
    preferred_daypart VARCHAR(20),
    preferred_category VARCHAR(50),
    lifetime_value NUMERIC(12,2),
    purchase_frequency VARCHAR(20)
);

-- Product dimension
CREATE TABLE IF NOT EXISTS scout.dim_products (
    product_key SERIAL PRIMARY KEY,
    product_id VARCHAR(50),
    sku VARCHAR(50) UNIQUE NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    category_id VARCHAR(20),
    category_name VARCHAR(100),
    subcategory_id VARCHAR(20),
    subcategory_name VARCHAR(100),
    brand_id VARCHAR(20),
    brand_name VARCHAR(100),
    product_type VARCHAR(50),
    package_size VARCHAR(50),
    unit_of_measure VARCHAR(20),
    standard_cost NUMERIC(10,2),
    list_price NUMERIC(10,2),
    is_active BOOLEAN DEFAULT TRUE,
    launch_date DATE,
    discontinue_date DATE,
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE,
    is_current BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    -- Additional attributes
    size_variant VARCHAR(50),
    flavor_variant VARCHAR(50),
    barcode VARCHAR(50),
    manufacturer VARCHAR(100),
    halal_certified BOOLEAN,
    product_description TEXT,
    price_source VARCHAR(50)
);

-- Campaign dimension
CREATE TABLE IF NOT EXISTS scout.dim_campaigns (
    campaign_key SERIAL PRIMARY KEY,
    campaign_id VARCHAR(50) UNIQUE NOT NULL,
    campaign_name VARCHAR(200),
    campaign_type VARCHAR(50),
    description TEXT,
    discount_type VARCHAR(20),
    discount_value NUMERIC(10,2),
    start_date DATE,
    end_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    -- Additional fields
    target_segment VARCHAR(50),
    budget_amount NUMERIC(12,2),
    actual_spend NUMERIC(12,2),
    roi_target NUMERIC(5,2),
    channel VARCHAR(50)
);

-- Payment methods dimension
CREATE TABLE IF NOT EXISTS scout.dim_payment_methods (
    payment_key SERIAL PRIMARY KEY,
    payment_method VARCHAR(50) UNIQUE NOT NULL,
    payment_category VARCHAR(50),
    is_digital BOOLEAN DEFAULT FALSE,
    processing_fee_pct NUMERIC(5,2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create foreign key constraints
ALTER TABLE scout.fact_transactions
    ADD CONSTRAINT fk_fact_trans_date FOREIGN KEY (date_key) REFERENCES scout.dim_date(date_key),
    ADD CONSTRAINT fk_fact_trans_time FOREIGN KEY (time_key) REFERENCES scout.dim_time(time_key),
    ADD CONSTRAINT fk_fact_trans_store FOREIGN KEY (store_key) REFERENCES scout.dim_stores(store_key),
    ADD CONSTRAINT fk_fact_trans_customer FOREIGN KEY (customer_key) REFERENCES scout.dim_customers(customer_key),
    ADD CONSTRAINT fk_fact_trans_campaign FOREIGN KEY (campaign_key) REFERENCES scout.dim_campaigns(campaign_key),
    ADD CONSTRAINT fk_fact_trans_payment FOREIGN KEY (payment_key) REFERENCES scout.dim_payment_methods(payment_key);

ALTER TABLE scout.fact_transaction_items
    ADD CONSTRAINT fk_fact_items_product FOREIGN KEY (product_key) REFERENCES scout.dim_products(product_key);

ALTER TABLE scout.fact_daily_sales
    ADD CONSTRAINT fk_daily_date FOREIGN KEY (date_key) REFERENCES scout.dim_date(date_key),
    ADD CONSTRAINT fk_daily_store FOREIGN KEY (store_key) REFERENCES scout.dim_stores(store_key),
    ADD CONSTRAINT fk_daily_product FOREIGN KEY (product_key) REFERENCES scout.dim_products(product_key);
```

### 4. PLATINUM LAYER - AI & Analytics

```sql
-- =====================================================
-- PLATINUM LAYER: Advanced analytics and AI
-- =====================================================

-- AI-driven insights
CREATE TABLE IF NOT EXISTS scout.platinum_insights (
    insight_id SERIAL PRIMARY KEY,
    insight_type VARCHAR(50),
    insight_category VARCHAR(50),
    title VARCHAR(200),
    description TEXT,
    impact_score NUMERIC(3,2),
    confidence_score NUMERIC(3,2),
    recommendation TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

-- Predictive models output
CREATE TABLE IF NOT EXISTS scout.platinum_predictions (
    prediction_id SERIAL PRIMARY KEY,
    model_name VARCHAR(100),
    model_version VARCHAR(20),
    entity_type VARCHAR(50),
    entity_id VARCHAR(50),
    prediction_date DATE,
    prediction_type VARCHAR(50),
    predicted_value NUMERIC,
    confidence_interval JSONB,
    features_used JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Customer segments
CREATE TABLE IF NOT EXISTS scout.platinum_customer_segments (
    segment_id SERIAL PRIMARY KEY,
    customer_key INTEGER REFERENCES scout.dim_customers(customer_key),
    segment_name VARCHAR(50),
    segment_score NUMERIC(3,2),
    characteristics JSONB,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    is_current BOOLEAN DEFAULT TRUE
);

-- Brand performance metrics
CREATE TABLE IF NOT EXISTS scout.platinum_brand_metrics (
    metric_id SERIAL PRIMARY KEY,
    brand_id VARCHAR(20),
    metric_date DATE,
    market_share NUMERIC(5,2),
    growth_rate NUMERIC(5,2),
    loyalty_index NUMERIC(3,2),
    competitive_position INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 🔄 ETL Pipeline

### ETL Control Tables

```sql
-- =====================================================
-- ETL PIPELINE MANAGEMENT
-- =====================================================

-- ETL job queue
CREATE TABLE IF NOT EXISTS scout.etl_queue (
    id BIGSERIAL PRIMARY KEY,
    bucket_id TEXT NOT NULL,
    name TEXT NOT NULL,
    size_bytes BIGINT DEFAULT 0,
    mime_type TEXT,
    sha256_hex TEXT,
    status TEXT DEFAULT 'QUEUED' CHECK (status IN ('QUEUED', 'PROCESSING', 'COMPLETED', 'FAILED')),
    attempts INTEGER DEFAULT 0,
    last_error TEXT,
    enqueued_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ
);

-- ETL watermarks for tracking
CREATE TABLE IF NOT EXISTS scout.etl_watermarks (
    obj_id TEXT PRIMARY KEY,
    processed_at TIMESTAMPTZ DEFAULT NOW(),
    ok BOOLEAN DEFAULT FALSE,
    msg TEXT
);

-- ETL failures tracking
CREATE TABLE IF NOT EXISTS scout.etl_failures (
    id BIGSERIAL PRIMARY KEY,
    bucket_id TEXT NOT NULL,
    name TEXT NOT NULL,
    error_msg TEXT NOT NULL,
    attempts INTEGER DEFAULT 1,
    failed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ingestion log
CREATE TABLE IF NOT EXISTS scout.ingestion_log (
    ingestion_id SERIAL PRIMARY KEY,
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(500),
    ingestion_timestamp TIMESTAMP DEFAULT NOW(),
    records_processed INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'pending',
    error_message TEXT,
    metadata JSONB
);
```

### ETL Functions

```sql
-- =====================================================
-- ETL TRANSFORMATION FUNCTIONS
-- =====================================================

-- Bronze to Silver transformation
CREATE OR REPLACE FUNCTION scout.transform_bronze_to_silver()
RETURNS INTEGER AS $$
DECLARE
    processed_count INTEGER := 0;
BEGIN
    -- Process pending bronze transactions
    INSERT INTO scout.silver_transactions (txn_id, data, source_file)
    SELECT 
        raw_data->>'id' AS txn_id,
        jsonb_build_object(
            'store_id', raw_data->>'store_id',
            'timestamp', (raw_data->>'timestamp')::TIMESTAMPTZ,
            'location', raw_data->'location',
            'duration_seconds', (raw_data->>'duration_seconds')::NUMERIC,
            'is_tbwa_client', (raw_data->>'is_tbwa_client')::BOOLEAN,
            'brand_name', NULLIF(raw_data->>'brand_name', 'unspecified'),
            'sku', NULLIF(raw_data->>'sku', 'unspecified'),
            'product_category', NULLIF(raw_data->>'product_category', 'unspecified'),
            'units_per_transaction', (raw_data->>'units_per_transaction')::INTEGER,
            'request_type', raw_data->>'request_type',
            'suggestion_accepted', (raw_data->>'suggestion_accepted')::BOOLEAN
        ) AS data,
        source_system AS source_file
    FROM scout.bronze_transactions
    WHERE processing_status = 'pending'
    ON CONFLICT (txn_id) DO UPDATE
    SET data = EXCLUDED.data,
        loaded_at = NOW();
    
    -- Update processing status
    UPDATE scout.bronze_transactions
    SET processing_status = 'processed'
    WHERE processing_status = 'pending';
    
    GET DIAGNOSTICS processed_count = ROW_COUNT;
    RETURN processed_count;
END;
$$ LANGUAGE plpgsql;

-- Silver to Gold transformation
CREATE OR REPLACE FUNCTION scout.transform_silver_to_gold()
RETURNS INTEGER AS $$
DECLARE
    processed_count INTEGER := 0;
BEGIN
    -- Insert into fact_transactions
    INSERT INTO scout.fact_transactions (
        transaction_id,
        store_id,
        transaction_date,
        transaction_time,
        total_amount,
        payment_method,
        status,
        source_file
    )
    SELECT 
        txn_id,
        data->>'store_id',
        (data->>'timestamp')::DATE,
        (data->>'timestamp')::TIME,
        COALESCE((data->>'total_amount')::NUMERIC, 100.00),
        COALESCE(data->>'payment_method', 'cash'),
        'completed'::scout.txn_status,
        source_file
    FROM scout.silver_transactions
    WHERE NOT EXISTS (
        SELECT 1 FROM scout.fact_transactions ft 
        WHERE ft.transaction_id = silver_transactions.txn_id
    );
    
    GET DIAGNOSTICS processed_count = ROW_COUNT;
    RETURN processed_count;
END;
$$ LANGUAGE plpgsql;

-- Refresh Gold aggregates
CREATE OR REPLACE FUNCTION scout.refresh_gold_aggregates()
RETURNS VOID AS $$
BEGIN
    -- Refresh daily sales
    INSERT INTO scout.fact_daily_sales (
        date_key,
        store_key,
        product_key,
        transaction_count,
        quantity_sold,
        gross_sales,
        net_sales,
        unique_customers
    )
    SELECT 
        dd.date_key,
        ds.store_key,
        COALESCE(dp.product_key, 0),
        COUNT(DISTINCT ft.transaction_id),
        SUM(fti.quantity),
        SUM(fti.line_amount),
        SUM(fti.line_amount - COALESCE(fti.discount_amount, 0)),
        COUNT(DISTINCT ft.customer_id)
    FROM scout.fact_transactions ft
    JOIN scout.fact_transaction_items fti ON ft.transaction_id = fti.transaction_id
    JOIN scout.dim_date dd ON ft.transaction_date = dd.full_date
    JOIN scout.dim_stores ds ON ft.store_id = ds.store_id
    LEFT JOIN scout.dim_products dp ON fti.sku = dp.sku
    WHERE ft.transaction_date >= CURRENT_DATE - INTERVAL '1 day'
    GROUP BY dd.date_key, ds.store_key, dp.product_key
    ON CONFLICT (date_key, store_key, product_key) 
    DO UPDATE SET
        transaction_count = EXCLUDED.transaction_count,
        quantity_sold = EXCLUDED.quantity_sold,
        gross_sales = EXCLUDED.gross_sales,
        net_sales = EXCLUDED.net_sales,
        unique_customers = EXCLUDED.unique_customers;
END;
$$ LANGUAGE plpgsql;
```

---

## 📚 API Documentation

### RPC Functions - Dashboard APIs

```sql
-- =====================================================
-- DASHBOARD API FUNCTIONS
-- =====================================================

-- Get Dashboard KPIs
CREATE OR REPLACE FUNCTION scout.get_dashboard_kpis(
    p_date_from DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_date_to DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    total_revenue NUMERIC,
    total_transactions BIGINT,
    unique_customers BIGINT,
    avg_transaction_value NUMERIC,
    top_brand VARCHAR,
    top_category VARCHAR,
    growth_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        SUM(ft.total_amount) AS total_revenue,
        COUNT(DISTINCT ft.transaction_id) AS total_transactions,
        COUNT(DISTINCT ft.customer_id) AS unique_customers,
        AVG(ft.total_amount) AS avg_transaction_value,
        (
            SELECT dp.brand_name 
            FROM scout.fact_transaction_items fti
            JOIN scout.dim_products dp ON fti.product_key = dp.product_key
            WHERE fti.transaction_id IN (
                SELECT transaction_id FROM scout.fact_transactions 
                WHERE transaction_date BETWEEN p_date_from AND p_date_to
            )
            GROUP BY dp.brand_name
            ORDER BY SUM(fti.line_amount) DESC
            LIMIT 1
        ) AS top_brand,
        (
            SELECT dp.category_name 
            FROM scout.fact_transaction_items fti
            JOIN scout.dim_products dp ON fti.product_key = dp.product_key
            WHERE fti.transaction_id IN (
                SELECT transaction_id FROM scout.fact_transactions 
                WHERE transaction_date BETWEEN p_date_from AND p_date_to
            )
            GROUP BY dp.category_name
            ORDER BY SUM(fti.line_amount) DESC
            LIMIT 1
        ) AS top_category,
        (
            SELECT ((current_month.revenue - previous_month.revenue) / previous_month.revenue * 100)
            FROM (
                SELECT SUM(total_amount) AS revenue
                FROM scout.fact_transactions
                WHERE transaction_date >= DATE_TRUNC('month', CURRENT_DATE)
            ) AS current_month,
            (
                SELECT SUM(total_amount) AS revenue
                FROM scout.fact_transactions
                WHERE transaction_date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
                  AND transaction_date < DATE_TRUNC('month', CURRENT_DATE)
            ) AS previous_month
        ) AS growth_rate
    FROM scout.fact_transactions ft
    WHERE ft.transaction_date BETWEEN p_date_from AND p_date_to;
END;
$$ LANGUAGE plpgsql STABLE;

-- Get Sales Trend
CREATE OR REPLACE FUNCTION scout.get_sales_trend(
    p_days INTEGER DEFAULT 30
)
RETURNS TABLE (
    date DATE,
    revenue NUMERIC,
    transactions BIGINT,
    customers BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ft.transaction_date AS date,
        SUM(ft.total_amount) AS revenue,
        COUNT(DISTINCT ft.transaction_id) AS transactions,
        COUNT(DISTINCT ft.customer_id) AS customers
    FROM scout.fact_transactions ft
    WHERE ft.transaction_date >= CURRENT_DATE - (p_days || ' days')::INTERVAL
    GROUP BY ft.transaction_date
    ORDER BY ft.transaction_date;
END;
$$ LANGUAGE plpgsql STABLE;

-- Get Store Performance
CREATE OR REPLACE FUNCTION scout.get_store_performance(
    p_days INTEGER DEFAULT 7
)
RETURNS TABLE (
    store_id VARCHAR,
    store_name VARCHAR,
    city VARCHAR,
    revenue NUMERIC,
    transactions BIGINT,
    avg_basket_size NUMERIC,
    growth_pct NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH current_period AS (
        SELECT 
            ds.store_id,
            ds.store_name,
            ds.city,
            SUM(ft.total_amount) AS revenue,
            COUNT(DISTINCT ft.transaction_id) AS transactions,
            AVG(ft.total_amount) AS avg_basket
        FROM scout.fact_transactions ft
        JOIN scout.dim_stores ds ON ft.store_key = ds.store_key
        WHERE ft.transaction_date >= CURRENT_DATE - (p_days || ' days')::INTERVAL
        GROUP BY ds.store_id, ds.store_name, ds.city
    ),
    previous_period AS (
        SELECT 
            ds.store_id,
            SUM(ft.total_amount) AS revenue
        FROM scout.fact_transactions ft
        JOIN scout.dim_stores ds ON ft.store_key = ds.store_key
        WHERE ft.transaction_date >= CURRENT_DATE - (2 * p_days || ' days')::INTERVAL
          AND ft.transaction_date < CURRENT_DATE - (p_days || ' days')::INTERVAL
        GROUP BY ds.store_id
    )
    SELECT 
        cp.store_id,
        cp.store_name,
        cp.city,
        cp.revenue,
        cp.transactions,
        cp.avg_basket AS avg_basket_size,
        CASE 
            WHEN pp.revenue > 0 THEN 
                ((cp.revenue - pp.revenue) / pp.revenue * 100)::NUMERIC(5,2)
            ELSE 0
        END AS growth_pct
    FROM current_period cp
    LEFT JOIN previous_period pp ON cp.store_id = pp.store_id
    ORDER BY cp.revenue DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Get Product Intelligence
CREATE OR REPLACE FUNCTION scout.get_product_intelligence(
    p_category VARCHAR DEFAULT NULL,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    sku VARCHAR,
    product_name VARCHAR,
    brand_name VARCHAR,
    category_name VARCHAR,
    units_sold BIGINT,
    revenue NUMERIC,
    avg_price NUMERIC,
    velocity_score NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dp.sku,
        dp.product_name,
        dp.brand_name,
        dp.category_name,
        SUM(fti.quantity)::BIGINT AS units_sold,
        SUM(fti.line_amount) AS revenue,
        AVG(fti.unit_price) AS avg_price,
        (SUM(fti.quantity) / NULLIF(COUNT(DISTINCT DATE(ft.transaction_date)), 0))::NUMERIC AS velocity_score
    FROM scout.fact_transaction_items fti
    JOIN scout.fact_transactions ft ON fti.transaction_id = ft.transaction_id
    JOIN scout.dim_products dp ON fti.product_key = dp.product_key
    WHERE (p_category IS NULL OR dp.category_name = p_category)
      AND ft.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY dp.sku, dp.product_name, dp.brand_name, dp.category_name
    ORDER BY revenue DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- Get Customer Segments
CREATE OR REPLACE FUNCTION scout.get_customer_segments()
RETURNS TABLE (
    segment_name VARCHAR,
    customer_count BIGINT,
    avg_transaction_value NUMERIC,
    total_revenue NUMERIC,
    retention_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dc.customer_segment AS segment_name,
        COUNT(DISTINCT dc.customer_key) AS customer_count,
        AVG(ft.total_amount) AS avg_transaction_value,
        SUM(ft.total_amount) AS total_revenue,
        (COUNT(DISTINCT CASE 
            WHEN ft.transaction_date >= CURRENT_DATE - INTERVAL '30 days' 
            THEN dc.customer_key 
        END)::NUMERIC / NULLIF(COUNT(DISTINCT dc.customer_key), 0) * 100) AS retention_rate
    FROM scout.dim_customers dc
    LEFT JOIN scout.fact_transactions ft ON dc.customer_key = ft.customer_key
    WHERE dc.is_current = TRUE
    GROUP BY dc.customer_segment
    ORDER BY total_revenue DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql STABLE;

-- Get Filter Options for Dashboard
CREATE OR REPLACE FUNCTION scout.get_filter_options()
RETURNS TABLE (
    filter_type VARCHAR,
    filter_values JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'regions'::VARCHAR AS filter_type,
           jsonb_agg(DISTINCT region ORDER BY region) AS filter_values
    FROM scout.dim_stores
    WHERE region IS NOT NULL
    
    UNION ALL
    
    SELECT 'cities'::VARCHAR,
           jsonb_agg(DISTINCT city ORDER BY city)
    FROM scout.dim_stores
    WHERE city IS NOT NULL
    
    UNION ALL
    
    SELECT 'categories'::VARCHAR,
           jsonb_agg(DISTINCT category_name ORDER BY category_name)
    FROM scout.dim_products
    WHERE category_name IS NOT NULL
    
    UNION ALL
    
    SELECT 'brands'::VARCHAR,
           jsonb_agg(DISTINCT brand_name ORDER BY brand_name)
    FROM scout.dim_products
    WHERE brand_name IS NOT NULL
    
    UNION ALL
    
    SELECT 'payment_methods'::VARCHAR,
           jsonb_agg(DISTINCT payment_method ORDER BY payment_method)
    FROM scout.dim_payment_methods
    WHERE is_active = TRUE;
END;
$$ LANGUAGE plpgsql STABLE;
```

### API Views for REST Access

```sql
-- =====================================================
-- API VIEWS (PostgREST Compatible)
-- =====================================================

-- Dashboard summary view
CREATE OR REPLACE VIEW scout.v_dashboard_summary AS
SELECT 
    COUNT(DISTINCT ft.transaction_id) AS total_transactions,
    COUNT(DISTINCT ft.customer_id) AS unique_customers,
    COUNT(DISTINCT ft.store_id) AS active_stores,
    SUM(ft.total_amount) AS total_revenue,
    AVG(ft.total_amount) AS avg_transaction_value,
    MAX(ft.transaction_date) AS last_transaction_date
FROM scout.fact_transactions ft
WHERE ft.transaction_date >= CURRENT_DATE - INTERVAL '30 days';

-- Store leaderboard view
CREATE OR REPLACE VIEW scout.v_store_leaderboard AS
SELECT 
    ds.store_id,
    ds.store_name,
    ds.city,
    ds.region,
    COUNT(DISTINCT ft.transaction_id) AS transactions,
    SUM(ft.total_amount) AS revenue,
    AVG(ft.total_amount) AS avg_basket,
    COUNT(DISTINCT ft.customer_id) AS customers
FROM scout.fact_transactions ft
JOIN scout.dim_stores ds ON ft.store_key = ds.store_key
WHERE ft.transaction_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY ds.store_id, ds.store_name, ds.city, ds.region
ORDER BY revenue DESC;

-- Product performance view
CREATE OR REPLACE VIEW scout.v_product_performance AS
SELECT 
    dp.sku,
    dp.product_name,
    dp.brand_name,
    dp.category_name,
    SUM(fti.quantity) AS units_sold,
    SUM(fti.line_amount) AS revenue,
    COUNT(DISTINCT fti.transaction_id) AS transaction_count,
    AVG(fti.unit_price) AS avg_price
FROM scout.fact_transaction_items fti
JOIN scout.dim_products dp ON fti.product_key = dp.product_key
JOIN scout.fact_transactions ft ON fti.transaction_id = ft.transaction_id
WHERE ft.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY dp.sku, dp.product_name, dp.brand_name, dp.category_name
ORDER BY revenue DESC;

-- Time-based sales view
CREATE OR REPLACE VIEW scout.v_hourly_sales AS
SELECT 
    dt.hour,
    dt.time_of_day,
    COUNT(DISTINCT ft.transaction_id) AS transactions,
    SUM(ft.total_amount) AS revenue,
    AVG(ft.total_amount) AS avg_transaction
FROM scout.fact_transactions ft
JOIN scout.dim_time dt ON ft.time_key = dt.time_key
WHERE ft.transaction_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY dt.hour, dt.time_of_day
ORDER BY dt.hour;

-- Source file tracking view
CREATE OR REPLACE VIEW scout.v_source_file_status AS
SELECT 
    source_file,
    COUNT(DISTINCT transaction_id) AS transaction_count,
    MIN(transaction_date) AS first_transaction,
    MAX(transaction_date) AS last_transaction,
    SUM(total_amount) AS total_revenue,
    CASE 
        WHEN source_file LIKE '%.zip' THEN 'ZIP Archive'
        WHEN source_file LIKE '%.json' THEN 'JSON File'
        WHEN source_file LIKE '%.csv' THEN 'CSV File'
        ELSE 'Other'
    END AS file_type
FROM scout.fact_transactions
GROUP BY source_file
ORDER BY last_transaction DESC;
```

---

## 🔀 Data Flow Architecture

### Complete Data Pipeline

```sql
-- =====================================================
-- DATA FLOW ORCHESTRATION
-- =====================================================

-- Master ETL orchestration function
CREATE OR REPLACE FUNCTION scout.run_etl_pipeline()
RETURNS TABLE (
    step VARCHAR,
    records_processed INTEGER,
    status VARCHAR
) AS $$
DECLARE
    bronze_count INTEGER;
    silver_count INTEGER;
    gold_count INTEGER;
BEGIN
    -- Step 1: Bronze to Silver
    bronze_count := scout.transform_bronze_to_silver();
    RETURN QUERY SELECT 'Bronze to Silver'::VARCHAR, bronze_count, 'SUCCESS'::VARCHAR;
    
    -- Step 2: Silver to Gold
    gold_count := scout.transform_silver_to_gold();
    RETURN QUERY SELECT 'Silver to Gold'::VARCHAR, gold_count, 'SUCCESS'::VARCHAR;
    
    -- Step 3: Refresh aggregates
    PERFORM scout.refresh_gold_aggregates();
    RETURN QUERY SELECT 'Refresh Aggregates'::VARCHAR, 0, 'SUCCESS'::VARCHAR;
    
    -- Step 4: Update dimensions
    PERFORM scout.update_dimension_tables();
    RETURN QUERY SELECT 'Update Dimensions'::VARCHAR, 0, 'SUCCESS'::VARCHAR;
    
    -- Step 5: Generate insights
    PERFORM scout.generate_platinum_insights();
    RETURN QUERY SELECT 'Generate Insights'::VARCHAR, 0, 'SUCCESS'::VARCHAR;
END;
$$ LANGUAGE plpgsql;

-- Update dimension tables from staging
CREATE OR REPLACE FUNCTION scout.update_dimension_tables()
RETURNS VOID AS $$
BEGIN
    -- Update store dimension
    INSERT INTO scout.dim_stores (store_id, store_name, city, region)
    SELECT DISTINCT 
        store_id,
        'Store ' || store_id AS store_name,
        city,
        region
    FROM scout.silver_transactions, 
         jsonb_to_record(data->'location') AS x(city TEXT, region TEXT)
    WHERE store_id IS NOT NULL
    ON CONFLICT (store_id) DO UPDATE
    SET updated_at = NOW();
    
    -- Update customer dimension
    INSERT INTO scout.dim_customers (customer_id, customer_name)
    SELECT DISTINCT
        customer_id,
        'Customer ' || customer_id AS customer_name
    FROM scout.fact_transactions
    WHERE customer_id IS NOT NULL
    ON CONFLICT (customer_id) DO UPDATE
    SET last_purchase_date = CURRENT_DATE,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Generate AI insights
CREATE OR REPLACE FUNCTION scout.generate_platinum_insights()
RETURNS VOID AS $$
BEGIN
    -- Clear old insights
    DELETE FROM scout.platinum_insights 
    WHERE expires_at < NOW();
    
    -- Generate store performance insights
    INSERT INTO scout.platinum_insights (
        insight_type,
        insight_category,
        title,
        description,
        impact_score,
        confidence_score,
        recommendation,
        expires_at
    )
    SELECT 
        'performance'::VARCHAR,
        'store'::VARCHAR,
        'Store ' || store_id || ' Performance Alert',
        CASE 
            WHEN growth < -10 THEN 'Store experiencing significant decline'
            WHEN growth > 20 THEN 'Store showing exceptional growth'
            ELSE 'Store performance stable'
        END,
        ABS(growth) / 100.0,
        0.85,
        CASE 
            WHEN growth < -10 THEN 'Investigate operational issues and competition'
            WHEN growth > 20 THEN 'Analyze success factors for replication'
            ELSE 'Maintain current strategies'
        END,
        NOW() + INTERVAL '7 days'
    FROM (
        SELECT 
            store_id,
            ((SUM(CASE WHEN transaction_date >= CURRENT_DATE - 7 THEN total_amount ELSE 0 END) -
              SUM(CASE WHEN transaction_date < CURRENT_DATE - 7 THEN total_amount ELSE 0 END)) /
             NULLIF(SUM(CASE WHEN transaction_date < CURRENT_DATE - 7 THEN total_amount ELSE 0 END), 0) * 100) AS growth
        FROM scout.fact_transactions
        WHERE transaction_date >= CURRENT_DATE - 14
        GROUP BY store_id
    ) AS store_growth
    WHERE ABS(growth) > 10;
END;
$$ LANGUAGE plpgsql;
```

---

## 🔒 Security & RLS

### Row Level Security Policies

```sql
-- =====================================================
-- SECURITY AND RLS POLICIES
-- =====================================================

-- Enable RLS on key tables
ALTER TABLE scout.fact_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.fact_transaction_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.dim_stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.dim_customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.dim_products ENABLE ROW LEVEL SECURITY;

-- Create roles
CREATE ROLE dashboard_viewer;
CREATE ROLE data_analyst;
CREATE ROLE admin_user;

-- RLS Policies for dashboard_viewer (read-only)
CREATE POLICY viewer_read_transactions ON scout.fact_transactions
    FOR SELECT
    TO dashboard_viewer
    USING (transaction_date >= CURRENT_DATE - INTERVAL '90 days');

CREATE POLICY viewer_read_stores ON scout.dim_stores
    FOR SELECT
    TO dashboard_viewer
    USING (is_active = TRUE);

CREATE POLICY viewer_read_products ON scout.dim_products
    FOR SELECT
    TO dashboard_viewer
    USING (is_active = TRUE);

-- RLS Policies for data_analyst (broader access)
CREATE POLICY analyst_read_all_transactions ON scout.fact_transactions
    FOR SELECT
    TO data_analyst
    USING (TRUE);

CREATE POLICY analyst_read_all_stores ON scout.dim_stores
    FOR SELECT
    TO data_analyst
    USING (TRUE);

CREATE POLICY analyst_read_all_products ON scout.dim_products
    FOR SELECT
    TO data_analyst
    USING (TRUE);

-- Grant permissions
GRANT USAGE ON SCHEMA scout TO dashboard_viewer, data_analyst, admin_user;
GRANT SELECT ON ALL TABLES IN SCHEMA scout TO dashboard_viewer;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA scout TO data_analyst;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA scout TO admin_user;

-- Grant function execution
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA scout TO dashboard_viewer, data_analyst;
```

---

## 📊 Sample Data & Testing

### Load Sample Data

```sql
-- =====================================================
-- SAMPLE DATA FOR TESTING
-- =====================================================

-- Populate date dimension
INSERT INTO scout.dim_date (date_key, full_date, year, quarter, month, month_name, 
                           month_short, week_of_year, day_of_month, day_of_week, 
                           day_name, day_short, is_weekend)
SELECT 
    TO_CHAR(d, 'YYYYMMDD')::INTEGER AS date_key,
    d AS full_date,
    EXTRACT(YEAR FROM d)::INTEGER AS year,
    EXTRACT(QUARTER FROM d)::INTEGER AS quarter,
    EXTRACT(MONTH FROM d)::INTEGER AS month,
    TO_CHAR(d, 'Month') AS month_name,
    TO_CHAR(d, 'Mon') AS month_short,
    EXTRACT(WEEK FROM d)::INTEGER AS week_of_year,
    EXTRACT(DAY FROM d)::INTEGER AS day_of_month,
    EXTRACT(DOW FROM d)::INTEGER AS day_of_week,
    TO_CHAR(d, 'Day') AS day_name,
    TO_CHAR(d, 'Dy') AS day_short,
    EXTRACT(DOW FROM d) IN (0, 6) AS is_weekend
FROM generate_series('2020-01-01'::DATE, '2030-12-31'::DATE, '1 day'::INTERVAL) AS d
ON CONFLICT (date_key) DO NOTHING;

-- Populate time dimension
INSERT INTO scout.dim_time (time_key, full_time, hour, minute, second, 
                           hour_12, am_pm, time_of_day, business_hours, peak_hours)
SELECT 
    (EXTRACT(HOUR FROM t) * 10000 + EXTRACT(MINUTE FROM t) * 100 + EXTRACT(SECOND FROM t))::INTEGER AS time_key,
    t::TIME AS full_time,
    EXTRACT(HOUR FROM t)::INTEGER AS hour,
    EXTRACT(MINUTE FROM t)::INTEGER AS minute,
    EXTRACT(SECOND FROM t)::INTEGER AS second,
    CASE 
        WHEN EXTRACT(HOUR FROM t) = 0 THEN 12
        WHEN EXTRACT(HOUR FROM t) > 12 THEN (EXTRACT(HOUR FROM t) - 12)::INTEGER
        ELSE EXTRACT(HOUR FROM t)::INTEGER
    END AS hour_12,
    CASE 
        WHEN EXTRACT(HOUR FROM t) < 12 THEN 'AM'
        ELSE 'PM'
    END AS am_pm,
    CASE 
        WHEN EXTRACT(HOUR FROM t) < 6 THEN 'Night'
        WHEN EXTRACT(HOUR FROM t) < 12 THEN 'Morning'
        WHEN EXTRACT(HOUR FROM t) < 18 THEN 'Afternoon'
        ELSE 'Evening'
    END AS time_of_day,
    EXTRACT(HOUR FROM t) BETWEEN 8 AND 17 AS business_hours,
    EXTRACT(HOUR FROM t) IN (11, 12, 13, 18, 19, 20) AS peak_hours
FROM generate_series('00:00:00'::TIME, '23:59:59'::TIME, '1 second'::INTERVAL) AS t
ON CONFLICT (time_key) DO NOTHING;

-- Sample stores
INSERT INTO scout.dim_stores (store_id, store_name, store_type, city, province, region, island_group)
VALUES 
    ('S001', 'Sari Store Manila', 'Sari-sari', 'Manila', 'Metro Manila', 'NCR', 'Luzon'),
    ('S002', 'Sari Store Quezon', 'Sari-sari', 'Quezon City', 'Metro Manila', 'NCR', 'Luzon'),
    ('S003', 'Sari Store Cebu', 'Sari-sari', 'Cebu City', 'Cebu', 'Region VII', 'Visayas'),
    ('S004', 'Sari Store Davao', 'Sari-sari', 'Davao City', 'Davao del Sur', 'Region XI', 'Mindanao'),
    ('S005', 'Sari Store Makati', 'Convenience', 'Makati', 'Metro Manila', 'NCR', 'Luzon')
ON CONFLICT (store_id) DO NOTHING;

-- Sample products
INSERT INTO scout.dim_products (sku, product_name, category_name, brand_name, list_price)
VALUES 
    ('SKU001', 'Coca-Cola 1.5L', 'Beverages', 'Coca-Cola', 65.00),
    ('SKU002', 'Pepsi 1.5L', 'Beverages', 'Pepsi', 62.00),
    ('SKU003', 'Lucky Me Pancit Canton', 'Instant Noodles', 'Lucky Me', 15.00),
    ('SKU004', 'Kopiko Black 3-in-1', 'Coffee', 'Kopiko', 8.00),
    ('SKU005', 'Safeguard Soap', 'Personal Care', 'Safeguard', 25.00)
ON CONFLICT (sku) DO NOTHING;

-- Sample payment methods
INSERT INTO scout.dim_payment_methods (payment_method, payment_category, is_digital)
VALUES 
    ('cash', 'Cash', FALSE),
    ('gcash', 'E-Wallet', TRUE),
    ('maya', 'E-Wallet', TRUE),
    ('credit_card', 'Card', TRUE),
    ('debit_card', 'Card', TRUE)
ON CONFLICT (payment_method) DO NOTHING;
```

---

## 📈 Performance Optimization

### Indexes and Materialized Views

```sql
-- =====================================================
-- PERFORMANCE OPTIMIZATION
-- =====================================================

-- Critical indexes
CREATE INDEX CONCURRENTLY idx_fact_trans_date ON scout.fact_transactions(transaction_date);
CREATE INDEX CONCURRENTLY idx_fact_trans_store ON scout.fact_transactions(store_id);
CREATE INDEX CONCURRENTLY idx_fact_trans_customer ON scout.fact_transactions(customer_id);
CREATE INDEX CONCURRENTLY idx_fact_items_sku ON scout.fact_transaction_items(sku);
CREATE INDEX CONCURRENTLY idx_fact_items_trans ON scout.fact_transaction_items(transaction_id);

-- Materialized view for dashboard
CREATE MATERIALIZED VIEW scout.mv_dashboard_metrics AS
SELECT 
    DATE(ft.transaction_date) AS date,
    ds.region,
    ds.city,
    dp.category_name,
    dp.brand_name,
    COUNT(DISTINCT ft.transaction_id) AS transactions,
    COUNT(DISTINCT ft.customer_id) AS customers,
    SUM(ft.total_amount) AS revenue,
    AVG(ft.total_amount) AS avg_transaction
FROM scout.fact_transactions ft
JOIN scout.dim_stores ds ON ft.store_key = ds.store_key
LEFT JOIN scout.fact_transaction_items fti ON ft.transaction_id = fti.transaction_id
LEFT JOIN scout.dim_products dp ON fti.product_key = dp.product_key
WHERE ft.transaction_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY 1, 2, 3, 4, 5
WITH DATA;

-- Create index on materialized view
CREATE INDEX idx_mv_dashboard_date ON scout.mv_dashboard_metrics(date);
CREATE INDEX idx_mv_dashboard_region ON scout.mv_dashboard_metrics(region);

-- Refresh function
CREATE OR REPLACE FUNCTION scout.refresh_materialized_views()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY scout.mv_dashboard_metrics;
END;
$$ LANGUAGE plpgsql;

-- Schedule refresh via pg_cron
SELECT cron.schedule('refresh-dashboard-metrics', '0 * * * *', 
    'SELECT scout.refresh_materialized_views()');
```

---

## 🚀 Deployment Commands

```bash
# Deploy to Supabase
psql $DATABASE_URL -f scout_v3_schema.sql

# Verify deployment
psql $DATABASE_URL -c "
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables 
WHERE schemaname = 'scout'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;"

# Test API endpoints
curl -X POST https://your-project.supabase.co/rest/v1/rpc/get_dashboard_kpis \
  -H "apikey: YOUR_API_KEY" \
  -H "Content-Type: application/json"

# Run ETL pipeline
psql $DATABASE_URL -c "SELECT * FROM scout.run_etl_pipeline();"
```

---

## 📝 Version History

| Version | Date | Changes |
|---------|------|---------|
| 3.0.0 | 2025-08-24 | Complete schema with ETL and APIs |
| 2.0.0 | 2025-07-15 | Added medallion architecture |
| 1.0.0 | 2025-06-01 | Initial schema design |

---

## 📞 Support

For questions or issues:
- Documentation: https://docs.scout-analytics.com
- API Reference: https://api.scout-analytics.com/docs
- Support: support@scout-analytics.com

---

*End of Scout v3 Complete Schema Documentation*
