#!/usr/bin/env bash
set -euo pipefail

DBML="docs-site/static/dbml/scout-schema-v3-complete.dbml"
OUTDIR="docs-site/static/dbml/generated"
mkdir -p "$OUTDIR"

echo "▶️ Installing tools if needed…"
# Install dbml-renderer if available, fallback to basic tools
if ! command -v dbml-render >/dev/null 2>&1; then
  echo "⚠️  dbml-render not found, installing @dbml/cli…"
  npm i -g @dbml/cli >/dev/null 2>&1 || true
fi

if ! command -v dbml2sql >/dev/null 2>&1; then
  npm i -g @dbml/cli >/dev/null 2>&1 || {
    echo "❌ Failed to install @dbml/cli"
    exit 1
  }
fi

echo "▶️ Validating DBML syntax…"
dbml2sql "$DBML" --postgres -o "$OUTDIR/scout-v3-complete.sql" >/dev/null 2>&1 || {
  echo "❌ DBML syntax validation failed"
  exit 1
}

echo "✅ DBML validation passed"

# Count actual tables from generated SQL
TABLE_COUNT=$(grep -c "^CREATE TABLE" "$OUTDIR/scout-v3-complete.sql" || echo 0)
echo "📊 Generated SQL contains: $TABLE_COUNT tables"

echo "▶️ Generating outputs…"

# Try advanced renderer first, fallback to basic
if command -v dbml-render >/dev/null 2>&1; then
  echo "📸 Rendering SVG with dbml-render…"
  dbml-render "$DBML" --format svg --out "$OUTDIR/scout-v3-erd.svg" || {
    echo "⚠️  SVG render failed, continuing with other outputs"
  }
else
  echo "ℹ️  Advanced renderer not available, using basic outputs only"
fi

echo "📝 Creating PlantUML diagram…"
cat > "$OUTDIR/scout-v3-erd.puml" << 'EOF'
@startuml scout-v3-erd
!theme aws-orange
skinparam linetype ortho
skinparam backgroundColor #FEFEFE
title Scout Analytics v3.0 - Entity Relationship Diagram (81 Tables)

package "Dimension Tables (8)" #DDDDDD {
  entity dim_date
  entity dim_time
  entity dim_stores
  entity dim_customers
  entity dim_products
  entity dim_campaigns
  entity dim_payment_methods
  entity dim_geometries
}

package "Fact Tables (9)" #FFEEEE {
  entity fact_transactions
  entity fact_transaction_items
  entity fact_daily_sales
  entity fact_consumer_behavior
  entity fact_basket_analysis
  entity fact_substitutions
  entity fact_request_patterns
  entity fact_transaction_duration
  entity fact_monthly_performance
}

package "Master Data (12)" #EEFFEE {
  entity master_brands
  entity master_categories
  entity master_locations
  entity master_ph_locations
  entity master_stores
  entity master_items
  entity master_product_catalog
  entity master_price_list
  entity master_customer_segments
  entity master_promotions
  entity master_suppliers
  entity master_brand_catalog
}

package "Data Pipeline (8)" #EEEEFF {
  entity bronze_transactions
  entity bronze_edge_raw
  entity bronze_products
  entity bronze_events
  entity silver_transactions
  entity gold_sari_sari_kpis
  entity scout_gold_transactions
  entity scout_gold_transaction_items
}

package "Data Collection (5)" #FFFFEE {
  entity stt_brand_dictionary
  entity stt_brand_requests
  entity scraped_items
  entity scraping_queue
  entity scraping_sessions
}

package "Philippines Geography (10)" #FFEEFF {
  entity psgc_regions
  entity psgc_provinces
  entity psgc_cities
  entity psgc_barangays
  entity psgc_special_areas
  entity geo_store_coverage
  entity geo_market_areas
  entity geo_competitor_locations
  entity geo_delivery_zones
  entity geo_demographics
}

package "ETL & Utilities (29)" #F0F0F0 {
  entity etl_queue
  entity etl_watermarks
  entity etl_failures
  entity ingestion_log
  entity enrichment_queue
  entity report_queue
  entity api_keys
  entity audit_log
  entity cache_keys
  entity config_settings
  note "...and 19 more utility tables"
}

