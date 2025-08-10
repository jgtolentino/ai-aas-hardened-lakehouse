table_name: "gold_region_choropleth"
schema: "scout"
database: { database_name: "${SUPABASE_DB_NAME}" }
is_sqllab_view: false
description: "Regional sales metrics with geographic boundaries for choropleth visualization"
columns:
  - column_name: region_key
    verbose_name: Region Key
    type: TEXT
    groupby: true
    filterable: true
  - column_name: region_name
    verbose_name: Region Name
    type: TEXT
    groupby: true
    filterable: true
  - column_name: day
    verbose_name: Date
    is_dttm: true
    type: TIMESTAMP
    python_date_format: "%Y-%m-%d"
  - column_name: peso_total
    verbose_name: Total Sales (₱)
    type: NUMERIC
    metric: true
    d3format: ",.2f"
  - column_name: txn_count
    verbose_name: Transaction Count
    type: BIGINT
    metric: true
  - column_name: geom
    verbose_name: Geometry
    is_spatial: true
    type: GEOMETRY
  # Virtual column for Deck.gl GeoJSON visualization
  - column_name: geojson
    verbose_name: GeoJSON
    type: TEXT
    expression: "ST_AsGeoJSON(geom)"
    is_dttm: false
metrics:
  - metric_name: sum_peso_total
    expression: "SUM(peso_total)"
    metric_type: sum
    verbose_name: "Total Sales (₱)"
    d3format: ",.2f"
  - metric_name: sum_txn_count
    expression: "SUM(txn_count)"
    metric_type: sum
    verbose_name: "Total Transactions"
    d3format: ",.0f"
  - metric_name: avg_ticket_size
    expression: "NULLIF(SUM(peso_total),0)/NULLIF(SUM(txn_count),0)"
    metric_type: avg
    verbose_name: "Average Ticket Size (₱)"
    d3format: ",.2f"