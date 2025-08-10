slice_name: "Philippines Regional Sales Heatmap (Cloud)"
viz_type: "deck_geojson"
datasource:
  dataset_name: "gold_region_choropleth"
  schema: "scout"
  database: { database_name: "${SUPABASE_DB_NAME}" }
description: "Geographic distribution of sales across Philippine regions with Mapbox base tiles"
params:
  viz_type: "deck_geojson"
  time_range: "Last 30 days"
  time_grain_sqla: "P1D"
  metrics:
    - "sum_peso_total"
  adhoc_filters: []
  groupby: []
  row_limit: 50000
  
  # Deck.gl specific parameters
  geojson: "geojson"
  
  # Map configuration
  autozoom: true
  
  # Viewport centered on Philippines
  viewport:
    longitude: 122.0
    latitude: 12.5
    zoom: 5.5
    bearing: 0
    pitch: 0
    
  # Visual styling
  fill_color_picker:
    r: 0
    g: 122
    b: 135
    a: 1
    
  stroke_color_picker:
    r: 0
    g: 0
    b: 0
    a: 1
    
  filled: true
  stroked: true
  extruded: false
  
  line_width: 10
  line_width_unit: "pixels"
  
  opacity: 0.8
  
  # Color mapping based on metric
  color_scheme: "reds"
  
  # Legend configuration
  legend_position: "tr"
  legend_format: ",.0f"
  
  # Tooltip configuration
  rich_tooltip: true
  tooltip:
    - "region_name"
    - "sum_peso_total"
    - "sum_txn_count"
    - "avg_ticket_size"
    
  # JS data columns for interactivity
  js_columns:
    - "region_key"
    - "region_name"
    
  # Map style (requires Mapbox token in environment)
  mapbox_style: "mapbox://styles/mapbox/light-v10"
    
cache_timeout: 300