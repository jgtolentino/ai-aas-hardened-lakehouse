-- Performance optimization: Add composite index for common query pattern
-- This index significantly improves choropleth and analytics queries

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_silver_region_category_date 
ON scout.silver_transactions(region, product_category, date_key);

-- Also add index for barangay-level queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_silver_barangay_category_date 
ON scout.silver_transactions(barangay, product_category, date_key);

-- Index for SKU performance analysis
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_silver_sku_date_store
ON scout.silver_transactions(sku_id, date_key, store_id);

-- Analyze tables to update statistics
ANALYZE scout.silver_transactions;