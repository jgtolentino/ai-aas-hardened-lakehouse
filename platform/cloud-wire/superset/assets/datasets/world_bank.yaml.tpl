table_name: "${WORLD_BANK_TABLE}"
schema: "${WORLD_BANK_SCHEMA}"
database: { database_name: "${SUPABASE_DB_NAME}" }
is_sqllab_view: false
columns:
  - column_name: country_name
  - column_name: country_code
  - column_name: year
    is_dttm: true
  - column_name: population
metrics:
  - metric_name: total_population
    expression: "SUM(population)"
    metric_type: numeric
