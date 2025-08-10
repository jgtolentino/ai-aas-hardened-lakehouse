dashboard_title: "Scout Analytics - Geographic Dashboard (Cloud)"
description: "Geographic visualization of Scout Analytics data with choropleth maps"
position:
  ROOT_ID: { id: "ROOT_ID", type: "ROOT", children: ["GRID_ID"] }
  GRID_ID: { id: "GRID_ID", type: "GRID", children: ["HEADER-1", "ROW-1", "ROW-2"] }
  HEADER-1: 
    id: "HEADER-1"
    type: "HEADER"
    meta:
      text: "Scout Analytics - Geographic Sales Distribution"
      background: "BACKGROUND_TRANSPARENT"
  ROW-1:   
    id: "ROW-1"  
    type: "ROW"  
    children: ["CHART-1"]
    meta:
      background: "BACKGROUND_TRANSPARENT"
  ROW-2:
    id: "ROW-2"
    type: "ROW"
    children: ["CHART-2"]
    meta:
      background: "BACKGROUND_TRANSPARENT"
  CHART-1: 
    id: "CHART-1"
    type: "CHART"
    meta: 
      chartId: "__RESOLVE_AT_IMPORT__"
      width: 12
      height: 8
  CHART-2:
    id: "CHART-2" 
    type: "CHART"
    meta:
      chartId: "__RESOLVE_AT_IMPORT_2__"
      width: 12
      height: 4

charts:
  - slice_name: "Philippines Regional Sales Heatmap (Cloud)"
  - slice_name: "World's Pop Growth (Supabase)"

datasets:
  - table_name: "gold_region_choropleth"
    schema: "scout" 
    database: { database_name: "${SUPABASE_DB_NAME}" }
  - table_name: "${WORLD_BANK_TABLE}"
    schema: "${WORLD_BANK_SCHEMA}"
    database: { database_name: "${SUPABASE_DB_NAME}" }

# Filters applied to dashboard
default_filters: {}

# Dashboard metadata
metadata:
  color_scheme: "supersetColors"
  label_colors: {}
  shared_label_colors: {}
  color_scheme_domain: []