' Key relationships
fact_transactions ||--o{ fact_transaction_items
fact_transactions }o--|| dim_stores
fact_transactions }o--|| dim_customers
fact_transactions }o--|| dim_date
fact_transaction_items }o--|| dim_products

master_items }o--|| master_brands
master_items }o--|| master_categories
master_product_catalog }o--|| master_items

psgc_barangays }o--|| psgc_cities
psgc_cities }o--|| psgc_provinces
psgc_provinces }o--|| psgc_regions

note bottom : Scout v3.0 Complete Schema\n81 Base Tables + 120+ Analytics Views

@enduml
EOF

echo "📄 Creating dbdiagram.io export…"
cp "$DBML" "$OUTDIR/scout-v3-for-dbdiagram.dbml"

echo "📊 Creating schema summary…"
cat > "$OUTDIR/scout-v3-summary.md" << EOF
# Scout v3.0 Schema Summary

Generated: $(date)

## Table Counts by Category

| Category | Count | Description |
|----------|-------|-------------|
| **Dimension Tables** | 8 | Core dimensional data |
| **Fact Tables** | 9 | Transaction and behavioral facts |
| **Master Data** | 12 | Reference data and catalogs |
| **Bridge Tables** | 3 | Many-to-many relationships |
| **Bronze Layer** | 4 | Raw data ingestion |
| **Silver Layer** | 1 | Cleansed transactions |
| **Gold Layer** | 3 | Analytics-ready aggregates |
| **Data Collection** | 5 | STT and web scraping |
| **Philippines Geography** | 10 | PSGC and location data |
| **ETL Management** | 6 | Pipeline orchestration |
| **Utilities** | 8+ | System and audit tables |
| **Analytics Views** | 120+ | Pre-built aggregations |

## Total: 81 Base Tables + 120+ Views = 200+ Database Objects

## Key v3 Features

- ✅ Complete Philippines geography with PSGC codes
- ✅ Speech-to-text brand detection
- ✅ Web scraping infrastructure for SKU enrichment
- ✅ Master data management layer
- ✅ Enhanced ETL pipeline with queue management
- ✅ Bridge tables for complex relationships
- ✅ Comprehensive audit and monitoring

## Generated Files

- \`scout-v3-complete.sql\` - Complete PostgreSQL DDL
- \`scout-v3-erd.puml\` - PlantUML diagram source
- \`scout-v3-for-dbdiagram.dbml\` - Interactive diagram import
- \`scout-v3-summary.md\` - This summary
EOF

# Create README for generated files
cat > "$OUTDIR/README.md" << 'EOF'
# Scout v3 Generated Documentation

This directory contains auto-generated documentation from the Scout v3 DBML schema.

## Files

- **scout-v3-complete.sql** - Complete PostgreSQL DDL (ready to deploy)
- **scout-v3-erd.puml** - PlantUML diagram source
- **scout-v3-for-dbdiagram.dbml** - DBML for interactive viewing
- **scout-v3-summary.md** - Schema statistics and overview

## View the ERD

### Option 1: dbdiagram.io (Recommended)
1. Go to https://dbdiagram.io/
2. Import → From DBML
3. Upload `scout-v3-for-dbdiagram.dbml`

### Option 2: PlantUML
```bash
plantuml scout-v3-erd.puml
```

### Option 3: VS Code
Install PlantUML extension, open .puml file, Alt+D to preview

## Deploy Schema
```bash
psql "$DATABASE_URL" -f scout-v3-complete.sql
```
EOF

echo "✅ ERD generation complete!"
echo ""
echo "Generated files in $OUTDIR:"
ls -la "$OUTDIR"
echo ""
echo "📋 Next steps:"
echo "1. View ERD: Upload scout-v3-for-dbdiagram.dbml to https://dbdiagram.io/"
echo "2. Generate PNG: plantuml $OUTDIR/scout-v3-erd.puml"
echo "3. Deploy schema: psql \"\$DATABASE_URL\" -f $OUTDIR/scout-v3-complete.sql"