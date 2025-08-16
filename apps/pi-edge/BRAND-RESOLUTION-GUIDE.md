# Scout Edge Brand Resolution System

## Overview

This brand resolution system unifies all brand sources (STT dictionary, catalog, observed) into an intelligent system that automatically standardizes and resolves brands on data ingestion.

## 🏗️ Architecture

### 1. **Brand Universe** (`scout.v_brand_universe`)
- Unifies brands from all sources: STT dictionary, PH catalog, observed data
- Normalizes all brand names (uppercase, remove special chars, unaccent)
- Tracks which sources know about each brand

### 2. **Variant Index** (`scout.v_variant_index`)
- Maps 337+ brand variants from STT dictionary
- Handles common misspellings, local terms, abbreviations
- Examples: "coke" → "COCA COLA", "yosi" → "MARLBORO"

### 3. **Server-Side Resolver** (`scout.brand_resolve()`)
- Runs automatically on every insert
- Resolution hierarchy:
  1. Exact brand match
  2. Exact variant match
  3. Fuzzy variant match (55% similarity)
  4. Fuzzy brand match (60% similarity)
- Falls back to extracting from product_name/local_name

### 4. **Token Mining** (Optional)
- Mines brands from conversation transcripts
- Cross-references with STT dictionary
- Provides additional context for resolution

## 📊 Key Views & Reports

### Brand Coverage Views
- `scout.v_brand_universe_summary` - Overall system statistics
- `scout.v_brand_coverage` - Brand performance metrics
- `scout.v_brands_unrecognized` - Unknown brand values
- `scout.v_brand_performance` - Revenue and transaction analysis

### Quality Metrics
```sql
-- Check current brand coverage
SELECT * FROM scout.v_brand_universe_summary;

-- View unrecognized brands
SELECT * FROM scout.v_brands_unrecognized LIMIT 20;

-- Brand performance last 30 days
SELECT * FROM scout.v_brand_performance LIMIT 20;
```

## 🚀 Setup Instructions

### 1. One-Command Setup
```bash
# Set database connection
export POSTGRES_URL="postgresql://user:pass@host/db"

# Run complete setup
./scripts/setup-brand-resolution.sh
```

### 2. Manual Setup (if needed)
```bash
# Create STT dictionary
psql $POSTGRES_URL -f scripts/stt-brand-dictionary.sql

# Create brand universe views
psql $POSTGRES_URL -f scripts/brand-universe-setup.sql

# Install resolver trigger
psql $POSTGRES_URL -f scripts/brand-resolver-trigger.sql

# Optional: Add token mining
psql $POSTGRES_URL -f scripts/token-mining-trigger.sql
```

### 3. Backfill Existing Data
```sql
-- Resolve brands for existing items (in batches)
SELECT * FROM scout.backfill_resolve_brands(1000);
```

### 4. Export for Edge Devices
```bash
# Generate catalog files
./scripts/export-brand-catalog.sh

# Deploy to Pi
scp /tmp/brand_catalog.csv pi@192.168.1.44:/opt/scout-edge/app/dictionaries/
scp /tmp/brand_variants.json pi@192.168.1.44:/opt/scout-edge/app/dictionaries/
```

## 📈 Expected Results

### Before Brand Resolution
- Brand coverage: 0.33%
- Manual brand entry required
- No standardization
- High variation in naming

### After Brand Resolution
- Brand coverage: 70%+ (immediate)
- Automatic standardization
- Variant handling (337+ mappings)
- Continuous learning from observations

## 🔧 Maintenance

### Adding New Brands
```sql
-- Add to STT dictionary
INSERT INTO scout.stt_brand_dictionary (brand, variant, category)
VALUES ('BRAND NAME', 'variant1', 'Category'),
       ('BRAND NAME', 'variant2', 'Category');

-- Add to PH catalog
INSERT INTO suqi.ph_brand_catalog (keyword, brand_name, category, confidence)
VALUES ('keyword', 'Brand Name', 'Category', 0.90);
```

### Monitoring Coverage
```sql
-- Daily coverage trend
SELECT date, brand_coverage_pct 
FROM suqi.daily_quality_trends 
ORDER BY date DESC;

-- By detection method
SELECT detection_method, brand_coverage_pct 
FROM (
  SELECT detection_method,
         ROUND(100.0 * COUNT(brand_name) / COUNT(*), 2) as brand_coverage_pct
  FROM public.scout_gold_transaction_items
  GROUP BY detection_method
) x;
```

### Tuning Thresholds
The fuzzy matching thresholds can be adjusted in `scout.brand_resolve()`:
- Variant match: 0.55 (default)
- Brand match: 0.60 (default)

Lower values = more matches but potentially wrong
Higher values = fewer matches but more accurate

## 🎯 How This Closes TBWA Gaps

1. **99.67% Brand Missing** ✅
   - Server-side resolution on every insert
   - 337+ variant mappings from STT
   - Fuzzy matching for misspellings
   - Backfill for historical data

2. **Coverage Reporting** ✅
   - Real-time brand coverage views
   - Unrecognized brand tracking
   - Performance metrics by brand

3. **Quality Improvement** ✅
   - Automatic standardization
   - Confidence boost for resolved brands
   - Continuous learning from observations

4. **Integration** ✅
   - Works with existing edge function
   - No client-side changes needed
   - Export for edge devices

## 📊 Sample Outputs

### Brand Universe Summary
```
brands_total | brands_observed | brands_catalog | brands_stt_dict
-------------|-----------------|----------------|----------------
     245     |       87        |       70       |      158
```

### Coverage Report
```
total_items | items_with_brand | brand_coverage_pct
------------|------------------|-------------------
   15,234   |     10,664       |      70.00
```

### Top Performing Brands
```
brand       | transactions | units_sold | revenue  | avg_confidence
------------|--------------|------------|----------|---------------
COCA COLA   |     1,234    |   2,468    | 160,420  |    0.945
LUCKY ME    |     1,089    |   3,267    |  32,670  |    0.923
SAN MIGUEL  |       876    |   1,752    | 122,640  |    0.891
```

## 🔍 Troubleshooting

### Low Coverage After Setup
1. Check if trigger is installed: `\df scout.trg_items_brand_resolve`
2. Run backfill: `SELECT * FROM scout.backfill_resolve_brands(10000);`
3. Check unrecognized brands: `SELECT * FROM scout.v_brands_unrecognized;`

### Brands Not Resolving
1. Check normalization: `SELECT scout.norm_brand('Your Brand');`
2. Verify in universe: `SELECT * FROM scout.v_brand_universe WHERE brand LIKE '%YOUR%';`
3. Add to dictionary if missing

### Performance Issues
1. Ensure indexes exist: `\di *brand*`
2. Refresh materialized views if using
3. Consider partitioning for large datasets