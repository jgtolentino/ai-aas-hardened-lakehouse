-- DW Star Schema DDL (Kimball methodology)
-- Idempotent: safe to run multiple times

CREATE SCHEMA IF NOT EXISTS dw;

-- =====================================================
-- DIMENSION TABLES
-- =====================================================

-- Date dimension
CREATE TABLE IF NOT EXISTS dw.dim_date (
    date_key INTEGER PRIMARY KEY,
    date_actual DATE NOT NULL UNIQUE,
    epoch BIGINT NOT NULL,
    day_suffix VARCHAR(4) NOT NULL,
    day_name VARCHAR(9) NOT NULL,
    day_of_week INTEGER NOT NULL,
    day_of_month INTEGER NOT NULL,
    day_of_quarter INTEGER NOT NULL,
    day_of_year INTEGER NOT NULL,
    week_of_month INTEGER NOT NULL,
    week_of_year INTEGER NOT NULL,
    week_of_year_iso CHAR(10) NOT NULL,
    month_actual INTEGER NOT NULL,
    month_name VARCHAR(9) NOT NULL,
    month_name_abbreviated CHAR(3) NOT NULL,
    quarter_actual INTEGER NOT NULL,
    quarter_name VARCHAR(9) NOT NULL,
    year_actual INTEGER NOT NULL,
    first_day_of_week DATE NOT NULL,
    last_day_of_week DATE NOT NULL,
    first_day_of_month DATE NOT NULL,
    last_day_of_month DATE NOT NULL,
    first_day_of_quarter DATE NOT NULL,
    last_day_of_quarter DATE NOT NULL,
    first_day_of_year DATE NOT NULL,
    last_day_of_year DATE NOT NULL,
    mmyyyy VARCHAR(6) NOT NULL,
    mmddyyyy VARCHAR(10) NOT NULL,
    weekend_indr BOOLEAN NOT NULL
);

-- Time dimension
CREATE TABLE IF NOT EXISTS dw.dim_time (
    time_key INTEGER PRIMARY KEY,
    time_value TIME NOT NULL UNIQUE,
    hour24 INTEGER NOT NULL,
    hour12 INTEGER NOT NULL,
    hour_bucket VARCHAR(15) NOT NULL,
    minute INTEGER NOT NULL,
    am_pm VARCHAR(2) NOT NULL,
    day_time_bucket VARCHAR(15) NOT NULL,
    day_time_name VARCHAR(20) NOT NULL
);

-- Store dimension
CREATE TABLE IF NOT EXISTS dw.dim_store (
    store_key SERIAL PRIMARY KEY,
    store_id VARCHAR(50) UNIQUE NOT NULL,
    store_name VARCHAR(100) NOT NULL,
    store_type VARCHAR(50),
    store_region VARCHAR(50),
    store_province VARCHAR(50),
    store_city VARCHAR(50),
    store_barangay VARCHAR(50),
    store_address VARCHAR(255),
    store_lat DECIMAL(10,7),
    store_lon DECIMAL(10,7),
    store_status VARCHAR(20) DEFAULT 'active',
    valid_from DATE DEFAULT CURRENT_DATE,
    valid_to DATE DEFAULT '9999-12-31',
    is_current BOOLEAN DEFAULT TRUE
);

-- Product dimension
CREATE TABLE IF NOT EXISTS dw.dim_product (
    product_key SERIAL PRIMARY KEY,
    product_id VARCHAR(50) UNIQUE NOT NULL,
    product_sku VARCHAR(100),
    product_name VARCHAR(255) NOT NULL,
    product_category VARCHAR(100),
    product_subcategory VARCHAR(100),
    product_brand VARCHAR(100),
    product_size VARCHAR(50),
    product_unit VARCHAR(20),
    product_barcode VARCHAR(50),
    product_status VARCHAR(20) DEFAULT 'active',
    valid_from DATE DEFAULT CURRENT_DATE,
    valid_to DATE DEFAULT '9999-12-31',
    is_current BOOLEAN DEFAULT TRUE
);

