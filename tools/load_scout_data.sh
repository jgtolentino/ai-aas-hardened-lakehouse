#!/bin/bash
# Load Scout Analytics data into Supabase or PostgreSQL
# Supports both CSV files and direct SQL generation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/scout_seed_data"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default database URL (can be overridden)
DB_URL="${DATABASE_URL:-postgresql://postgres:postgres@localhost:5432/postgres}"

# Help function
show_help() {
    echo "Scout Analytics Data Loader"
    echo "=========================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --db-url URL     Database connection URL (default: \$DATABASE_URL)"
    echo "  -g, --generate       Generate CSV files only (don't load)"
    echo "  -l, --load           Load existing CSV files to database"
    echo "  -s, --synthetic      Generate and load synthetic data using Python"
    echo "  -c, --csv            Generate and load CSV data"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Generate CSV files only"
    echo "  $0 --generate"
    echo ""
    echo "  # Load to Supabase"
    echo "  $0 --load --db-url 'postgresql://postgres:password@db.project.supabase.co:5432/postgres'"
    echo ""
    echo "  # Generate and load synthetic data"
    echo "  $0 --synthetic"
}

# Parse arguments
GENERATE_ONLY=false
LOAD_ONLY=false
USE_SYNTHETIC=false
USE_CSV=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--db-url)
            DB_URL="$2"
            shift 2
            ;;
        -g|--generate)
            GENERATE_ONLY=true
            shift
            ;;
        -l|--load)
            LOAD_ONLY=true
            shift
            ;;
        -s|--synthetic)
            USE_SYNTHETIC=true
            shift
            ;;
        -c|--csv)
            USE_CSV=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Functions
generate_csvs() {
    echo -e "${GREEN}Generating Scout Analytics CSV files...${NC}"
    python3 "${SCRIPT_DIR}/generate_scout_csvs.py"
}

load_synthetic() {
    echo -e "${GREEN}Loading synthetic data directly to database...${NC}"
    export SUPABASE_DB_URI="$DB_URL"
    python3 "${SCRIPT_DIR}/seed_scout_data.py"
}

load_csvs() {
    echo -e "${GREEN}Loading CSV files to database...${NC}"
    
    if [ ! -d "$DATA_DIR" ]; then
        echo -e "${RED}Error: Data directory not found. Run with --generate first.${NC}"
        exit 1
    fi
    
    # First, apply the schema
    echo "Applying schema..."
    psql "$DB_URL" < "${DATA_DIR}/scout_rls_and_schema.sql"
    
    # Load CSVs in order (respecting foreign keys)
    echo "Loading categories..."
    psql "$DB_URL" -c "\COPY scout.categories FROM '${DATA_DIR}/categories.csv' WITH CSV HEADER"
    
    echo "Loading brands..."
    psql "$DB_URL" -c "\COPY scout.brands FROM '${DATA_DIR}/brands.csv' WITH CSV HEADER"
    
    echo "Loading master SKU data..."
    psql "$DB_URL" -c "\COPY scout.master_data_brand_sku FROM '${DATA_DIR}/master_data_brand_sku.csv' WITH CSV HEADER"
    
    echo "Loading SKU variants..."
    psql "$DB_URL" -c "\COPY scout.sku_variants FROM '${DATA_DIR}/sku_variants.csv' WITH CSV HEADER"
    
    echo "Loading stores..."
    psql "$DB_URL" -c "\COPY scout.stores FROM '${DATA_DIR}/stores.csv' WITH CSV HEADER"
    
    echo "Loading transactions..."
    psql "$DB_URL" -c "\COPY scout.transactions FROM '${DATA_DIR}/transactions.csv' WITH CSV HEADER"
    
    echo "Loading transaction items..."
    psql "$DB_URL" -c "\COPY scout.transaction_items FROM '${DATA_DIR}/transaction_items.csv' WITH CSV HEADER"
    
    echo "Loading brand ownership (RLS)..."
    psql "$DB_URL" -c "\COPY scout.brand_ownership FROM '${DATA_DIR}/brand_ownership.csv' WITH CSV HEADER"
    
    echo -e "${GREEN}Data loaded successfully!${NC}"
}

