-- Register initial Code Connect components
-- Run this after the design_system_analytics migration

-- Register KPI Tile component
INSERT INTO design_analytics.components (
  component_id,
  component_name,
  component_type,
  library_name,
  library_version,
  figma_key,
  figma_node_id,
  code_connect_path,
  react_component_path,
  description,
  tags
) VALUES (
  'kpi-tile',
  'KPI Tile',
  'atom',
  'scout-ui',
  '1.0.0',
  'xyz123scout789',
  '45:67',
  'apps/scout-ui/src/components/Kpi/KpiTile.figma.tsx',
  'apps/scout-ui/src/components/Kpi/KpiTile.tsx',
  'Key performance indicator display component with delta comparison',
  ARRAY['kpi', 'metric', 'dashboard', 'analytics']
)
ON CONFLICT (component_id) DO NOTHING;

-- Register Data Table component
INSERT INTO design_analytics.components (
  component_id,
  component_name,
  component_type,
  library_name,
  library_version,
  figma_key,
  figma_node_id,
  code_connect_path,
  react_component_path,
  description,
  tags
) VALUES (
  'data-table',
  'Data Table',
  'organism',
  'scout-ui',
  '1.0.0',
  'xyz123scout789',
  '78:91',
  'apps/scout-ui/src/components/DataTable/DataTable.figma.tsx',
  'apps/scout-ui/src/components/DataTable/DataTable.tsx',
  'Sortable, searchable data table with pagination',
  ARRAY['table', 'data', 'list', 'pagination']
)
ON CONFLICT (component_id) DO NOTHING;

-- Register Chart Card component
INSERT INTO design_analytics.components (
  component_id,
  component_name,
  component_type,
  library_name,
  library_version,
  figma_key,
  figma_node_id,
  code_connect_path,
  react_component_path,
  description,
  tags
) VALUES (
  'chart-card',
  'Chart Card',
  'molecule',
  'scout-ui',
  '1.0.0',
  'xyz123scout789',
  '56:78',
  'apps/scout-ui/src/components/ChartCard/ChartCard.figma.tsx',
  'apps/scout-ui/src/components/ChartCard/ChartCard.tsx',
  'Container for various chart types with loading and error states',
  ARRAY['chart', 'visualization', 'card', 'container']
)
ON CONFLICT (component_id) DO NOTHING;

-- Register Filter Panel component
INSERT INTO design_analytics.components (
  component_id,
  component_name,
  component_type,
  library_name,
  library_version,
  figma_key,
  figma_node_id,
  code_connect_path,
  react_component_path,
  description,
  tags
) VALUES (
  'filter-panel',
  'Filter Panel',
  'organism',
  'scout-ui',
  '1.0.0',
  'xyz123scout789',
  '156:189',
  'apps/scout-ui/src/components/FilterPanel/FilterPanel.figma.tsx',
  'apps/scout-ui/src/components/FilterPanel/FilterPanel.tsx',
  'Collapsible panel for dashboard filtering with multiple filter types',
  ARRAY['filter', 'panel', 'controls', 'search']
)
ON CONFLICT (component_id) DO NOTHING;

-- Add some mock usage data for demonstration
INSERT INTO design_analytics.usage_logs (
  team_id,
  user_id, 
  component_id,
  component_name,
  action,
  platform,
  file_id,
  file_name,
  context,
  created_at
) VALUES 
-- KPI Tile usage
(gen_random_uuid(), gen_random_uuid(), 'kpi-tile', 'KPI Tile', 'insert', 'figma', 'file_001', 'Scout Dashboard', '{"position": {"x": 100, "y": 200}}', NOW() - INTERVAL '1 day'),
(gen_random_uuid(), gen_random_uuid(), 'kpi-tile', 'KPI Tile', 'insert', 'figma', 'file_002', 'Executive Dashboard', '{"position": {"x": 50, "y": 100}}', NOW() - INTERVAL '2 days'),
(gen_random_uuid(), gen_random_uuid(), 'kpi-tile', 'KPI Tile', 'detach', 'figma', 'file_003', 'Analytics View', '{"reason": "custom styling needed"}', NOW() - INTERVAL '3 days'),

-- Data Table usage
(gen_random_uuid(), gen_random_uuid(), 'data-table', 'Data Table', 'insert', 'code', NULL, 'UserList.tsx', '{"props": {"pagination": true}}', NOW() - INTERVAL '1 day'),
(gen_random_uuid(), gen_random_uuid(), 'data-table', 'Data Table', 'override', 'figma', 'file_004', 'Customer Dashboard', '{"overrides": ["columns", "sorting"]}', NOW() - INTERVAL '4 days'),

-- Chart Card usage  
(gen_random_uuid(), gen_random_uuid(), 'chart-card', 'Chart Card', 'insert', 'figma', 'file_005', 'Revenue Dashboard', '{"chartType": "line"}', NOW() - INTERVAL '2 days'),
(gen_random_uuid(), gen_random_uuid(), 'chart-card', 'Chart Card', 'detach', 'figma', 'file_006', 'Sales Analytics', '{"reason": "needed custom chart"}', NOW() - INTERVAL '5 days'),
(gen_random_uuid(), gen_random_uuid(), 'chart-card', 'Chart Card', 'detach', 'figma', 'file_007', 'Marketing Dashboard', '{"reason": "styling conflicts"}', NOW() - INTERVAL '6 days'),

-- Filter Panel usage
(gen_random_uuid(), gen_random_uuid(), 'filter-panel', 'Filter Panel', 'insert', 'figma', 'file_008', 'Search Interface', '{"filters": ["date", "category"]}', NOW() - INTERVAL '1 day'),
(gen_random_uuid(), gen_random_uuid(), 'filter-panel', 'Filter Panel', 'create', 'figma', 'file_009', 'Product Catalog', '{"variant": "compact"}', NOW() - INTERVAL '7 days');

-- Initial refresh of materialized view
REFRESH MATERIALIZED VIEW design_analytics.component_stats;

-- Verify the setup
SELECT 
  component_name,
  total_usage,
  detachment_rate,
  trend
FROM design_analytics.component_stats
ORDER BY total_usage DESC;