-- Customer dimension
CREATE TABLE IF NOT EXISTS dw.dim_customer (
    customer_key SERIAL PRIMARY KEY,
    customer_id VARCHAR(50) UNIQUE NOT NULL,
    customer_name VARCHAR(100),
    customer_type VARCHAR(50),
    customer_segment VARCHAR(50),
    customer_region VARCHAR(50),
    customer_province VARCHAR(50),
    customer_city VARCHAR(50),
    customer_status VARCHAR(20) DEFAULT 'active',
    valid_from DATE DEFAULT CURRENT_DATE,
    valid_to DATE DEFAULT '9999-12-31',
    is_current BOOLEAN DEFAULT TRUE
);

-- Payment method dimension
CREATE TABLE IF NOT EXISTS dw.dim_payment_method (
    payment_method_key SERIAL PRIMARY KEY,
    payment_method_code VARCHAR(20) UNIQUE NOT NULL,
    payment_method_name VARCHAR(50) NOT NULL,
    payment_category VARCHAR(50)
);

-- =====================================================
-- FACT TABLES
-- =====================================================

-- Transaction fact table
CREATE TABLE IF NOT EXISTS dw.fact_transactions (
    transaction_key BIGSERIAL PRIMARY KEY,
    date_key INTEGER NOT NULL REFERENCES dw.dim_date(date_key),
    time_key INTEGER REFERENCES dw.dim_time(time_key),
    store_key INTEGER NOT NULL REFERENCES dw.dim_store(store_key),
    customer_key INTEGER REFERENCES dw.dim_customer(customer_key),
    payment_method_key INTEGER REFERENCES dw.dim_payment_method(payment_method_key),
    transaction_id VARCHAR(100) NOT NULL,
    transaction_amount DECIMAL(12,2) NOT NULL,
    transaction_cost DECIMAL(12,2),
    transaction_margin DECIMAL(12,2),
    item_count INTEGER NOT NULL DEFAULT 0,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Transaction items fact table
CREATE TABLE IF NOT EXISTS dw.fact_transaction_items (
    transaction_item_key BIGSERIAL PRIMARY KEY,
    transaction_key BIGINT NOT NULL REFERENCES dw.fact_transactions(transaction_key),
    product_key INTEGER NOT NULL REFERENCES dw.dim_product(product_key),
    quantity DECIMAL(10,3) NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(12,2) NOT NULL,
    unit_cost DECIMAL(10,2),
    total_cost DECIMAL(12,2),
    margin DECIMAL(12,2),
    discount_amount DECIMAL(10,2) DEFAULT 0
);

-- Monthly performance fact table
CREATE TABLE IF NOT EXISTS dw.fact_monthly_performance (
    performance_key SERIAL PRIMARY KEY,
    date_key INTEGER NOT NULL REFERENCES dw.dim_date(date_key),
    store_key INTEGER NOT NULL REFERENCES dw.dim_store(store_key),
    revenue DECIMAL(15,2) NOT NULL,
    cost DECIMAL(15,2),
    margin DECIMAL(15,2),
    transaction_count INTEGER NOT NULL,
    unique_customers INTEGER,
    units_sold DECIMAL(12,3),
    UNIQUE(date_key, store_key)
);

-- =====================================================
-- BRIDGE TABLES
-- =====================================================

-- Product bundle bridge
CREATE TABLE IF NOT EXISTS dw.bridge_product_bundle (
    bundle_key SERIAL PRIMARY KEY,
    parent_product_key INTEGER NOT NULL REFERENCES dw.dim_product(product_key),
    child_product_key INTEGER NOT NULL REFERENCES dw.dim_product(product_key),
    quantity DECIMAL(10,3) NOT NULL DEFAULT 1,
    UNIQUE(parent_product_key, child_product_key)
);

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_fact_trans_date ON dw.fact_transactions(date_key);
CREATE INDEX IF NOT EXISTS idx_fact_trans_store ON dw.fact_transactions(store_key);
CREATE INDEX IF NOT EXISTS idx_fact_trans_id ON dw.fact_transactions(transaction_id);
CREATE INDEX IF NOT EXISTS idx_fact_items_trans ON dw.fact_transaction_items(transaction_key);
CREATE INDEX IF NOT EXISTS idx_fact_items_product ON dw.fact_transaction_items(product_key);

-- =====================================================
-- FUNCTIONS
-- =====================================================

-- Function to seed date dimension
CREATE OR REPLACE FUNCTION dw.seed_dim_date(start_date DATE, end_date DATE)
RETURNS void AS $$
DECLARE
    curr_date DATE;
BEGIN
    curr_date := start_date;
    
    WHILE curr_date <= end_date LOOP
        INSERT INTO dw.dim_date VALUES (
            TO_CHAR(curr_date,'YYYYMMDD')::INTEGER,
            curr_date,
            EXTRACT(EPOCH FROM curr_date),
            TO_CHAR(curr_date,'fmDDth'),
            TO_CHAR(curr_date,'Day'),
            EXTRACT(ISODOW FROM curr_date),
            EXTRACT(DAY FROM curr_date),
            TO_CHAR(curr_date,'Q')::INTEGER,
            EXTRACT(DOY FROM curr_date),
            TO_CHAR(curr_date,'W')::INTEGER,
            EXTRACT(WEEK FROM curr_date),
            TO_CHAR(curr_date,'IYYY-IW'),
            EXTRACT(MONTH FROM curr_date),
            TO_CHAR(curr_date,'Month'),
            TO_CHAR(curr_date,'Mon'),
            EXTRACT(QUARTER FROM curr_date),
            'Q' || TO_CHAR(curr_date,'Q'),
            EXTRACT(YEAR FROM curr_date),
            curr_date - (EXTRACT(ISODOW FROM curr_date) - 1)::INTEGER,
            curr_date + (7 - EXTRACT(ISODOW FROM curr_date))::INTEGER,
            DATE_TRUNC('month',curr_date)::DATE,
            (DATE_TRUNC('month',curr_date) + INTERVAL '1 month - 1 day')::DATE,
            DATE_TRUNC('quarter',curr_date)::DATE,
            (DATE_TRUNC('quarter',curr_date) + INTERVAL '3 months - 1 day')::DATE,
            DATE_TRUNC('year',curr_date)::DATE,
            (DATE_TRUNC('year',curr_date) + INTERVAL '1 year - 1 day')::DATE,
            TO_CHAR(curr_date,'MMYYYY'),
            TO_CHAR(curr_date,'MMDDYYYY'),
            EXTRACT(ISODOW FROM curr_date) IN (6,7)
        ) ON CONFLICT (date_actual) DO NOTHING;
        
        curr_date := curr_date + INTERVAL '1 day';
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to seed time dimension
CREATE OR REPLACE FUNCTION dw.seed_dim_time()
RETURNS void AS $$
DECLARE
    curr_time TIME;
    h INTEGER;
    m INTEGER;
BEGIN
    FOR h IN 0..23 LOOP
        FOR m IN 0..59 LOOP
            curr_time := (h::TEXT || ':' || m::TEXT)::TIME;
            INSERT INTO dw.dim_time VALUES (
                h * 100 + m,
                curr_time,
                h,
                CASE WHEN h = 0 THEN 12 WHEN h <= 12 THEN h ELSE h - 12 END,
                CASE 
                    WHEN h < 6 THEN 'Night (12-6)'
                    WHEN h < 12 THEN 'Morning (6-12)'
                    WHEN h < 18 THEN 'Afternoon (12-18)'
                    ELSE 'Evening (18-24)'
                END,
                m,
                CASE WHEN h < 12 THEN 'AM' ELSE 'PM' END,
                CASE 
                    WHEN h < 6 THEN 'Night'
                    WHEN h < 12 THEN 'Morning'
                    WHEN h < 17 THEN 'Afternoon'
                    WHEN h < 22 THEN 'Evening'
                    ELSE 'Night'
                END,
                CASE 
                    WHEN h >= 6 AND h < 9 THEN 'Early Morning'
                    WHEN h >= 9 AND h < 12 THEN 'Late Morning'
                    WHEN h >= 12 AND h < 15 THEN 'Early Afternoon'
                    WHEN h >= 15 AND h < 18 THEN 'Late Afternoon'
                    WHEN h >= 18 AND h < 21 THEN 'Early Evening'
                    WHEN h >= 21 OR h < 3 THEN 'Late Evening'
                    ELSE 'Early Morning'
                END
            ) ON CONFLICT (time_value) DO NOTHING;
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- GRANTS
-- =====================================================

GRANT USAGE ON SCHEMA dw TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA dw TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA dw TO PUBLIC;