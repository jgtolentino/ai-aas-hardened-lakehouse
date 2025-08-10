slice_name: "World's Pop Growth (Supabase)"
viz_type: "line"
datasource:
  dataset_name: "${WORLD_BANK_TABLE}"
  schema: "${WORLD_BANK_SCHEMA}"
  database: { database_name: "${SUPABASE_DB_NAME}" }
params:
  color_scheme: "supersetBrand10"
  x_axis: "year"
  metrics: ["total_population"]
  groupby: ["country_name"]
  time_range: "No filter"
cache_timeout: 300
