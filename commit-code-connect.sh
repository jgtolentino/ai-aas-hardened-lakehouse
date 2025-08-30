#!/bin/bash

# Scout Dashboard Code Connect Implementation
# Direct execution with GitHub MCP and Supabase integration

set -e

echo "🚀 Scout Dashboard Code Connect Implementation"
echo "============================================="

# Navigate to backend repo
cd /Users/tbwa/ai-aas-hardened-lakehouse

# 1. Execute Supabase migrations for scout schema
echo "📊 Applying Scout schema migrations..."
cat << 'EOF' > supabase/migrations/$(date +%Y%m%d%H%M%S)_scout_dashboard_integration.sql
-- Scout Dashboard Integration Schema
-- Code Connect metadata and component tracking

CREATE SCHEMA IF NOT EXISTS scout;

-- Component registry for Figma Code Connect
CREATE TABLE IF NOT EXISTS scout.component_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    component_name TEXT NOT NULL,
    figma_node_id TEXT NOT NULL,
    file_path TEXT NOT NULL,
    component_type TEXT CHECK (component_type IN ('layout', 'chart', 'ai', 'kpi', 'tab')),
    props JSONB DEFAULT '{}',
    variants JSONB DEFAULT '{}',
    last_synced TIMESTAMPTZ DEFAULT NOW(),
    version INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(component_name, figma_node_id)
);

-- Design tokens synchronization
CREATE TABLE IF NOT EXISTS scout.design_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token_type TEXT CHECK (token_type IN ('color', 'typography', 'spacing', 'shadow', 'border')),
    token_name TEXT NOT NULL,
    token_value JSONB NOT NULL,
    figma_reference TEXT,
    css_variable TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(token_type, token_name)
);

-- Dashboard configuration
CREATE TABLE IF NOT EXISTS scout.dashboard_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_name TEXT NOT NULL UNIQUE,
    config_data JSONB NOT NULL,
    is_active BOOLEAN DEFAULT false,
    environment TEXT CHECK (environment IN ('development', 'staging', 'production')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Code Connect sync history
CREATE TABLE IF NOT EXISTS scout.sync_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sync_type TEXT CHECK (sync_type IN ('figma', 'github', 'deployment')),
    status TEXT CHECK (status IN ('pending', 'in_progress', 'completed', 'failed')),
    details JSONB DEFAULT '{}',
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    error_message TEXT
);

-- Insert initial component registry
INSERT INTO scout.component_registry (component_name, figma_node_id, file_path, component_type, props) VALUES
('Sidebar', '66-1754', 'src/components/layout/Sidebar.tsx', 'layout', '{"activeItem": "string", "collapsed": "boolean", "theme": "enum"}'),
('KpiCard', '66-1754', 'src/components/scout/KpiCard/index.tsx', 'kpi', '{"title": "string", "value": "string", "change": "number", "state": "enum"}'),
('AnalyticsChart', '66-1770', 'src/components/charts/AnalyticsChart.tsx', 'chart', '{"type": "enum", "title": "string", "showLegend": "boolean"}'),
('RecommendationPanel', '66-1800', 'src/components/ai/RecommendationPanel.tsx', 'ai', '{"priority": "enum", "category": "enum", "expanded": "boolean"}'),
('OverviewTab', '66-1820', 'src/components/tabs/OverviewTab.tsx', 'tab', '{"period": "enum", "viewMode": "enum", "showInsights": "boolean"}')
ON CONFLICT (component_name, figma_node_id) DO UPDATE
SET 
    file_path = EXCLUDED.file_path,
    props = EXCLUDED.props,
    updated_at = NOW();

