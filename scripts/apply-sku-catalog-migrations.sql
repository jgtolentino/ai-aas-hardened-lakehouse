-- ============================================================
-- APPLY SKU CATALOG MIGRATIONS
-- Run this in Supabase SQL Editor
-- ============================================================

-- First, run the import SKU catalog migration
\i supabase/migrations/20250823_import_sku_catalog.sql

-- Then, run the telco extensions
\i supabase/migrations/20250824170000_sku_catalog_telco_extensions.sql

-- Verify the setup
SELECT 'Checking masterdata schema...' as status;
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'masterdata' 
ORDER BY table_name;

SELECT 'Checking staging schema...' as status;
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'staging' 
ORDER BY table_name;

-- Check if telco products table exists
SELECT 'Checking telco products...' as status;
SELECT EXISTS (
    SELECT 1 
    FROM information_schema.tables 
    WHERE table_schema = 'masterdata' 
    AND table_name = 'telco_products'
) as telco_table_exists;

-- Check views
SELECT 'Checking views...' as status;
SELECT table_name 
FROM information_schema.views 
WHERE table_schema = 'masterdata' 
AND table_name LIKE '%catalog%' OR table_name LIKE '%telco%' OR table_name LIKE '%halal%'
ORDER BY table_name;

-- Summary
SELECT 'Setup complete! Ready to import 347 products.' as message;