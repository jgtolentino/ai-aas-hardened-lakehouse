# Scout Analytics Data Tools

This directory contains tools for generating and loading synthetic data for the Scout Analytics platform, including TBWA client master data with realistic Philippine market coverage.

## Overview

The tools generate:
- **All 17 Philippine regions** with realistic city/barangay coverage
- **1,299 sari-sari stores** distributed across regions
- **18,000 transactions** over 365 days
- **TBWA client brands** with target market share:
  - FMCG: ~20% for TBWA clients (Alaska, Oishi, Marca Leon, Del Monte)
  - Tobacco: ~39% for JTI
- **Complete master data** including competitors (Bear Brand, Nido, PMFTC, etc.)
- **RLS-ready schema** with brand ownership mapping

## Tools

### 1. `generate_scout_csvs.py`
Generates CSV files with complete Scout Analytics data:
- `categories.csv` - Product categories
- `brands.csv` - TBWA clients + competitors
- `master_data_brand_sku.csv` - Full SKU catalog with variants
- `sku_variants.csv` - Variant tags for filtering
- `geography.csv` - Regions, cities, barangays
- `stores.csv` - Sari-sari store locations
- `transactions.csv` - 18K transactions
- `transaction_items.csv` - Line item details
- `brand_ownership.csv` - RLS tenant mapping
- `scout_rls_and_schema.sql` - Complete schema with RLS

### 2. `seed_scout_data.py`
Direct database seeder that:
- Connects directly to Supabase/PostgreSQL
- Generates Bronze → Silver → Gold → Platinum layers
- Includes event deduplication (idempotent ingestion)
- Refreshes materialized views automatically

### 3. `load_scout_data.sh`
Comprehensive loader script with options:
```bash
# Generate CSV files only
./load_scout_data.sh --generate

# Load to Supabase
./load_scout_data.sh --load --db-url 'postgresql://...'

# Generate and load in one step
./load_scout_data.sh --csv

# Use Python synthetic data generator
./load_scout_data.sh --synthetic
```

## Quick Start

### Option 1: CSV Generation and Loading
```bash
# Generate CSVs
python3 generate_scout_csvs.py

# Load to Supabase
export DATABASE_URL="postgresql://postgres:password@db.project.supabase.co:5432/postgres"
./load_scout_data.sh --csv
```

### Option 2: Direct Database Seeding
```bash
# Set connection
export SUPABASE_DB_URI="postgresql://postgres:password@db.project.supabase.co:5432/postgres"

# Run seeder
python3 seed_scout_data.py
```

### Option 3: Manual CSV Upload (Supabase Dashboard)
1. Generate CSVs: `python3 generate_scout_csvs.py`
2. Run schema: Upload `scout_seed_data/scout_rls_and_schema.sql` to SQL Editor
3. Upload CSVs via Table Editor in this order:
   - categories.csv
   - brands.csv
   - master_data_brand_sku.csv
   - sku_variants.csv
   - stores.csv
   - transactions.csv
   - transaction_items.csv
   - brand_ownership.csv

## TBWA Client Brands

### Dairy & Beverages - Alaska
- Alaska Evaporada (370ml, 180ml pouch)
- Alaska Condensada (300ml)
- Alaska Fresh Milk (1L)
- Alaska Powdered Milk (300g, 700g)
- Alaska UHT Chocolate (1L)

### Snacks - Oishi
- Oishi Prawn Crackers (Regular, Spicy)
- Oishi Pillows (Chocolate, Ube)
- Oishi Rinbee Cheese Sticks
- Oishi Smart C Drink

### Oils - Marca Leon / Star Margarine
- Marca Leon Coconut Oil (1L)
- Marca Leon Palm Oil (1L, 2L)
- Star Margarine (Classic, Sweet, Garlic)

### Canned Goods - Del Monte
- Del Monte Pineapple Juice
- Del Monte Spaghetti Sauce (Sweet, Italian)
- Del Monte Ketchup (Banana, Tomato)
- Del Monte Fruit Cocktail

### Tobacco - JTI
- Winston (Red, Blue, White)
- Mevius (Original Blue, Sky Blue, Option Purple)
- Camel (Yellow, Blue, Activate Purple)
- LD (Red, Blue)

## Market Share Verification

After loading, verify market shares:
```sql
-- Check TBWA FMCG share (should be ~20%)
WITH fmcg_sales AS (
  SELECT 
    b.is_tbwa_client,
    SUM(ti.line_total) as total
  FROM scout.transaction_items ti
  JOIN scout.brands b ON b.brand_id = ti.brand_id
  WHERE b.category_id IN (1,2,3,4)
  GROUP BY b.is_tbwa_client
)
SELECT 
  is_tbwa_client,
  total,
  100.0 * total / SUM(total) OVER () as market_share_pct
FROM fmcg_sales;

-- Check JTI tobacco share (should be ~39%)
WITH tobacco_sales AS (
  SELECT 
    b.brand_name,
    SUM(ti.line_total) as total
  FROM scout.transaction_items ti
  JOIN scout.brands b ON b.brand_id = ti.brand_id
  WHERE b.category_id = 5
  GROUP BY b.brand_name
)
SELECT 
  brand_name,
  total,
  100.0 * total / SUM(total) OVER () as market_share_pct
FROM tobacco_sales
ORDER BY total DESC;
```

## Superset Integration

1. Import the generated dataset config:
   - File: `scout_seed_data/superset_dataset_scout.yaml`
   - Or create dataset manually pointing to `scout.vw_sales_gold`

2. Create visualizations:
   - **Brand Performance**: Bar chart by brand_name
   - **Category Mix**: Pie chart by category_name
   - **Regional Heatmap**: Choropleth using region_name
   - **Time Series**: Line chart with date (d) dimension
   - **Market Share**: Calculated field using revenue metrics

3. Apply filters:
   - Brand filter (with RLS for TBWA-only view)
   - Category filter
   - Date range picker
   - Region/City cascading filters

## RLS Configuration

The schema includes Row Level Security for multi-tenant access:

```sql
-- Example: Set TBWA tenant context
SET request.jwt.claims = '{"tenant_id": "your-tbwa-tenant-uuid"}';

-- Brands will be automatically filtered
SELECT * FROM scout.brands; -- Only shows brands in brand_ownership for tenant
```

## Troubleshooting

### Connection Issues
```bash
# Test connection
psql "$DATABASE_URL" -c "SELECT version();"

# Check if scout schema exists
psql "$DATABASE_URL" -c "\dn scout"
```

### Data Issues
```bash
# Verify counts
psql "$DATABASE_URL" -c "
  SELECT 'stores' as table_name, COUNT(*) FROM scout.stores
  UNION ALL
  SELECT 'transactions', COUNT(*) FROM scout.transactions
  UNION ALL  
  SELECT 'items', COUNT(*) FROM scout.transaction_items;
"
```

### Performance
```sql
-- Create additional indexes if needed
CREATE INDEX idx_items_transaction ON scout.transaction_items(transaction_id);
CREATE INDEX idx_stores_city ON scout.stores(city);
CREATE INDEX idx_transactions_date ON scout.transactions(DATE(transaction_ts));
```

## Next Steps

1. **Load the data** using one of the methods above
2. **Configure Superset** connection to your database
3. **Import dataset** configuration or create manually
4. **Build dashboards** with brand/category filters
5. **Test RLS** with different tenant contexts
6. **Create alerts** for market share thresholds

For questions or issues, check the main project README or open an issue.