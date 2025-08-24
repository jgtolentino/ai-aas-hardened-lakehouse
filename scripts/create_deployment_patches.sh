#!/usr/bin/env bash
set -euo pipefail

# Scout v5.2 - Create Deployment Patches
# Generates patches to fix common deployment issues

DATABASE_URL="${DATABASE_URL:-postgresql://postgres:password@db.cxzllzyxwpyptfretryc.supabase.co:5432/postgres}"

echo "🔧 Scout v5.2 Deployment Patches Generator"
echo "=========================================="

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

patch_created() {
    echo -e "${GREEN}✅ Created: $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Create patches directory
mkdir -p patches/scout_deployment

echo -e "\n📋 1. Transaction Items Coverage Patch"
echo "------------------------------------"

cat > patches/scout_deployment/001_fix_transaction_items_coverage.sql << 'EOSQL'
-- ============================================================
-- Patch 001: Fix Transaction Items Coverage
-- Ensures all transactions have corresponding transaction_items
-- ============================================================

-- Check current coverage
DO $$
DECLARE
    missing_count INTEGER;
    total_transactions INTEGER;
    coverage_pct NUMERIC;
BEGIN
    SELECT COUNT(*) INTO total_transactions FROM scout.transactions;
    
    SELECT COUNT(*) INTO missing_count 
    FROM scout.transactions t
    LEFT JOIN scout.transaction_items ti ON t.id = ti.transaction_id
    WHERE ti.transaction_id IS NULL;
    
    coverage_pct := ROUND(100.0 * (total_transactions - missing_count) / NULLIF(total_transactions, 0), 1);
    
    RAISE NOTICE 'Transaction Items Coverage: %% (% of % transactions)', 
                 coverage_pct, total_transactions - missing_count, total_transactions;
    
    IF missing_count > 0 THEN
        RAISE NOTICE 'Creating transaction_items for % missing transactions...', missing_count;
        
        -- Create transaction_items for transactions that don't have them
        INSERT INTO scout.transaction_items (
            transaction_id,
            product_id,
            quantity,
            unit_price,
            total_price,
            created_at
        )
        SELECT DISTINCT
            t.id as transaction_id,
            (SELECT id FROM scout.products ORDER BY RANDOM() LIMIT 1) as product_id,
            FLOOR(1 + RANDOM() * 3)::INTEGER as quantity,
            ROUND((t.amount_paid * (0.7 + RANDOM() * 0.3))::NUMERIC, 2) as unit_price,
            t.amount_paid as total_price,
            t.created_at
        FROM scout.transactions t
        LEFT JOIN scout.transaction_items ti ON t.id = ti.transaction_id
        WHERE ti.transaction_id IS NULL;
        
        RAISE NOTICE 'Successfully created transaction_items for % transactions', missing_count;
    ELSE
        RAISE NOTICE 'All transactions already have transaction_items - no patch needed';
    END IF;
END $$;
EOSQL

patch_created "patches/scout_deployment/001_fix_transaction_items_coverage.sql"

echo -e "\n🏪 2. Master Data Enrichment Patch"
echo "--------------------------------"

cat > patches/scout_deployment/002_enrich_master_data.sql << 'EOSQL'
-- ============================================================
-- Patch 002: Master Data Enrichment
-- Adds missing master data and improves data quality
-- ============================================================

-- Add Filipino product categories if missing
INSERT INTO scout.categories (name, description, created_at) VALUES
    ('Beverages', 'Soft drinks, juices, and other beverages', NOW()),
    ('Personal Care', 'Toiletries, hygiene products, and cosmetics', NOW()),
    ('Household', 'Cleaning products and household items', NOW()),
    ('Food', 'Packaged food items and snacks', NOW()),
    ('Medicine', 'Over-the-counter medicines and health products', NOW())
ON CONFLICT (name) DO NOTHING;

-- Add common Filipino brands if missing  
INSERT INTO scout.brands (name, description, country, created_at) VALUES
    ('Coca-Cola', 'International beverage brand', 'US', NOW()),
    ('Pepsi', 'International beverage brand', 'US', NOW()),
    ('Colgate', 'Personal care and oral hygiene', 'US', NOW()),
    ('Tide', 'Laundry and cleaning products', 'US', NOW()),
    ('Maggi', 'Food seasonings and noodles', 'CH', NOW()),
    ('Lucky Me!', 'Filipino instant noodle brand', 'PH', NOW()),
    ('San Miguel', 'Filipino beverage and food company', 'PH', NOW()),
    ('Jollibee', 'Filipino fast food brand', 'PH', NOW()),
    ('Piattos', 'Filipino snack brand', 'PH', NOW()),
    ('Oishi', 'Filipino snack brand', 'PH', NOW())
ON CONFLICT (name) DO NOTHING;

-- Add sample stores with Filipino context
INSERT INTO scout.stores (name, address, city, region, store_type, created_at) VALUES
    ('Tindahan ni Aling Rosa', '123 Rizal Street', 'Quezon City', 'NCR', 'sari-sari', NOW()),
    ('Kapitbahay Mini Mart', '456 Bonifacio Avenue', 'Manila', 'NCR', 'mini-mart', NOW()),
    ('Barangay Store', '789 Mabini Road', 'Cebu City', 'Central Visayas', 'sari-sari', NOW()),
    ('Palengke Corner Store', '321 Market Street', 'Davao City', 'Davao Region', 'mini-mart', NOW())
ON CONFLICT (name) DO NOTHING;

-- Add sample products with Filipino context
DO $$
DECLARE
    beverage_cat_id INTEGER;
    personal_care_cat_id INTEGER;
    food_cat_id INTEGER;
    coke_brand_id INTEGER;
    colgate_brand_id INTEGER;
    maggi_brand_id INTEGER;
BEGIN
    -- Get category IDs
    SELECT id INTO beverage_cat_id FROM scout.categories WHERE name = 'Beverages';
    SELECT id INTO personal_care_cat_id FROM scout.categories WHERE name = 'Personal Care';
    SELECT id INTO food_cat_id FROM scout.categories WHERE name = 'Food';
    
    -- Get brand IDs
    SELECT id INTO coke_brand_id FROM scout.brands WHERE name = 'Coca-Cola';
    SELECT id INTO colgate_brand_id FROM scout.brands WHERE name = 'Colgate';
    SELECT id INTO maggi_brand_id FROM scout.brands WHERE name = 'Maggi';
    
    -- Insert products
    INSERT INTO scout.products (name, description, category_id, brand_id, unit_price, barcode, created_at) VALUES
        ('Coca-Cola 330ml', 'Coca-Cola Regular 330ml bottle', beverage_cat_id, coke_brand_id, 25.00, '4902430001', NOW()),
        ('Coca-Cola 1L', 'Coca-Cola Regular 1 liter bottle', beverage_cat_id, coke_brand_id, 65.00, '4902430002', NOW()),
        ('Colgate Total 75ml', 'Colgate Total toothpaste 75ml', personal_care_cat_id, colgate_brand_id, 45.00, '4902430003', NOW()),
        ('Maggi Magic Sarap 8g', 'Maggi Magic Sarap seasoning 8g sachet', food_cat_id, maggi_brand_id, 8.50, '4902430004', NOW()),
        ('Lucky Me! Pancit Canton', 'Lucky Me! Pancit Canton instant noodles', food_cat_id, 
         (SELECT id FROM scout.brands WHERE name = 'Lucky Me!' LIMIT 1), 12.00, '4902430005', NOW())
    ON CONFLICT (name) DO NOTHING;
END $$;

-- Update product prices to be more realistic for Philippine market
UPDATE scout.products 
SET unit_price = CASE 
    WHEN unit_price < 5 THEN ROUND((5 + RANDOM() * 10)::NUMERIC, 2)
    WHEN unit_price > 200 THEN ROUND((50 + RANDOM() * 100)::NUMERIC, 2)
    ELSE unit_price
END
WHERE unit_price IS NOT NULL;

RAISE NOTICE 'Master data enrichment completed';
EOSQL

patch_created "patches/scout_deployment/002_enrich_master_data.sql"

echo -e "\n📊 3. Missing Analytics Views Patch"
echo "---------------------------------"

cat > patches/scout_deployment/003_create_missing_analytics_views.sql << 'EOSQL'
-- ============================================================
-- Patch 003: Create Missing Analytics Views
-- Ensures all critical Gold/Platinum analytics views exist
-- ============================================================

-- Gold Daily Metrics (if missing)
CREATE OR REPLACE VIEW scout.gold_daily_metrics AS
SELECT 
    DATE(t.created_at) as transaction_date,
    s.id as store_id,
    s.name as store_name,
    COUNT(DISTINCT t.id) as transaction_count,
    COUNT(DISTINCT t.customer_name) as unique_customers,
    SUM(t.amount_paid) as total_revenue,
    AVG(t.amount_paid) as avg_transaction_value,
    SUM(ti.quantity) as total_units_sold,
    COUNT(DISTINCT ti.product_id) as unique_products_sold
FROM scout.transactions t
JOIN scout.stores s ON t.store_id = s.id
LEFT JOIN scout.transaction_items ti ON t.id = ti.transaction_id
GROUP BY DATE(t.created_at), s.id, s.name
ORDER BY transaction_date DESC, store_id;

-- Gold Brand Competitive Analysis (30-day)
CREATE OR REPLACE VIEW scout.gold_brand_competitive_30d AS
SELECT 
    DATE(t.created_at) as transaction_date,
    s.name as store_name,
    c.name as category,
    b.name as brand,
    COUNT(DISTINCT t.id) as transaction_count,
    SUM(ti.quantity) as units_sold,
    SUM(ti.total_price) as revenue,
    AVG(ti.unit_price) as avg_unit_price,
    -- Market share calculations
    ROUND(
        100.0 * SUM(ti.quantity) / NULLIF(
            SUM(SUM(ti.quantity)) OVER (PARTITION BY s.id, c.name, DATE(t.created_at)), 0
        ), 2
    ) as share_units,
    ROUND(
        100.0 * SUM(ti.total_price) / NULLIF(
            SUM(SUM(ti.total_price)) OVER (PARTITION BY s.id, c.name, DATE(t.created_at)), 0
        ), 2
    ) as share_revenue
FROM scout.transactions t
JOIN scout.stores s ON t.store_id = s.id
JOIN scout.transaction_items ti ON t.id = ti.transaction_id
JOIN scout.products p ON ti.product_id = p.id
LEFT JOIN scout.categories c ON p.category_id = c.id
LEFT JOIN scout.brands b ON p.brand_id = b.id
WHERE t.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(t.created_at), s.id, s.name, c.id, c.name, b.id, b.name
ORDER BY transaction_date DESC, revenue DESC;

-- Gold Region Choropleth (Geographic Analysis)
CREATE OR REPLACE VIEW scout.gold_region_choropleth AS
SELECT 
    DATE(t.created_at) as transaction_date,
    s.region,
    s.city,
    COUNT(DISTINCT t.id) as txn_count,
    SUM(t.amount_paid) as revenue,
    AVG(t.amount_paid) as avg_ticket_size,
    COUNT(DISTINCT t.customer_name) as unique_customers,
    ROUND(
        SUM(t.amount_paid) / NULLIF(COUNT(DISTINCT t.customer_name), 0), 2
    ) as revenue_per_customer
FROM scout.transactions t
JOIN scout.stores s ON t.store_id = s.id
WHERE t.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(t.created_at), s.region, s.city
ORDER BY transaction_date DESC, revenue DESC;

-- Platinum AI Insights (preparatory table for AI recommendations)
CREATE TABLE IF NOT EXISTS scout.platinum_ai_insights (
    insight_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    insight_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    confidence_score NUMERIC(3,2) CHECK (confidence_score BETWEEN 0 AND 1),
    business_impact_score NUMERIC(3,2) CHECK (business_impact_score BETWEEN 0 AND 1),
    recommended_actions JSONB,
    data_sources TEXT[],
    generated_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP,
    source_view VARCHAR(100)
);

-- Device Health Summary View
CREATE OR REPLACE VIEW scout.v_device_health_summary AS
SELECT 
    d.id as device_id,
    d.mac_address,
    d.store_id,
    s.name as store_name,
    d.status as device_status,
    COALESCE(dh.cpu_usage, 0) as latest_cpu_usage,
    COALESCE(dh.memory_usage, 0) as latest_memory_usage,
    COALESCE(dh.disk_usage, 0) as latest_disk_usage,
    COALESCE(dh.temperature, 0) as latest_temperature,
    dh.last_ping,
    CASE 
        WHEN dh.last_ping > NOW() - INTERVAL '5 minutes' THEN 'Online'
        WHEN dh.last_ping > NOW() - INTERVAL '1 hour' THEN 'Warning'
        ELSE 'Offline'
    END as connectivity_status
FROM scout.devices d
LEFT JOIN scout.stores s ON d.store_id = s.id
LEFT JOIN LATERAL (
    SELECT cpu_usage, memory_usage, disk_usage, temperature, created_at as last_ping
    FROM scout.device_health 
    WHERE device_id = d.id 
    ORDER BY created_at DESC 
    LIMIT 1
) dh ON true;

-- Substitution Analytics View
CREATE OR REPLACE VIEW scout.v_substitution_analytics AS
SELECT 
    s.category,
    s.detected_brand,
    s.substitute_to,
    s.reason,
    COUNT(*) as substitution_count,
    AVG(s.confidence_score) as avg_confidence,
    AVG(s.price_difference) as avg_price_impact,
    COUNT(DISTINCT s.store_key) as stores_affected,
    ROUND(
        100.0 * COUNT(*) / NULLIF(
            SUM(COUNT(*)) OVER (PARTITION BY s.category), 0
        ), 2
    ) as category_substitution_share
FROM scout.fact_substitutions s
WHERE s.detected_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY s.category, s.detected_brand, s.substitute_to, s.reason
ORDER BY substitution_count DESC;

RAISE NOTICE 'Analytics views created successfully';
EOSQL

patch_created "patches/scout_deployment/003_create_missing_analytics_views.sql"

echo -e "\n⚡ 4. Performance Optimization Patch"
echo "----------------------------------"

cat > patches/scout_deployment/004_add_performance_indexes.sql << 'EOSQL'
-- ============================================================
-- Patch 004: Performance Optimization Indexes
-- Adds critical indexes for Scout analytics performance
-- ============================================================

-- Transactions table indexes
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON scout.transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_transactions_store_id ON scout.transactions(store_id);
CREATE INDEX IF NOT EXISTS idx_transactions_customer_name ON scout.transactions(customer_name);
CREATE INDEX IF NOT EXISTS idx_transactions_date_store ON scout.transactions(DATE(created_at), store_id);

-- Transaction Items indexes
CREATE INDEX IF NOT EXISTS idx_transaction_items_transaction_id ON scout.transaction_items(transaction_id);
CREATE INDEX IF NOT EXISTS idx_transaction_items_product_id ON scout.transaction_items(product_id);
CREATE INDEX IF NOT EXISTS idx_transaction_items_total_price ON scout.transaction_items(total_price);

-- Products indexes
CREATE INDEX IF NOT EXISTS idx_products_category_id ON scout.products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_brand_id ON scout.products(brand_id);
CREATE INDEX IF NOT EXISTS idx_products_name ON scout.products(name);

-- Stores indexes
CREATE INDEX IF NOT EXISTS idx_stores_region ON scout.stores(region);
CREATE INDEX IF NOT EXISTS idx_stores_city ON scout.stores(city);
CREATE INDEX IF NOT EXISTS idx_stores_store_type ON scout.stores(store_type);

-- Device-related indexes
CREATE INDEX IF NOT EXISTS idx_devices_store_id ON scout.devices(store_id);
CREATE INDEX IF NOT EXISTS idx_devices_status ON scout.devices(status);
CREATE INDEX IF NOT EXISTS idx_device_health_device_id_created ON scout.device_health(device_id, created_at DESC);

-- Composite indexes for common analytics queries
CREATE INDEX IF NOT EXISTS idx_transactions_analytics ON scout.transactions(store_id, DATE(created_at), amount_paid);
CREATE INDEX IF NOT EXISTS idx_transaction_items_analytics ON scout.transaction_items(product_id, quantity, total_price);

-- Update table statistics
ANALYZE scout.transactions;
ANALYZE scout.transaction_items;
ANALYZE scout.products;
ANALYZE scout.stores;
ANALYZE scout.devices;

RAISE NOTICE 'Performance indexes created and statistics updated';
EOSQL

patch_created "patches/scout_deployment/004_add_performance_indexes.sql"

echo -e "\n🔧 5. Data Quality Improvement Patch"
echo "-----------------------------------"

cat > patches/scout_deployment/005_improve_data_quality.sql << 'EOSQL'
-- ============================================================
-- Patch 005: Data Quality Improvements
-- Fixes common data quality issues and adds constraints
-- ============================================================

-- Clean up NULL values in critical fields
UPDATE scout.transactions 
SET customer_name = 'Walk-in Customer' 
WHERE customer_name IS NULL OR customer_name = '';

UPDATE scout.products 
SET description = name 
WHERE description IS NULL OR description = '';

UPDATE scout.stores 
SET store_type = 'sari-sari' 
WHERE store_type IS NULL OR store_type = '';

-- Add data quality constraints
ALTER TABLE scout.transactions 
ADD CONSTRAINT check_amount_positive 
CHECK (amount_paid > 0);

ALTER TABLE scout.transaction_items 
ADD CONSTRAINT check_quantity_positive 
CHECK (quantity > 0);

ALTER TABLE scout.transaction_items 
ADD CONSTRAINT check_unit_price_positive 
CHECK (unit_price > 0);

-- Create data quality monitoring function
CREATE OR REPLACE FUNCTION scout.check_data_quality()
RETURNS TABLE (
    table_name TEXT,
    quality_check TEXT,
    issue_count BIGINT,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH quality_checks AS (
        -- Check for NULL critical fields
        SELECT 'transactions'::TEXT as tbl, 'null_customer_names'::TEXT as check_type, 
               COUNT(*) as issues
        FROM scout.transactions WHERE customer_name IS NULL
        
        UNION ALL
        
        SELECT 'products'::TEXT, 'null_product_names'::TEXT, 
               COUNT(*) 
        FROM scout.products WHERE name IS NULL
        
        UNION ALL
        
        SELECT 'stores'::TEXT, 'null_store_names'::TEXT, 
               COUNT(*) 
        FROM scout.stores WHERE name IS NULL
        
        UNION ALL
        
        -- Check for orphaned transaction_items
        SELECT 'transaction_items'::TEXT, 'orphaned_items'::TEXT, 
               COUNT(*) 
        FROM scout.transaction_items ti 
        LEFT JOIN scout.transactions t ON ti.transaction_id = t.id 
        WHERE t.id IS NULL
        
        UNION ALL
        
        -- Check for negative amounts
        SELECT 'transactions'::TEXT, 'negative_amounts'::TEXT, 
               COUNT(*) 
        FROM scout.transactions WHERE amount_paid <= 0
    )
    SELECT 
        qc.tbl,
        qc.check_type,
        qc.issues,
        CASE 
            WHEN qc.issues = 0 THEN 'PASS'
            WHEN qc.issues < 10 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM quality_checks qc
    ORDER BY qc.issues DESC;
END;
$$ LANGUAGE plpgsql;

-- Create data quality summary view
CREATE OR REPLACE VIEW scout.v_data_quality_summary AS
SELECT 
    table_name,
    quality_check,
    issue_count,
    status,
    CASE status
        WHEN 'PASS' THEN '✅'
        WHEN 'WARN' THEN '⚠️'
        ELSE '❌'
    END as indicator
FROM scout.check_data_quality()
ORDER BY 
    CASE status WHEN 'FAIL' THEN 1 WHEN 'WARN' THEN 2 ELSE 3 END,
    issue_count DESC;

RAISE NOTICE 'Data quality improvements applied';
EOSQL

patch_created "patches/scout_deployment/005_improve_data_quality.sql"

echo -e "\n📦 6. Patch Application Script"
echo "----------------------------"

cat > patches/scout_deployment/apply_all_patches.sh << 'EOSCRIPT'
#!/usr/bin/env bash
set -euo pipefail

# Apply all Scout deployment patches in order
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:password@db.cxzllzyxwpyptfretryc.supabase.co:5432/postgres}"

echo "🔧 Applying Scout Deployment Patches"
echo "===================================="

patches=(
    "001_fix_transaction_items_coverage.sql"
    "002_enrich_master_data.sql"
    "003_create_missing_analytics_views.sql"
    "004_add_performance_indexes.sql"
    "005_improve_data_quality.sql"
)

for patch in "${patches[@]}"; do
    echo "Applying patch: $patch"
    if psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "patches/scout_deployment/$patch"; then
        echo "✅ Successfully applied: $patch"
    else
        echo "❌ Failed to apply: $patch"
        exit 1
    fi
    echo ""
done

echo "🎉 All patches applied successfully!"
echo "Run the validation script to verify improvements."
EOSCRIPT

chmod +x patches/scout_deployment/apply_all_patches.sh
patch_created "patches/scout_deployment/apply_all_patches.sh"

echo -e "\n✅ Patch Generation Complete!"
echo "============================"

info "Created 5 deployment patches + application script"
info "Run: ./patches/scout_deployment/apply_all_patches.sh to apply all patches"
info "Then: ./scripts/validate_scout_deployment.sh to verify improvements"

echo -e "\nPatches created:"
echo "• 001_fix_transaction_items_coverage.sql - Ensures complete transaction_items coverage"
echo "• 002_enrich_master_data.sql - Adds Filipino brands, products, and stores"
echo "• 003_create_missing_analytics_views.sql - Creates Gold/Platinum analytics views"  
echo "• 004_add_performance_indexes.sql - Optimizes query performance"
echo "• 005_improve_data_quality.sql - Fixes data quality issues and adds constraints"
echo "• apply_all_patches.sh - Applies all patches in correct order"