verify_data() {
    echo -e "${YELLOW}Verifying data...${NC}"
    
    psql "$DB_URL" <<EOF
-- Verification queries
SELECT 'Total Stores' as metric, COUNT(*) as count FROM scout.stores
UNION ALL
SELECT 'Total Transactions', COUNT(*) FROM scout.transactions
UNION ALL
SELECT 'Total SKUs', COUNT(*) FROM scout.master_data_brand_sku
UNION ALL
SELECT 'TBWA Brands', COUNT(*) FROM scout.brands WHERE is_tbwa_client = true
UNION ALL
SELECT 'Total Revenue', SUM(basket_total) FROM scout.transactions;

-- Market share check
WITH brand_sales AS (
  SELECT 
    b.brand_name,
    b.is_tbwa_client,
    c.category_name,
    SUM(ti.line_total) as total_sales
  FROM scout.transaction_items ti
  JOIN scout.brands b ON b.brand_id = ti.brand_id
  JOIN scout.categories c ON c.category_id = b.category_id
  GROUP BY b.brand_name, b.is_tbwa_client, c.category_name
),
category_totals AS (
  SELECT 
    category_name,
    SUM(total_sales) as category_total
  FROM brand_sales
  GROUP BY category_name
)
SELECT 
  bs.category_name,
  bs.brand_name,
  bs.total_sales,
  ROUND(100.0 * bs.total_sales / ct.category_total, 2) as market_share_pct
FROM brand_sales bs
JOIN category_totals ct ON ct.category_name = bs.category_name
WHERE bs.is_tbwa_client = true OR bs.brand_name IN ('JTI', 'PMFTC', 'BAT')
ORDER BY bs.category_name, market_share_pct DESC;
EOF
}

create_superset_dataset() {
    echo -e "${GREEN}Creating Superset dataset configuration...${NC}"
    
    cat > "${DATA_DIR}/superset_dataset_scout.yaml" <<EOF
# Superset Dataset Configuration for Scout Analytics
# Import this in Superset to create the dataset

database_name: "Supabase (prod)"
schema: "scout"
table_name: "vw_sales_gold"
description: "Scout Analytics Gold Layer - Sales by Brand, SKU, and Geography"

columns:
  - column_name: brand_id
    verbose_name: "Brand ID"
    type: INTEGER
    filterable: true
    groupby: true
    
  - column_name: brand_name
    verbose_name: "Brand"
    type: VARCHAR
    filterable: true
    groupby: true
    
  - column_name: category_name
    verbose_name: "Category"
    type: VARCHAR
    filterable: true
    groupby: true
    
  - column_name: sku_name
    verbose_name: "SKU"
    type: VARCHAR
    filterable: true
    groupby: true
    
  - column_name: region_name
    verbose_name: "Region"
    type: VARCHAR
    filterable: true
    groupby: true
    
  - column_name: city
    verbose_name: "City"
    type: VARCHAR
    filterable: true
    groupby: true
    
  - column_name: barangay
    verbose_name: "Barangay"
    type: VARCHAR
    filterable: true
    groupby: true
    
  - column_name: d
    verbose_name: "Date"
    type: DATE
    filterable: true
    groupby: true
    is_dttm: true
    
  - column_name: qty
    verbose_name: "Quantity Sold"
    type: BIGINT
    filterable: false
    groupby: false
    
  - column_name: revenue
    verbose_name: "Revenue (PHP)"
    type: NUMERIC
    filterable: false
    groupby: false

metrics:
  - metric_name: total_revenue
    verbose_name: "Total Revenue"
    metric_type: sum
    expression: "SUM(revenue)"
    
  - metric_name: total_quantity
    verbose_name: "Total Quantity"
    metric_type: sum
    expression: "SUM(qty)"
    
  - metric_name: avg_revenue_per_sku
    verbose_name: "Avg Revenue per SKU"
    metric_type: avg
    expression: "AVG(revenue)"
    
  - metric_name: unique_skus
    verbose_name: "Unique SKUs"
    metric_type: count_distinct
    expression: "COUNT(DISTINCT sku_id)"
    
  - metric_name: market_share_pct
    verbose_name: "Market Share %"
    metric_type: expression
    expression: "100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER ()"
EOF

    echo -e "${GREEN}Superset dataset config created at: ${DATA_DIR}/superset_dataset_scout.yaml${NC}"
}

# Main execution
main() {
    echo -e "${GREEN}Scout Analytics Data Loader${NC}"
    echo "==========================="
    echo ""
    
    # Check Python dependencies
    if ! python3 -c "import pandas, numpy, sqlalchemy" 2>/dev/null; then
        echo -e "${YELLOW}Installing required Python packages...${NC}"
        pip3 install pandas numpy sqlalchemy python-dotenv faker psycopg2-binary
    fi
    
    # Execute based on options
    if [ "$GENERATE_ONLY" = true ]; then
        generate_csvs
        create_superset_dataset
    elif [ "$LOAD_ONLY" = true ]; then
        load_csvs
        verify_data
    elif [ "$USE_SYNTHETIC" = true ]; then
        load_synthetic
        verify_data
    elif [ "$USE_CSV" = true ]; then
        generate_csvs
        load_csvs
        verify_data
        create_superset_dataset
    else
        # Default: generate and load CSVs
        generate_csvs
        load_csvs
        verify_data
        create_superset_dataset
    fi
    
    echo ""
    echo -e "${GREEN}✅ Process completed successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Import the Superset dataset using: ${DATA_DIR}/superset_dataset_scout.yaml"
    echo "2. Create charts and dashboards in Superset"
    echo "3. Apply RLS policies as needed for multi-tenant access"
}

# Run main function
main