-- Design System Analytics Schema
-- Track component usage, detachments, and design system health

-- Create design analytics schema
CREATE SCHEMA IF NOT EXISTS design_analytics;

-- Design usage logs table
CREATE TABLE design_analytics.usage_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID REFERENCES auth.users(id),
  user_id UUID REFERENCES auth.users(id),
  component_id TEXT NOT NULL,
  component_name TEXT NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('insert', 'detach', 'override', 'create', 'rename', 'place', 'modify')),
  platform TEXT NOT NULL DEFAULT 'figma' CHECK (platform IN ('web', 'mobile', 'figma', 'figjam', 'code')),
  file_id TEXT,
  file_name TEXT,
  context JSONB DEFAULT '{}',
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Indexes for fast queries
  INDEX idx_usage_logs_component (component_id),
  INDEX idx_usage_logs_team (team_id),
  INDEX idx_usage_logs_created (created_at),
  INDEX idx_usage_logs_action (action),
  INDEX idx_usage_logs_platform (platform)
);

-- Component registry table
CREATE TABLE design_analytics.components (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  component_id TEXT UNIQUE NOT NULL,
  component_name TEXT NOT NULL,
  component_type TEXT NOT NULL CHECK (component_type IN ('atom', 'molecule', 'organism', 'template', 'page')),
  library_name TEXT,
  library_version TEXT,
  figma_key TEXT,
  figma_node_id TEXT,
  code_connect_path TEXT,
  react_component_path TEXT,
  description TEXT,
  tags TEXT[] DEFAULT '{}',
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'deprecated', 'experimental', 'archived')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Indexes
  INDEX idx_components_name (component_name),
  INDEX idx_components_type (component_type),
  INDEX idx_components_status (status),
  INDEX idx_components_library (library_name)
);

-- Component usage statistics (materialized view for performance)
CREATE MATERIALIZED VIEW design_analytics.component_stats AS
SELECT 
  c.component_id,
  c.component_name,
  c.component_type,
  c.library_name,
  c.status,
  
  -- Usage metrics
  COUNT(ul.id) AS total_usage,
  COUNT(DISTINCT ul.team_id) AS teams_using,
  COUNT(DISTINCT ul.file_id) AS files_using,
  COUNT(DISTINCT ul.user_id) AS users_using,
  
  -- Action breakdowns
  COUNT(ul.id) FILTER (WHERE ul.action = 'insert') AS insertions,
  COUNT(ul.id) FILTER (WHERE ul.action = 'detach') AS detachments,
  COUNT(ul.id) FILTER (WHERE ul.action = 'override') AS overrides,
  
  -- Calculate detachment rate
  CASE 
    WHEN COUNT(ul.id) FILTER (WHERE ul.action = 'insert') > 0 
    THEN (COUNT(ul.id) FILTER (WHERE ul.action = 'detach')::FLOAT / COUNT(ul.id) FILTER (WHERE ul.action = 'insert')) * 100
    ELSE 0 
  END AS detachment_rate,
  
  -- Platform usage
  COUNT(ul.id) FILTER (WHERE ul.platform = 'figma') AS figma_usage,
  COUNT(ul.id) FILTER (WHERE ul.platform = 'code') AS code_usage,
  COUNT(ul.id) FILTER (WHERE ul.platform = 'web') AS web_usage,
  
  -- Time metrics
  MAX(ul.created_at) AS last_used,
  MIN(ul.created_at) AS first_used,
  
  -- Trend calculation (last 30 days vs previous 30 days)
  CASE 
    WHEN COUNT(ul.id) FILTER (WHERE ul.created_at > NOW() - INTERVAL '30 days') > 
         COUNT(ul.id) FILTER (WHERE ul.created_at BETWEEN NOW() - INTERVAL '60 days' AND NOW() - INTERVAL '30 days')
    THEN 'up'
    WHEN COUNT(ul.id) FILTER (WHERE ul.created_at > NOW() - INTERVAL '30 days') < 
         COUNT(ul.id) FILTER (WHERE ul.created_at BETWEEN NOW() - INTERVAL '60 days' AND NOW() - INTERVAL '30 days')
    THEN 'down'
    ELSE 'stable'
  END AS trend

FROM design_analytics.components c
LEFT JOIN design_analytics.usage_logs ul ON c.component_id = ul.component_id
GROUP BY c.component_id, c.component_name, c.component_type, c.library_name, c.status;

-- Create index on materialized view
CREATE INDEX idx_component_stats_usage ON design_analytics.component_stats (total_usage DESC);
CREATE INDEX idx_component_stats_detachment ON design_analytics.component_stats (detachment_rate DESC);
CREATE INDEX idx_component_stats_trend ON design_analytics.component_stats (trend);

