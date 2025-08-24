-- ============================================================
-- SCOUT ANALYTICS v5.2 ALIGNMENT PATCH
-- Adds missing components from PRD while preserving existing deployment
-- ============================================================

SET search_path TO scout, public;

-- ============================================================
-- FACT TABLES (Add if missing)
-- ============================================================

-- Core transaction fact table
CREATE TABLE IF NOT EXISTS scout.fact_transactions (
    transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL,
    customer_id UUID,
    transaction_date DATE NOT NULL,
    transaction_time TIME NOT NULL,
    date_key INTEGER,
    time_key INTEGER,
    transaction_type TEXT,
    payment_method TEXT,
    subtotal_amount DECIMAL(10,2),
    discount_amount DECIMAL(10,2),
    tax_amount DECIMAL(10,2),
    total_amount DECIMAL(10,2) NOT NULL,
    item_count INTEGER DEFAULT 0,
    basket_size_tier TEXT,
    is_repeat_customer BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Transaction items fact table
CREATE TABLE IF NOT EXISTS scout.fact_transaction_items (
    item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL,
    product_id UUID NOT NULL,
    store_id UUID NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    total_amount DECIMAL(10,2) NOT NULL,
    promotion_id UUID,
    detected_brand TEXT,
    confidence_score DECIMAL(3,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Daily sales fact for fast aggregation
CREATE TABLE IF NOT EXISTS scout.fact_daily_sales (
    date_key INTEGER NOT NULL,
    store_id UUID NOT NULL,
    product_id UUID,
    brand_id UUID,
    category_id UUID,
    total_quantity INTEGER DEFAULT 0,
    total_sales DECIMAL(12,2) DEFAULT 0,
    unique_customers INTEGER DEFAULT 0,
    transaction_count INTEGER DEFAULT 0,
    avg_basket_size DECIMAL(10,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (date_key, store_id, product_id)
);

-- ============================================================
-- DIMENSION TABLES (Add missing dimensions)
-- ============================================================

-- Date dimension for time-based analysis
CREATE TABLE IF NOT EXISTS scout.dim_date (
    date_key INTEGER PRIMARY KEY,
    date DATE NOT NULL UNIQUE,
    year INTEGER NOT NULL,
    quarter INTEGER NOT NULL,
    month INTEGER NOT NULL,
    month_name TEXT NOT NULL,
    week_of_year INTEGER NOT NULL,
    day_of_month INTEGER NOT NULL,
    day_of_week INTEGER NOT NULL,
    day_name TEXT NOT NULL,
    is_weekend BOOLEAN NOT NULL,
    is_holiday BOOLEAN DEFAULT false,
    holiday_name TEXT,
    fiscal_year INTEGER,
    fiscal_quarter INTEGER
);

-- Time dimension for intraday analysis
CREATE TABLE IF NOT EXISTS scout.dim_time (
    time_key INTEGER PRIMARY KEY,
    time TIME NOT NULL UNIQUE,
    hour INTEGER NOT NULL,
    minute INTEGER NOT NULL,
    hour_24 TEXT NOT NULL,
    hour_12 TEXT NOT NULL,
    am_pm TEXT NOT NULL,
    time_period TEXT NOT NULL, -- morning, afternoon, evening, night
    is_business_hours BOOLEAN DEFAULT true,
    is_peak_hours BOOLEAN DEFAULT false
);

-- ============================================================
-- MASTER TABLES (Add if missing, using ref_ prefix in existing system)
-- ============================================================

-- Map master tables to existing ref tables via views
CREATE OR REPLACE VIEW scout.master_brands AS
SELECT 
    brand_id,
    brand_name,
    manufacturer,
    country_of_origin,
    is_local,
    created_at,
    updated_at
FROM scout.ref_brands;

CREATE OR REPLACE VIEW scout.master_categories AS
SELECT 
    category_id,
    category_name,
    parent_category_id,
    category_level,
    is_active,
    display_order,
    created_at,
    updated_at
FROM scout.ref_categories;

CREATE OR REPLACE VIEW scout.master_products AS
SELECT 
    p.product_id,
    p.sku,
    p.product_name,
    p.brand_id,
    p.category_id,
    p.subcategory,
    p.unit_size,
    p.unit_of_measure,
    p.barcode,
    p.is_active,
    p.created_at,
    p.updated_at
FROM scout.dim_sku p;

-- ============================================================
-- BRONZE LAYER TABLES (Ensure consistency)
-- ============================================================

-- Add missing bronze tables if they don't exist
CREATE TABLE IF NOT EXISTS scout.bronze_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL,
    event_timestamp TIMESTAMPTZ NOT NULL,
    device_id TEXT,
    store_id TEXT,
    event_data JSONB NOT NULL,
    processing_status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS scout.bronze_inventory (
    inventory_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id TEXT,
    product_id TEXT,
    quantity INTEGER,
    last_updated TIMESTAMPTZ,
    raw_data JSONB,
    processing_status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SILVER LAYER ENHANCEMENT
-- ============================================================

-- Add missing silver tables
CREATE TABLE IF NOT EXISTS scout.silver_inventory (
    inventory_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL,
    product_id UUID NOT NULL,
    quantity_on_hand INTEGER NOT NULL,
    quantity_reserved INTEGER DEFAULT 0,
    quantity_available INTEGER GENERATED ALWAYS AS (quantity_on_hand - quantity_reserved) STORED,
    reorder_point INTEGER,
    reorder_quantity INTEGER,
    last_count_date TIMESTAMPTZ,
    last_sale_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- GOLD LAYER VIEWS (Add missing analytics views)
-- ============================================================

-- Dashboard KPIs view
CREATE OR REPLACE VIEW scout.v_dashboard_kpis AS
WITH daily_metrics AS (
    SELECT 
        date_key,
        SUM(total_sales) as daily_revenue,
        SUM(transaction_count) as daily_transactions,
        SUM(unique_customers) as daily_customers,
        AVG(avg_basket_size) as avg_basket_size
    FROM scout.fact_daily_sales
    GROUP BY date_key
)
SELECT 
    COUNT(DISTINCT date_key) as days_analyzed,
    SUM(daily_revenue) as total_revenue,
    SUM(daily_transactions) as total_transactions,
    SUM(daily_customers) as total_customers,
    AVG(avg_basket_size) as overall_avg_basket,
    MAX(daily_revenue) as peak_daily_revenue,
    MIN(daily_revenue) as min_daily_revenue
FROM daily_metrics;

-- Brand performance view
CREATE OR REPLACE VIEW scout.v_brand_performance AS
SELECT 
    b.brand_name,
    b.manufacturer,
    COUNT(DISTINCT f.store_id) as store_coverage,
    COUNT(DISTINCT f.date_key) as active_days,
    SUM(f.total_quantity) as units_sold,
    SUM(f.total_sales) as revenue,
    AVG(f.total_sales / NULLIF(f.total_quantity, 0)) as avg_unit_price,
    SUM(f.total_sales) / NULLIF(SUM(SUM(f.total_sales)) OVER (), 0) * 100 as market_share_pct
FROM scout.fact_daily_sales f
JOIN scout.ref_brands b ON f.brand_id = b.brand_id
GROUP BY b.brand_id, b.brand_name, b.manufacturer;

-- ============================================================
-- PLATINUM LAYER (Predictive Analytics)
-- ============================================================

-- Substitution patterns table
CREATE TABLE IF NOT EXISTS scout.platinum_substitution_patterns (
    pattern_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    original_product_id UUID NOT NULL,
    substitute_product_id UUID NOT NULL,
    substitution_rate DECIMAL(5,2),
    confidence_score DECIMAL(3,2),
    sample_size INTEGER,
    conditions JSONB, -- price_delta, stock_out, promotion
    valid_from DATE,
    valid_to DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Demand forecasting table
CREATE TABLE IF NOT EXISTS scout.platinum_demand_forecast (
    forecast_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    store_id UUID,
    forecast_date DATE NOT NULL,
    forecast_quantity INTEGER,
    forecast_revenue DECIMAL(10,2),
    confidence_interval_lower INTEGER,
    confidence_interval_upper INTEGER,
    model_type TEXT, -- arima, prophet, neural
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- EDGE DEVICE TABLES (Ensure compatibility)
-- ============================================================

-- Add missing edge columns if needed
DO $$
BEGIN
    -- Add stt_model_version if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'scout' 
        AND table_name = 'edge_health' 
        AND column_name = 'stt_accuracy'
    ) THEN
        ALTER TABLE scout.edge_health 
        ADD COLUMN stt_accuracy DECIMAL(3,2),
        ADD COLUMN stt_latency_ms INTEGER;
    END IF;
END $$;

-- ============================================================
-- STT (Speech-to-Text) TABLES
-- ============================================================

-- STT brand dictionary
CREATE TABLE IF NOT EXISTS scout.stt_brand_dictionary (
    brand_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_name TEXT NOT NULL,
    brand_variants TEXT[], -- different pronunciations
    phonetic_patterns TEXT[],
    language TEXT DEFAULT 'fil',
    confidence_threshold DECIMAL(3,2) DEFAULT 0.80,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- STT detection log
CREATE TABLE IF NOT EXISTS scout.stt_detections (
    detection_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL,
    store_id UUID NOT NULL,
    detected_text TEXT NOT NULL,
    detected_brands TEXT[],
    confidence_scores DECIMAL(3,2)[],
    detection_timestamp TIMESTAMPTZ NOT NULL,
    processing_duration_ms INTEGER,
    model_version TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ETL CONTROL TABLES
-- ============================================================

-- ETL pipeline status
CREATE TABLE IF NOT EXISTS scout.etl_pipeline_status (
    pipeline_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pipeline_name TEXT NOT NULL,
    pipeline_stage TEXT NOT NULL, -- bronze, silver, gold, platinum
    status TEXT NOT NULL, -- running, completed, failed
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    records_processed INTEGER DEFAULT 0,
    records_failed INTEGER DEFAULT 0,
    error_message TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- COMPATIBILITY VIEWS (Handle naming differences)
-- ============================================================

-- Create plural views for existing singular dimension tables
CREATE OR REPLACE VIEW scout.dim_stores AS SELECT * FROM scout.dim_store;
CREATE OR REPLACE VIEW scout.dim_products AS SELECT * FROM scout.dim_sku;
CREATE OR REPLACE VIEW scout.dim_customers AS SELECT * FROM scout.dim_customer;

-- Create singular views for systems expecting singular names
CREATE OR REPLACE VIEW scout.dim_product AS SELECT * FROM scout.dim_sku;

-- ============================================================
-- RPC FUNCTIONS (Core API endpoints)
-- ============================================================

-- Get dashboard KPIs
CREATE OR REPLACE FUNCTION scout.get_dashboard_kpis(
    p_date_from DATE DEFAULT CURRENT_DATE - 30,
    p_date_to DATE DEFAULT CURRENT_DATE,
    p_store_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT json_build_object(
        'period', json_build_object(
            'from', p_date_from,
            'to', p_date_to
        ),
        'revenue', json_build_object(
            'total', COALESCE(SUM(total_sales), 0),
            'daily_average', COALESCE(AVG(total_sales), 0),
            'growth_rate', COALESCE(
                (SUM(total_sales) - LAG(SUM(total_sales)) OVER ()) / 
                NULLIF(LAG(SUM(total_sales)) OVER (), 0) * 100, 0
            )
        ),
        'transactions', json_build_object(
            'total', COALESCE(SUM(transaction_count), 0),
            'daily_average', COALESCE(AVG(transaction_count), 0)
        ),
        'customers', json_build_object(
            'unique_count', COALESCE(SUM(unique_customers), 0),
            'daily_average', COALESCE(AVG(unique_customers), 0)
        ),
        'basket', json_build_object(
            'average_size', COALESCE(AVG(avg_basket_size), 0),
            'average_value', COALESCE(SUM(total_sales) / NULLIF(SUM(transaction_count), 0), 0)
        ),
        'top_brand', (
            SELECT json_build_object(
                'brand_name', b.brand_name,
                'revenue', SUM(f.total_sales),
                'units_sold', SUM(f.total_quantity)
            )
            FROM scout.fact_daily_sales f
            JOIN scout.ref_brands b ON f.brand_id = b.brand_id
            WHERE f.date_key BETWEEN 
                EXTRACT(YEAR FROM p_date_from) * 10000 + EXTRACT(MONTH FROM p_date_from) * 100 + EXTRACT(DAY FROM p_date_from)
                AND EXTRACT(YEAR FROM p_date_to) * 10000 + EXTRACT(MONTH FROM p_date_to) * 100 + EXTRACT(DAY FROM p_date_to)
            AND (p_store_id IS NULL OR f.store_id = p_store_id)
            GROUP BY b.brand_id, b.brand_name
            ORDER BY SUM(f.total_sales) DESC
            LIMIT 1
        )
    ) INTO v_result
    FROM scout.fact_daily_sales
    WHERE date_key BETWEEN 
        EXTRACT(YEAR FROM p_date_from) * 10000 + EXTRACT(MONTH FROM p_date_from) * 100 + EXTRACT(DAY FROM p_date_from)
        AND EXTRACT(YEAR FROM p_date_to) * 10000 + EXTRACT(MONTH FROM p_date_to) * 100 + EXTRACT(DAY FROM p_date_to)
    AND (p_store_id IS NULL OR store_id = p_store_id);
    
    RETURN v_result;
END;
$$;

-- Get sales trend
CREATE OR REPLACE FUNCTION scout.get_sales_trend(
    p_days INTEGER DEFAULT 30,
    p_granularity TEXT DEFAULT 'daily',
    p_store_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    WITH trend_data AS (
        SELECT 
            CASE 
                WHEN p_granularity = 'hourly' THEN to_char(transaction_date, 'YYYY-MM-DD HH24:00')
                WHEN p_granularity = 'daily' THEN to_char(transaction_date, 'YYYY-MM-DD')
                WHEN p_granularity = 'weekly' THEN to_char(date_trunc('week', transaction_date), 'YYYY-MM-DD')
                WHEN p_granularity = 'monthly' THEN to_char(date_trunc('month', transaction_date), 'YYYY-MM')
            END as period,
            SUM(total_amount) as revenue,
            COUNT(*) as transactions,
            COUNT(DISTINCT customer_id) as unique_customers,
            AVG(total_amount) as avg_transaction_value
        FROM scout.fact_transactions
        WHERE transaction_date >= CURRENT_DATE - p_days
        AND (p_store_id IS NULL OR store_id = p_store_id)
        GROUP BY 1
        ORDER BY 1
    )
    SELECT json_build_object(
        'granularity', p_granularity,
        'periods', json_agg(period),
        'revenue', json_agg(revenue),
        'transactions', json_agg(transactions),
        'customers', json_agg(unique_customers),
        'avg_transaction_value', json_agg(avg_transaction_value),
        'summary', json_build_object(
            'total_revenue', SUM(revenue),
            'total_transactions', SUM(transactions),
            'period_count', COUNT(*)
        )
    ) INTO v_result
    FROM trend_data;
    
    RETURN v_result;
END;
$$;

-- ============================================================
-- POPULATE DIMENSION TABLES
-- ============================================================

-- Populate date dimension (if empty)
INSERT INTO scout.dim_date (
    date_key, date, year, quarter, month, month_name,
    week_of_year, day_of_month, day_of_week, day_name,
    is_weekend, fiscal_year, fiscal_quarter
)
SELECT 
    TO_CHAR(d, 'YYYYMMDD')::INTEGER as date_key,
    d as date,
    EXTRACT(YEAR FROM d)::INTEGER as year,
    EXTRACT(QUARTER FROM d)::INTEGER as quarter,
    EXTRACT(MONTH FROM d)::INTEGER as month,
    TO_CHAR(d, 'Month') as month_name,
    EXTRACT(WEEK FROM d)::INTEGER as week_of_year,
    EXTRACT(DAY FROM d)::INTEGER as day_of_month,
    EXTRACT(DOW FROM d)::INTEGER as day_of_week,
    TO_CHAR(d, 'Day') as day_name,
    EXTRACT(DOW FROM d) IN (0, 6) as is_weekend,
    EXTRACT(YEAR FROM d)::INTEGER as fiscal_year,
    EXTRACT(QUARTER FROM d)::INTEGER as fiscal_quarter
FROM generate_series(
    '2020-01-01'::DATE,
    '2030-12-31'::DATE,
    '1 day'::INTERVAL
) d
ON CONFLICT (date_key) DO NOTHING;

-- Populate time dimension (if empty)
INSERT INTO scout.dim_time (
    time_key, time, hour, minute, hour_24, hour_12, am_pm, time_period
)
SELECT 
    (EXTRACT(HOUR FROM t) * 100 + EXTRACT(MINUTE FROM t))::INTEGER as time_key,
    t::TIME as time,
    EXTRACT(HOUR FROM t)::INTEGER as hour,
    EXTRACT(MINUTE FROM t)::INTEGER as minute,
    TO_CHAR(t, 'HH24:MI') as hour_24,
    TO_CHAR(t, 'HH12:MI AM') as hour_12,
    TO_CHAR(t, 'AM') as am_pm,
    CASE 
        WHEN EXTRACT(HOUR FROM t) BETWEEN 6 AND 11 THEN 'morning'
        WHEN EXTRACT(HOUR FROM t) BETWEEN 12 AND 17 THEN 'afternoon'
        WHEN EXTRACT(HOUR FROM t) BETWEEN 18 AND 21 THEN 'evening'
        ELSE 'night'
    END as time_period
FROM generate_series(
    '00:00:00'::TIME,
    '23:59:00'::TIME,
    '1 minute'::INTERVAL
) t
ON CONFLICT (time_key) DO NOTHING;

-- ============================================================
-- MIGRATION HELPERS
-- ============================================================

-- Function to migrate data from existing tables to fact tables
CREATE OR REPLACE FUNCTION scout.migrate_to_fact_tables()
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    -- Migrate from silver_transactions to fact_transactions if needed
    INSERT INTO scout.fact_transactions (
        transaction_id,
        store_id,
        customer_id,
        transaction_date,
        transaction_time,
        date_key,
        time_key,
        total_amount,
        created_at
    )
    SELECT 
        gen_random_uuid(),
        store_id,
        customer_id,
        date(transaction_timestamp),
        time(transaction_timestamp),
        TO_CHAR(transaction_timestamp, 'YYYYMMDD')::INTEGER,
        (EXTRACT(HOUR FROM transaction_timestamp) * 100 + EXTRACT(MINUTE FROM transaction_timestamp))::INTEGER,
        total_amount,
        created_at
    FROM scout.silver_transactions
    WHERE NOT EXISTS (
        SELECT 1 FROM scout.fact_transactions ft 
        WHERE ft.created_at = silver_transactions.created_at
    );
    
    RAISE NOTICE 'Migration completed. Fact tables populated.';
END;
$$;

-- ============================================================
-- GRANTS
-- ============================================================

-- Grant permissions on new objects
GRANT SELECT ON ALL TABLES IN SCHEMA scout TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA scout TO authenticated;

-- ============================================================
-- COMPLETION
-- ============================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎯 SCOUT v5.2 ALIGNMENT PATCH COMPLETE!';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Added/Verified:';
    RAISE NOTICE '   • Fact tables (transactions, items, daily sales)';
    RAISE NOTICE '   • Date and time dimensions';
    RAISE NOTICE '   • Master table views (mapping to ref_ tables)';
    RAISE NOTICE '   • Bronze/Silver enhancement tables';
    RAISE NOTICE '   • Gold layer analytics views';
    RAISE NOTICE '   • Platinum predictive tables';
    RAISE NOTICE '   • STT detection tables';
    RAISE NOTICE '   • ETL pipeline status tracking';
    RAISE NOTICE '   • Core RPC functions (get_dashboard_kpis, get_sales_trend)';
    RAISE NOTICE '   • Compatibility views for naming differences';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Next Steps:';
    RAISE NOTICE '   1. Run scout.migrate_to_fact_tables() if needed';
    RAISE NOTICE '   2. Test RPC functions with your API';
    RAISE NOTICE '   3. Verify dashboard connectivity';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Scout Analytics v5.2 is now PRD-aligned!';
    RAISE NOTICE '';
END $$;