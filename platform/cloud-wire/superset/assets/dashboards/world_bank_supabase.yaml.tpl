dashboard_title: "World Bank's Data (Supabase)"
position:
  ROOT_ID: { id: "ROOT_ID", type: "ROOT", children: ["GRID_ID"] }
  GRID_ID: { id: "GRID_ID", type: "GRID", children: ["ROW-1"] }
  ROW-1:   { id: "ROW-1",  type: "ROW",  children: ["CHART-1"] }
  CHART-1: { id: "CHART-1", type: "CHART", meta: { chartId: "__RESOLVE_AT_IMPORT__" } }
charts:
  - { slice_name: "World's Pop Growth (Supabase)" }
datasets:
  - { table_name: "${WORLD_BANK_TABLE}", schema: "${WORLD_BANK_SCHEMA}", database: { database_name: "${SUPABASE_DB_NAME}" } }
