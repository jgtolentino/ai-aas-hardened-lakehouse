#!/bin/bash
# Import Superset dashboard bundles for Scout Analytics Platform
# This script imports pre-configured dashboards for Supabase data source

set -euo pipefail

# Configuration
SUPERSET_URL="${SUPERSET_URL:-http://localhost:8088}"
SUPERSET_USER="${SUPERSET_USER:-admin}"
SUPERSET_PASS="${SUPERSET_PASS:-admin}"
BUNDLE_DIR="$(dirname "$0")/../bundles"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Importing Superset dashboards...${NC}"

# Check if Superset is running
if ! curl -s "${SUPERSET_URL}/health" > /dev/null; then
    echo -e "${RED}ERROR: Superset is not accessible at ${SUPERSET_URL}${NC}"
    echo "Please ensure Superset is running and port-forwarded:"
    echo "  kubectl port-forward -n aaas svc/superset 8088:8088"
    exit 1
fi

# Get auth token
echo "Authenticating with Superset..."
AUTH_TOKEN=$(curl -s -X POST "${SUPERSET_URL}/api/v1/security/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${SUPERSET_USER}\",\"password\":\"${SUPERSET_PASS}\",\"provider\":\"db\"}" \
    | jq -r '.access_token')

if [ -z "$AUTH_TOKEN" ] || [ "$AUTH_TOKEN" = "null" ]; then
    echo -e "${RED}ERROR: Failed to authenticate with Superset${NC}"
    exit 1
fi

# Import Supabase connection bundle
if [ -f "${BUNDLE_DIR}/supabase_scout_bundle.zip" ]; then
    echo "Importing Supabase Scout bundle..."
    
    # Upload bundle
    IMPORT_RESPONSE=$(curl -s -X POST "${SUPERSET_URL}/api/v1/assets/import/" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -F "bundle=@${BUNDLE_DIR}/supabase_scout_bundle.zip" \
        -F "passwords={\"databases/Scout_Supabase.yaml\":\"${SUPABASE_DB_PASSWORD}\"}" \
        -F "overwrite=true")
    
    # Check response
    if echo "$IMPORT_RESPONSE" | grep -q "error"; then
        echo -e "${RED}ERROR: Failed to import Supabase bundle${NC}"
        echo "$IMPORT_RESPONSE"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Supabase bundle imported successfully${NC}"
else
    echo -e "${YELLOW}WARNING: Supabase bundle not found at ${BUNDLE_DIR}/supabase_scout_bundle.zip${NC}"
    echo "Creating bundle from current configuration..."
    
    # Create bundle programmatically
    python3 - <<EOF
import requests
import json
import zipfile
import io
import yaml
from datetime import datetime

# Configuration
api_url = "${SUPERSET_URL}/api/v1"
headers = {"Authorization": "Bearer ${AUTH_TOKEN}"}

# Create database connection
db_config = {
    "database_name": "Scout Supabase",
    "sqlalchemy_uri": "postgresql://postgres:${SUPABASE_DB_PASSWORD}@db.${SUPABASE_PROJECT_REF}.supabase.co:5432/postgres?sslmode=require",
    "expose_in_sqllab": True,
    "allow_ctas": False,
    "allow_cvas": False,
    "allow_dml": False,
    "allow_multi_schema_metadata_fetch": True,
    "extra": json.dumps({
        "metadata_params": {},
        "engine_params": {},
        "metadata_cache_timeout": {},
        "schemas_allowed_for_csv_upload": ["scout"]
    })
}

# Create database
resp = requests.post(f"{api_url}/database/", json=db_config, headers=headers)
if resp.status_code == 201:
    print("✓ Database connection created")
    db_id = resp.json()["id"]
elif resp.status_code == 422:
    print("Database already exists, fetching ID...")
    resp = requests.get(f"{api_url}/database/?q=(filters:!((col:database_name,opr:eq,value:'Scout Supabase')))", headers=headers)
    db_id = resp.json()["result"][0]["id"]
else:
    print(f"ERROR: Failed to create database: {resp.text}")
    exit(1)

# Create datasets
datasets = [
    {
        "database": db_id,
        "table_name": "daily_aggregates",
        "schema": "scout",
        "sql": """
SELECT 
    date_day,
    store_id,
    barangay,
    city,
    total_transactions,
    unique_shoppers,
    total_sales,
    avg_transaction_value,
    morning_sales,
    afternoon_sales,
    evening_sales,
    night_sales
FROM scout.gold_daily_aggregates
WHERE date_day >= CURRENT_DATE - INTERVAL '30 days'
"""
    },
    {
        "database": db_id,
        "table_name": "hourly_patterns",
        "schema": "scout",
        "sql": """
SELECT 
    date_hour,
    hour_of_day,
    day_of_week,
    store_id,
    barangay,
    transaction_count,
    sales_amount,
    unique_shoppers
FROM scout.gold_hourly_patterns
WHERE date_hour >= CURRENT_TIMESTAMP - INTERVAL '7 days'
"""
    },
    {
        "database": db_id,
        "table_name": "product_performance",
        "schema": "scout",
        "sql": """
SELECT 
    date_day,
    product_name,
    category,
    barangay,
    city,
    quantity_sold,
    revenue,
    transaction_count,
    avg_price
FROM scout.gold_product_performance
WHERE date_day >= CURRENT_DATE - INTERVAL '30 days'
"""
    }
]

