#!/bin/bash
# Import Superset dashboard bundles for Trino/Lakehouse data source
# This script imports pre-configured dashboards for Trino lakehouse queries

set -euo pipefail

# Configuration
SUPERSET_URL="${SUPERSET_URL:-http://localhost:8088}"
SUPERSET_USER="${SUPERSET_USER:-admin}"
SUPERSET_PASS="${SUPERSET_PASS:-admin}"
BUNDLE_DIR="$(dirname "$0")/../bundles"
TRINO_HOST="${TRINO_HOST:-trino.aaas.svc.cluster.local}"
TRINO_PORT="${TRINO_PORT:-8080}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Importing Trino lakehouse dashboards...${NC}"

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

# Import Trino connection bundle
if [ -f "${BUNDLE_DIR}/trino_lakehouse_bundle.zip" ]; then
    echo "Importing Trino lakehouse bundle..."
    
    # Upload bundle
    IMPORT_RESPONSE=$(curl -s -X POST "${SUPERSET_URL}/api/v1/assets/import/" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -F "bundle=@${BUNDLE_DIR}/trino_lakehouse_bundle.zip" \
        -F "overwrite=true")
    
    # Check response
    if echo "$IMPORT_RESPONSE" | grep -q "error"; then
        echo -e "${RED}ERROR: Failed to import Trino bundle${NC}"
        echo "$IMPORT_RESPONSE"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Trino bundle imported successfully${NC}"
else
    echo -e "${YELLOW}WARNING: Trino bundle not found at ${BUNDLE_DIR}/trino_lakehouse_bundle.zip${NC}"
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

# Create Trino database connection
db_config = {
    "database_name": "Scout Lakehouse (Trino)",
    "sqlalchemy_uri": "trino://admin@${TRINO_HOST}:${TRINO_PORT}/iceberg",
    "expose_in_sqllab": True,
    "allow_ctas": True,
    "allow_cvas": True,
    "allow_dml": False,
    "allow_multi_schema_metadata_fetch": True,
    "extra": json.dumps({
        "metadata_params": {},
        "engine_params": {
            "connect_args": {
                "http_scheme": "http",
                "catalog": "iceberg"
            }
        },
        "metadata_cache_timeout": {},
        "schemas_allowed_for_csv_upload": []
    })
}

# Create database
resp = requests.post(f"{api_url}/database/", json=db_config, headers=headers)
if resp.status_code == 201:
    print("✓ Trino database connection created")
    db_id = resp.json()["id"]
elif resp.status_code == 422:
    print("Trino database already exists, fetching ID...")
    resp = requests.get(f"{api_url}/database/?q=(filters:!((col:database_name,opr:eq,value:'Scout Lakehouse (Trino)')))", headers=headers)
    db_id = resp.json()["result"][0]["id"] if resp.json()["result"] else None
else:
    print(f"ERROR: Failed to create Trino database: {resp.text}")
    exit(1)

# Create Iceberg/Trino datasets
datasets = [
    {
        "database": db_id,
        "table_name": "platinum_executive_summary",
        "schema": "platinum",
        "sql": """
SELECT 
    reporting_date,
    total_stores,
    active_stores,
    total_revenue,
    total_transactions,
    avg_transaction_value,
    revenue_growth_mom,
    revenue_growth_yoy,
    top_region,
    top_city,
    top_product
FROM iceberg.platinum.executive_summary
WHERE reporting_date >= CURRENT_DATE - INTERVAL '90' DAY
ORDER BY reporting_date DESC
"""
    },
    {
        "database": db_id,
        "table_name": "platinum_regional_performance",
        "schema": "platinum",
        "sql": """
SELECT 
    region,
    province,
    city,
    barangay,
    store_count,
    total_revenue,
    total_transactions,
    avg_basket_size,
    top_categories,
    market_share
FROM iceberg.platinum.regional_performance
WHERE last_updated >= CURRENT_DATE - INTERVAL '7' DAY
"""
    },
    {
        "database": db_id,
        "table_name": "gold_customer_segments",
        "schema": "gold",
        "sql": """
SELECT 
    segment_name,
    segment_size,
    avg_frequency,
    avg_monetary_value,
    avg_recency_days,
    growth_rate,
    churn_risk,
    segment_characteristics
FROM iceberg.gold.customer_segments
WHERE analysis_date = (SELECT MAX(analysis_date) FROM iceberg.gold.customer_segments)
"""
    },
    {
        "database": db_id,
        "table_name": "gold_forecasts",
        "schema": "gold",
        "sql": """
SELECT 
    forecast_date,
    region,
    city,
    predicted_revenue,
    confidence_lower,
    confidence_upper,
    seasonality_factor,
    trend_component
FROM iceberg.gold.revenue_forecasts
WHERE forecast_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30' DAY
ORDER BY forecast_date
"""
    }
]

