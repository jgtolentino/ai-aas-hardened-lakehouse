# SKU Catalog Integration Guide

## Overview

This guide covers the integration of a comprehensive **347-product SKU catalog** into the Scout Analytics platform, including telco products, barcodes, and halal certification tracking.

## What's Included

### Product Categories
1. **TBWA Client Products** (89 products)
   - Alaska (Dairy)
   - Oishi (Snacks)
   - Del Monte (Canned Goods)
   - JTI (Tobacco)
   - Marca Leon (Oils)

2. **Competitor Products** (100+ products)
   - Nestle (Bear Brand, Nido)
   - Universal Robina (Jack n Jill)
   - Other major brands

3. **Telco Products** (50+ products)
   - Globe (Load & Data packages)
   - Smart (Load & Data packages)
   - TNT (Load products)
   - TM (Load products)

4. **Generic Products** (150+ products)
   - Personal Care
   - Home Care
   - Food & Beverages
   - Health & Wellness

## Database Schema

### Core Tables

#### `masterdata.products` (Extended)
```sql
- id UUID PRIMARY KEY
- brand_id UUID REFERENCES brands
- product_name TEXT
- category TEXT
- subcategory TEXT
- pack_size TEXT
- barcode TEXT (NEW)
- halal_certified BOOLEAN (NEW)
- upc TEXT
- metadata JSONB
- is_active BOOLEAN
- created_at TIMESTAMPTZ
- updated_at TIMESTAMPTZ
```

#### `masterdata.telco_products` (NEW)
```sql
- id UUID PRIMARY KEY
- product_id UUID REFERENCES products
- network TEXT (Globe, Smart, TNT, TM)
- product_type TEXT (Load, Data, Promo)
- denomination DECIMAL
- data_volume_mb INTEGER
- validity_days INTEGER
- promo_code TEXT
- ussd_code TEXT
- keywords TEXT[]
```

#### `masterdata.barcode_registry` (NEW)
```sql
- barcode TEXT PRIMARY KEY
- product_id UUID REFERENCES products
- barcode_type TEXT
- verified BOOLEAN
- verified_at TIMESTAMPTZ
```

#### `masterdata.price_history` (NEW)
```sql
- id UUID PRIMARY KEY
- product_id UUID REFERENCES products
- store_id UUID
- price_date DATE
- list_price DECIMAL
- selling_price DECIMAL
- promo_price DECIMAL
```

## Import Process

### Step 1: Apply Database Migrations

```bash
# Apply the SKU catalog schema
psql $DATABASE_URL -f supabase/migrations/20250823_import_sku_catalog.sql

# Apply telco extensions
psql $DATABASE_URL -f supabase/migrations/20250824170000_sku_catalog_telco_extensions.sql
```

### Step 2: Run Import Script

```bash
# Set environment variables
export SUPABASE_URL="https://cxzllzyxwpyptfretryc.supabase.co"
export SUPABASE_ANON_KEY="your-anon-key"

# Run the import
node scripts/import-sku-catalog-347.js
```

### Step 3: Verify Import

```sql
-- Check product counts
SELECT 
    category_name,
    COUNT(*) as product_count,
    COUNT(DISTINCT brand_name) as brand_count,
    SUM(CASE WHEN halal_certified THEN 1 ELSE 0 END) as halal_count
FROM masterdata.v_product_catalog
GROUP BY category_name
ORDER BY product_count DESC;

-- Check telco products
SELECT 
    network,
    product_type,
    COUNT(*) as count,
    MIN(denomination) as min_price,
    MAX(denomination) as max_price
FROM masterdata.v_telco_products
GROUP BY network, product_type
ORDER BY network, product_type;
```

## Available Views

### `masterdata.v_product_catalog`
Complete product catalog with all details including telco data and pricing.

### `masterdata.v_telco_products`
Telco-specific products with network, denomination, and data package details.

### `masterdata.v_halal_products`
Products certified as halal for Muslim consumers.

### `masterdata.v_catalog_summary`
Summary statistics by brand including barcode coverage.

## API Endpoints

### Get Products by Category
```javascript
const { data } = await supabase
  .from('v_product_catalog')
  .select('*')
  .eq('category', 'Telco')
  .eq('telco_network', 'Globe');
```

### Search by Barcode
```javascript
const { data } = await supabase
  .from('products')
  .select('*, brands(*)')
  .eq('barcode', '4800016644122')
  .single();
```

### Get Halal Products
```javascript
const { data } = await supabase
  .from('v_halal_products')
  .select('*')
  .eq('category', 'Food');
```

## Dashboard Integration

### Telco Sales Dashboard
```sql
-- Daily telco sales by network
SELECT 
    tp.network,
    COUNT(DISTINCT ft.transaction_id) as transactions,
    SUM(fti.total_amount) as revenue,
    AVG(tp.denomination) as avg_denomination
FROM scout.fact_transaction_items fti
JOIN masterdata.telco_products tp ON tp.product_id = fti.product_id
JOIN scout.fact_transactions ft ON ft.transaction_id = fti.transaction_id
WHERE ft.transaction_date = CURRENT_DATE
GROUP BY tp.network;
```

### Product Mix Analysis
```sql
-- TBWA vs Competitor sales
SELECT 
    CASE 
        WHEN b.brand_name IN ('Alaska', 'Oishi', 'Del Monte', 'JTI', 'Marca Leon') 
        THEN 'TBWA Client'
        ELSE 'Competitor'
    END as brand_type,
    COUNT(DISTINCT fti.transaction_id) as transactions,
    SUM(fti.total_amount) as revenue
FROM scout.fact_transaction_items fti
JOIN masterdata.products p ON p.id = fti.product_id
JOIN masterdata.brands b ON b.id = p.brand_id
GROUP BY brand_type;
```

## Business Benefits

1. **Complete Product Coverage**: 347 products with rich metadata
2. **Telco Integration**: Track load and data sales
3. **Cultural Sensitivity**: Halal tracking for Muslim market (30%+ of products)
4. **Operational Efficiency**: Barcode scanning ready
5. **Price Intelligence**: Historical price tracking
6. **Market Analysis**: TBWA client vs competitor insights

## Troubleshooting

### Import Errors
- Check Supabase connection credentials
- Ensure staging schema exists
- Verify RLS policies allow inserts

### Missing Data
- Run `SELECT * FROM staging.sku_catalog_upload` to check staging
- Verify import function: `SELECT masterdata.import_sku_catalog()`

### Performance Issues
- Create indexes on frequently queried columns
- Use materialized views for complex aggregations
- Partition large tables by date

## Next Steps

1. **Configure UI Filters**: Add halal and telco filters to dashboards
2. **Set Up Barcode Scanner**: Integrate hardware scanners
3. **Create Price Alerts**: Monitor price changes
4. **Build Telco Analytics**: Load/data sales trends
5. **Export Reports**: SKU performance by store/region