-- Insert design tokens
INSERT INTO scout.design_tokens (token_type, token_name, token_value, css_variable) VALUES
('color', 'primary', '{"hex": "#3B82F6", "rgb": "59, 130, 246"}', '--color-primary'),
('color', 'success', '{"hex": "#10B981", "rgb": "16, 185, 129"}', '--color-success'),
('color', 'warning', '{"hex": "#F59E0B", "rgb": "245, 158, 11"}', '--color-warning'),
('color', 'error', '{"hex": "#EF4444", "rgb": "239, 68, 68"}', '--color-error'),
('typography', 'heading-1', '{"size": "24px", "weight": "600", "lineHeight": "32px"}', '--font-h1'),
('spacing', 'base', '{"value": "4px"}', '--spacing-base'),
('spacing', 'sm', '{"value": "8px"}', '--spacing-sm'),
('spacing', 'md', '{"value": "16px"}', '--spacing-md'),
('spacing', 'lg', '{"value": "24px"}', '--spacing-lg'),
('spacing', 'xl', '{"value": "32px"}', '--spacing-xl')
ON CONFLICT (token_type, token_name) DO UPDATE
SET 
    token_value = EXCLUDED.token_value,
    css_variable = EXCLUDED.css_variable,
    updated_at = NOW();

-- Create RLS policies
ALTER TABLE scout.component_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.design_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.dashboard_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.sync_history ENABLE ROW LEVEL SECURITY;

-- Public read access for component registry and tokens
CREATE POLICY "Public read access" ON scout.component_registry FOR SELECT USING (true);
CREATE POLICY "Public read access" ON scout.design_tokens FOR SELECT USING (true);

-- Create indexes for performance
CREATE INDEX idx_component_registry_type ON scout.component_registry(component_type);
CREATE INDEX idx_component_registry_figma ON scout.component_registry(figma_node_id);
CREATE INDEX idx_design_tokens_type ON scout.design_tokens(token_type);
CREATE INDEX idx_sync_history_status ON scout.sync_history(status, sync_type);

-- Function to track sync status
CREATE OR REPLACE FUNCTION scout.track_sync(
    p_sync_type TEXT,
    p_status TEXT,
    p_details JSONB DEFAULT '{}'
) RETURNS UUID AS $$
DECLARE
    v_sync_id UUID;
BEGIN
    INSERT INTO scout.sync_history (sync_type, status, details)
    VALUES (p_sync_type, p_status, p_details)
    RETURNING id INTO v_sync_id;
    
    RETURN v_sync_id;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT USAGE ON SCHEMA scout TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA scout TO anon, authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA scout TO anon, authenticated;
EOF

# Apply the migration
supabase db push

# 2. Commit frontend changes
echo "💾 Committing Code Connect implementation..."
cd apps/scout-dashboard
git add -A
git commit -m "feat(scout-dashboard): implement Figma Code Connect integration

- Added Code Connect mappings for all dashboard components
- Created .figma.tsx files for Sidebar, KpiCard, Charts, AI panels
- Configured figma.config.json and code-connect.config.json
- Added deployment scripts for CI/CD pipeline
- Integrated with Scout schema in Supabase
- Documentation and setup scripts included"

# 3. Push to GitHub
echo "📤 Pushing to GitHub..."
git push origin main

# 4. Sync submodules
echo "🔄 Syncing frontend submodule..."
cd ../..
git add apps/scout-dashboard
git commit -m "chore: update scout-dashboard submodule with Code Connect"
git push origin main

# 5. Deploy Edge Functions if needed
echo "⚡ Checking Edge Functions..."
if [ -d "supabase/functions/scout-sync" ]; then
    supabase functions deploy scout-sync
fi

# 6. Verify deployment
echo "✅ Verifying deployment..."
cd apps/scout-dashboard
npm run figma:validate

echo "
========================================
✨ Code Connect Implementation Complete!
========================================

📊 Database: Scout schema created and migrated
🎨 Figma: Code Connect files ready
📦 Repository: Changes committed and pushed
🚀 Status: Ready for production deployment

Next Steps:
1. Run 'npm run figma:publish' to publish to Figma
2. Deploy to Vercel: 'vercel --prod'
3. Test in Figma Dev Mode
"