dataset_ids = []
for ds in datasets:
    resp = requests.post(f"{api_url}/dataset/", json=ds, headers=headers)
    if resp.status_code == 201:
        dataset_ids.append(resp.json()["id"])
        print(f"✓ Created Trino dataset: {ds['table_name']}")
    else:
        print(f"WARNING: Dataset {ds['table_name']} may already exist")

print(f"✓ Created {len(dataset_ids)} Trino datasets")

# Create advanced charts for lakehouse data
charts = [
    {
        "slice_name": "Executive KPI Summary",
        "viz_type": "big_number_total",
        "datasource_id": dataset_ids[0] if dataset_ids else 1,
        "datasource_type": "table",
        "params": json.dumps({
            "metric": {
                "expressionType": "SIMPLE",
                "column": {"column_name": "total_revenue"},
                "aggregate": "SUM",
                "label": "Total Revenue"
            },
            "subheader": "Last 30 days",
            "time_range": "Last 30 days",
            "y_axis_format": ",.2f"
        })
    },
    {
        "slice_name": "Regional Revenue Heatmap",
        "viz_type": "heatmap",
        "datasource_id": dataset_ids[1] if len(dataset_ids) > 1 else 1,
        "datasource_type": "table",
        "params": json.dumps({
            "all_columns_x": "city",
            "all_columns_y": "region",
            "metric": {
                "expressionType": "SIMPLE",
                "column": {"column_name": "total_revenue"},
                "aggregate": "SUM"
            },
            "linear_color_scheme": "blue_white_yellow",
            "xscale_interval": 1,
            "yscale_interval": 1,
            "canvas_image_rendering": "pixelated",
            "normalize_across": "heatmap"
        })
    },
    {
        "slice_name": "Customer Segment Analysis",
        "viz_type": "sunburst",
        "datasource_id": dataset_ids[2] if len(dataset_ids) > 2 else 1,
        "datasource_type": "table",
        "params": json.dumps({
            "groupby": ["segment_name"],
            "metric": {
                "expressionType": "SIMPLE",
                "column": {"column_name": "segment_size"},
                "aggregate": "SUM"
            },
            "secondary_metric": {
                "expressionType": "SIMPLE",
                "column": {"column_name": "avg_monetary_value"},
                "aggregate": "AVG"
            }
        })
    },
    {
        "slice_name": "Revenue Forecast",
        "viz_type": "line",
        "datasource_id": dataset_ids[3] if len(dataset_ids) > 3 else 1,
        "datasource_type": "table",
        "params": json.dumps({
            "metrics": [
                {"expressionType": "SIMPLE", "column": {"column_name": "predicted_revenue"}, "aggregate": "SUM"},
                {"expressionType": "SIMPLE", "column": {"column_name": "confidence_lower"}, "aggregate": "SUM"},
                {"expressionType": "SIMPLE", "column": {"column_name": "confidence_upper"}, "aggregate": "SUM"}
            ],
            "groupby": ["forecast_date"],
            "timeseries_limit_metric": {
                "expressionType": "SIMPLE",
                "column": {"column_name": "forecast_date"},
                "aggregate": "MAX"
            },
            "line_interpolation": "linear",
            "show_legend": True,
            "x_axis_label": "Date",
            "y_axis_label": "Revenue (₱)",
            "rich_tooltip": True
        })
    }
]

chart_ids = []
for chart in charts:
    resp = requests.post(f"{api_url}/chart/", json=chart, headers=headers)
    if resp.status_code == 201:
        chart_ids.append(resp.json()["id"])
        print(f"✓ Created chart: {chart['slice_name']}")