-- Team analytics view
CREATE VIEW design_analytics.team_stats AS
SELECT 
  ul.team_id,
  u.email as team_email,
  COUNT(DISTINCT ul.component_id) AS unique_components_used,
  COUNT(ul.id) AS total_component_usage,
  COUNT(ul.id) FILTER (WHERE ul.action = 'detach') AS total_detachments,
  COUNT(DISTINCT ul.file_id) AS files_with_components,
  
  -- Calculate team's detachment rate
  CASE 
    WHEN COUNT(ul.id) FILTER (WHERE ul.action = 'insert') > 0 
    THEN (COUNT(ul.id) FILTER (WHERE ul.action = 'detach')::FLOAT / COUNT(ul.id) FILTER (WHERE ul.action = 'insert')) * 100
    ELSE 0 
  END AS team_detachment_rate,
  
  -- Most used components by team
  array_agg(DISTINCT ul.component_name ORDER BY COUNT(ul.id) DESC) AS top_components,
  
  MAX(ul.created_at) AS last_activity,
  COUNT(ul.id) FILTER (WHERE ul.created_at > NOW() - INTERVAL '7 days') AS usage_last_7_days,
  COUNT(ul.id) FILTER (WHERE ul.created_at > NOW() - INTERVAL '30 days') AS usage_last_30_days

FROM design_analytics.usage_logs ul
LEFT JOIN auth.users u ON ul.team_id = u.id
GROUP BY ul.team_id, u.email;

-- Library health metrics
CREATE VIEW design_analytics.library_health AS
SELECT 
  c.library_name,
  c.library_version,
  COUNT(c.id) AS total_components,
  COUNT(c.id) FILTER (WHERE c.status = 'active') AS active_components,
  COUNT(c.id) FILTER (WHERE c.status = 'deprecated') AS deprecated_components,
  COUNT(c.id) FILTER (WHERE c.status = 'experimental') AS experimental_components,
  
  -- Usage metrics
  AVG(cs.total_usage) AS avg_component_usage,
  AVG(cs.detachment_rate) AS avg_detachment_rate,
  COUNT(cs.component_id) FILTER (WHERE cs.total_usage = 0) AS unused_components,
  
  -- Adoption metrics
  COUNT(DISTINCT cs.component_id) FILTER (WHERE cs.teams_using > 0) AS adopted_components,
  AVG(cs.teams_using) AS avg_teams_per_component,
  
  -- Health score (0-100)
  LEAST(100, GREATEST(0,
    (COUNT(c.id) FILTER (WHERE c.status = 'active')::FLOAT / GREATEST(COUNT(c.id), 1)) * 30 +
    (1 - (COUNT(cs.component_id) FILTER (WHERE cs.total_usage = 0)::FLOAT / GREATEST(COUNT(c.id), 1))) * 30 +
    LEAST(1, AVG(cs.teams_using) / 3.0) * 20 +
    (1 - LEAST(1, AVG(cs.detachment_rate) / 20.0)) * 20
  )) AS health_score

FROM design_analytics.components c
LEFT JOIN design_analytics.component_stats cs ON c.component_id = cs.component_id
GROUP BY c.library_name, c.library_version;

-- Design insights (AI-ready analytics)
CREATE VIEW design_analytics.insights AS
WITH component_insights AS (
  SELECT 
    cs.*,
    CASE 
      WHEN cs.detachment_rate > 20 AND cs.total_usage > 10 THEN 'high_detachment'
      WHEN cs.total_usage = 0 AND cs.first_used IS NOT NULL THEN 'unused'
      WHEN cs.trend = 'down' AND cs.total_usage > 0 THEN 'declining'
      WHEN cs.teams_using = 1 AND cs.total_usage > 5 THEN 'single_team'
      WHEN cs.overrides > cs.insertions * 0.3 THEN 'frequently_overridden'
      ELSE 'healthy'
    END AS insight_type,
    
    CASE 
      WHEN cs.detachment_rate > 20 AND cs.total_usage > 10 
        THEN 'Component has high detachment rate (' || ROUND(cs.detachment_rate, 1) || '%). Consider updating default props or creating variants.'
      WHEN cs.total_usage = 0 AND cs.first_used IS NOT NULL 
        THEN 'Component was created but never used. Consider removing or promoting it.'
      WHEN cs.trend = 'down' AND cs.total_usage > 0 
        THEN 'Component usage is declining. Check if it needs updates or if teams are switching to alternatives.'
      WHEN cs.teams_using = 1 AND cs.total_usage > 5 
        THEN 'Component is only used by one team but heavily used. Consider promoting to other teams.'
      WHEN cs.overrides > cs.insertions * 0.3 
        THEN 'Component is frequently overridden. Consider adding more variant options.'
      ELSE 'Component is healthy and well-adopted.'
    END AS insight_message,
    
    CASE 
      WHEN cs.detachment_rate > 20 AND cs.total_usage > 10 THEN 'high'
      WHEN cs.total_usage = 0 AND cs.first_used IS NOT NULL THEN 'medium'
      WHEN cs.trend = 'down' AND cs.total_usage > 0 THEN 'medium'
      WHEN cs.teams_using = 1 AND cs.total_usage > 5 THEN 'low'
      WHEN cs.overrides > cs.insertions * 0.3 THEN 'medium'
      ELSE 'info'
    END AS insight_priority

  FROM design_analytics.component_stats cs
)