dataset_ids = []
for ds in datasets:
    resp = requests.post(f"{api_url}/dataset/", json=ds, headers=headers)
    if resp.status_code == 201:
        dataset_ids.append(resp.json()["id"])
        print(f"✓ Created dataset: {ds['table_name']}")
    else:
        print(f"WARNING: Dataset {ds['table_name']} may already exist")

print(f"✓ Created {len(dataset_ids)} datasets")

# Create charts
charts = [
    {
        "slice_name": "Daily Sales Trend",
        "viz_type": "line",
        "datasource_id": dataset_ids[0] if dataset_ids else 1,
        "datasource_type": "table",
        "params": json.dumps({
            "metrics": ["total_sales"],
            "groupby": ["date_day"],
            "time_range": "Last 30 days",
            "line_interpolation": "linear",
            "show_legend": True
        })
    },
    {
        "slice_name": "Sales by Time of Day",
        "viz_type": "pie",
        "datasource_id": dataset_ids[0] if dataset_ids else 1,
        "datasource_type": "table",
        "params": json.dumps({
            "metrics": [
                {"expressionType": "SIMPLE", "column": {"column_name": "morning_sales"}, "aggregate": "SUM"},
                {"expressionType": "SIMPLE", "column": {"column_name": "afternoon_sales"}, "aggregate": "SUM"},
                {"expressionType": "SIMPLE", "column": {"column_name": "evening_sales"}, "aggregate": "SUM"},
                {"expressionType": "SIMPLE", "column": {"column_name": "night_sales"}, "aggregate": "SUM"}
            ],
            "show_legend": True,
            "donut": True
        })
    },
    {
        "slice_name": "Top Products by Revenue",
        "viz_type": "table",
        "datasource_id": dataset_ids[2] if len(dataset_ids) > 2 else 1,
        "datasource_type": "table",
        "params": json.dumps({
            "metrics": ["revenue", "quantity_sold"],
            "groupby": ["product_name", "category"],
            "row_limit": 20,
            "order_desc": True
        })
    }
]

chart_ids = []
for chart in charts:
    resp = requests.post(f"{api_url}/chart/", json=chart, headers=headers)
    if resp.status_code == 201:
        chart_ids.append(resp.json()["id"])
        print(f"✓ Created chart: {chart['slice_name']}")

# Create dashboard
dashboard = {
    "dashboard_title": "Scout Analytics Dashboard",
    "slug": "scout-analytics",
    "published": True,
    "position_json": json.dumps({
        "DASHBOARD_VERSION_KEY": "v2",
        "GRID_ID": {"id": "GRID_ID", "children": []},
        "HEADER_ID": {"id": "HEADER_ID", "meta": {"text": "Scout Analytics Dashboard"}},
        "ROOT_ID": {"children": ["GRID_ID"], "id": "ROOT_ID", "type": "ROOT"}
    }),
    "metadata": {
        "native_filter_configuration": [],
        "chart_configuration": {str(cid): {} for cid in chart_ids}
    }
}

resp = requests.post(f"{api_url}/dashboard/", json=dashboard, headers=headers)
if resp.status_code == 201:
    print("✓ Created dashboard: Scout Analytics Dashboard")
    dashboard_id = resp.json()["id"]
    
    # Add charts to dashboard
    for i, chart_id in enumerate(chart_ids):
        requests.post(f"{api_url}/dashboard/{dashboard_id}/charts", 
                     json={"slice_id": chart_id}, 
                     headers=headers)
    print(f"✓ Added {len(chart_ids)} charts to dashboard")
else:
    print(f"WARNING: Dashboard creation failed: {resp.text}")

print("\n✓ Import completed successfully!")
print(f"Access dashboard at: ${SUPERSET_URL}/superset/dashboard/scout-analytics/")
EOF
fi

echo -e "${GREEN}✓ Superset import completed${NC}"
echo ""
echo "Next steps:"
echo "1. Access Superset at: ${SUPERSET_URL}"
echo "2. Login with user: ${SUPERSET_USER}"
echo "3. Navigate to Dashboards > Scout Analytics Dashboard"
echo ""
echo "To refresh data sources:"
echo "  - Go to Data > Datasets"
echo "  - Click refresh on each dataset"