# Create executive dashboard
dashboard = {
    "dashboard_title": "Scout Lakehouse Analytics",
    "slug": "scout-lakehouse",
    "published": True,
    "position_json": json.dumps({
        "DASHBOARD_VERSION_KEY": "v2",
        "GRID_ID": {
            "id": "GRID_ID",
            "children": ["ROW-1", "ROW-2", "ROW-3", "ROW-4"]
        },
        "HEADER_ID": {
            "id": "HEADER_ID",
            "meta": {"text": "Scout Lakehouse Analytics - Executive View"}
        },
        "ROOT_ID": {"children": ["GRID_ID"], "id": "ROOT_ID", "type": "ROOT"},
        "ROW-1": {
            "id": "ROW-1",
            "children": ["CHART-1"],
            "meta": {"background": "BACKGROUND_TRANSPARENT"}
        },
        "ROW-2": {
            "id": "ROW-2",
            "children": ["CHART-2"],
            "meta": {"background": "BACKGROUND_TRANSPARENT"}
        },
        "ROW-3": {
            "id": "ROW-3",
            "children": ["CHART-3"],
            "meta": {"background": "BACKGROUND_TRANSPARENT"}
        },
        "ROW-4": {
            "id": "ROW-4",
            "children": ["CHART-4"],
            "meta": {"background": "BACKGROUND_TRANSPARENT"}
        }
    }),
    "metadata": {
        "native_filter_configuration": [
            {
                "id": "NATIVE_FILTER-1",
                "name": "Region",
                "filterType": "filter_select",
                "targets": [{"datasetId": dataset_ids[1] if len(dataset_ids) > 1 else 1}],
                "defaultDataMask": {"filterState": {"value": []}},
                "cascadeParentIds": [],
                "scope": {"rootPath": ["ROOT_ID"], "excluded": []},
                "inverseSelection": False,
                "controlValues": {
                    "multiSelect": True,
                    "searchAllOptions": False,
                    "enableEmptyFilter": False
                }
            }
        ],
        "refresh_frequency": 3600,  # Refresh every hour
        "color_scheme": "supersetColors",
        "label_colors": {}
    }
}

resp = requests.post(f"{api_url}/dashboard/", json=dashboard, headers=headers)
if resp.status_code == 201:
    print("✓ Created dashboard: Scout Lakehouse Analytics")
    dashboard_id = resp.json()["id"]
    
    # Add charts to dashboard
    for i, chart_id in enumerate(chart_ids):
        requests.post(f"{api_url}/dashboard/{dashboard_id}/charts", 
                     json={"slice_id": chart_id}, 
                     headers=headers)
    print(f"✓ Added {len(chart_ids)} charts to lakehouse dashboard")
else:
    print(f"WARNING: Dashboard creation failed: {resp.text}")

# Create a complex multi-source dashboard combining Supabase and Trino
print("\nCreating unified dashboard with both data sources...")

# Get Supabase database ID
resp = requests.get(f"{api_url}/database/?q=(filters:!((col:database_name,opr:eq,value:'Scout Supabase')))", headers=headers)
supabase_db_id = resp.json()["result"][0]["id"] if resp.json()["result"] else None

if supabase_db_id and db_id:
    # Create a virtual dataset joining real-time and historical data
    virtual_dataset = {
        "database": db_id,
        "table_name": "unified_scout_view",
        "schema": "",
        "sql": """
WITH real_time AS (
    SELECT 
        CAST(date_day AS DATE) as reporting_date,
        SUM(total_sales) as realtime_revenue,
        SUM(total_transactions) as realtime_transactions
    FROM scout.gold_daily_aggregates
    WHERE date_day >= CURRENT_DATE - INTERVAL '7' DAY
    GROUP BY date_day
),
historical AS (
    SELECT 
        reporting_date,
        total_revenue as historical_revenue,
        total_transactions as historical_transactions,
        revenue_growth_mom,
        revenue_growth_yoy
    FROM iceberg.platinum.executive_summary
    WHERE reporting_date >= CURRENT_DATE - INTERVAL '90' DAY
)
SELECT 
    COALESCE(r.reporting_date, h.reporting_date) as date,
    COALESCE(r.realtime_revenue, h.historical_revenue) as revenue,
    COALESCE(r.realtime_transactions, h.historical_transactions) as transactions,
    h.revenue_growth_mom,
    h.revenue_growth_yoy,
    CASE 
        WHEN r.reporting_date IS NOT NULL THEN 'Real-time'
        ELSE 'Historical'
    END as data_source
FROM real_time r
FULL OUTER JOIN historical h ON r.reporting_date = h.reporting_date
ORDER BY date DESC
"""
    }
    
    resp = requests.post(f"{api_url}/dataset/", json=virtual_dataset, headers=headers)
    if resp.status_code == 201:
        print("✓ Created unified virtual dataset")

print("\n✓ Trino lakehouse import completed successfully!")
print(f"Access dashboards at: ${SUPERSET_URL}")
print("  - Scout Analytics Dashboard (real-time)")
print("  - Scout Lakehouse Analytics (historical/ML)")
print("")
print("Lakehouse features available:")
print("  - Iceberg time travel queries")
print("  - Partitioned data for performance")
print("  - ML-ready aggregations")
print("  - Cross-schema federated queries")
EOF
fi

echo -e "${GREEN}✓ Trino import completed${NC}"
echo ""
echo "To test Trino connectivity:"
echo "  kubectl port-forward -n aaas svc/trino 8080:8080"
echo "  Then access Trino UI at http://localhost:8080"