SELECT * FROM component_insights
WHERE insight_type != 'healthy'
ORDER BY 
  CASE insight_priority 
    WHEN 'high' THEN 1 
    WHEN 'medium' THEN 2 
    WHEN 'low' THEN 3 
    ELSE 4 
  END,
  total_usage DESC;

-- Row Level Security policies
ALTER TABLE design_analytics.usage_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE design_analytics.components ENABLE ROW LEVEL SECURITY;

-- Allow team members to see their own team's usage logs
CREATE POLICY "Team usage logs access" ON design_analytics.usage_logs
  FOR ALL USING (
    auth.uid() = team_id OR 
    auth.jwt() ->> 'role' IN ('admin', 'design_lead')
  );

-- Allow authenticated users to read component registry
CREATE POLICY "Component registry read access" ON design_analytics.components
  FOR SELECT USING (auth.role() = 'authenticated');

-- Allow design leads to manage components
CREATE POLICY "Component registry write access" ON design_analytics.components
  FOR ALL USING (auth.jwt() ->> 'role' IN ('admin', 'design_lead'));

-- Functions for logging usage
CREATE OR REPLACE FUNCTION design_analytics.log_component_usage(
  p_component_id TEXT,
  p_component_name TEXT,
  p_action TEXT,
  p_platform TEXT DEFAULT 'figma',
  p_file_id TEXT DEFAULT NULL,
  p_file_name TEXT DEFAULT NULL,
  p_context JSONB DEFAULT '{}',
  p_metadata JSONB DEFAULT '{}'
) RETURNS UUID AS $$
DECLARE
  log_id UUID;
BEGIN
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
    metadata
  ) VALUES (
    auth.uid(),
    auth.uid(),
    p_component_id,
    p_component_name,
    p_action,
    p_platform,
    p_file_id,
    p_file_name,
    p_context,
    p_metadata
  ) RETURNING id INTO log_id;
  
  RETURN log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to refresh component stats
CREATE OR REPLACE FUNCTION design_analytics.refresh_component_stats()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW design_analytics.component_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to register a new component
CREATE OR REPLACE FUNCTION design_analytics.register_component(
  p_component_id TEXT,
  p_component_name TEXT,
  p_component_type TEXT,
  p_library_name TEXT DEFAULT 'scout-ui',
  p_library_version TEXT DEFAULT '1.0.0',
  p_figma_key TEXT DEFAULT NULL,
  p_figma_node_id TEXT DEFAULT NULL,
  p_code_connect_path TEXT DEFAULT NULL,
  p_react_component_path TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_tags TEXT[] DEFAULT '{}'
) RETURNS UUID AS $$
DECLARE
  component_uuid UUID;
BEGIN
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
    p_component_id,
    p_component_name,
    p_component_type,
    p_library_name,
    p_library_version,
    p_figma_key,
    p_figma_node_id,
    p_code_connect_path,
    p_react_component_path,
    p_description,
    p_tags
  ) 
  ON CONFLICT (component_id) 
  DO UPDATE SET 
    component_name = EXCLUDED.component_name,
    component_type = EXCLUDED.component_type,
    library_version = EXCLUDED.library_version,
    figma_key = EXCLUDED.figma_key,
    figma_node_id = EXCLUDED.figma_node_id,
    code_connect_path = EXCLUDED.code_connect_path,
    react_component_path = EXCLUDED.react_component_path,
    description = EXCLUDED.description,
    tags = EXCLUDED.tags,
    updated_at = NOW()
  RETURNING id INTO component_uuid;
  
  RETURN component_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create scheduled job to refresh stats every hour
SELECT cron.schedule('refresh-component-stats', '0 * * * *', 'SELECT design_analytics.refresh_component_stats();');

-- Insert initial component data for existing Code Connect components
SELECT design_analytics.register_component(
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
);

SELECT design_analytics.register_component(
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
);

SELECT design_analytics.register_component(
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
);

SELECT design_analytics.register_component(
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
);

-- Initial refresh of stats
SELECT design_analytics.refresh_component_stats();