-- Dataset Versioning and Rollback Schema
-- Provides version control and rollback capabilities for datasets

-- Create versioning schema
CREATE SCHEMA IF NOT EXISTS versioning;

-- Version status enum
CREATE TYPE versioning.version_status AS ENUM ('active', 'archived', 'deprecated', 'draft');

-- Change type enum  
CREATE TYPE versioning.change_type AS ENUM ('major', 'minor', 'patch');

-- Dataset versions table
CREATE TABLE versioning.dataset_versions (
  version_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dataset_name TEXT NOT NULL,
  version_number TEXT NOT NULL, -- Semantic versioning (e.g., "1.2.3")
  version_tag TEXT, -- Optional human-readable tag (e.g., "v1.2.3", "release-jan-2025")
  file_path TEXT NOT NULL, -- Path to the versioned file in storage
  file_size BIGINT DEFAULT 0,
  checksum TEXT, -- MD5 or SHA256 hash of the file
  schema_version TEXT DEFAULT '1.0', -- Schema version for compatibility
  created_by TEXT NOT NULL DEFAULT 'system',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  metadata JSONB DEFAULT '{}', -- Additional version metadata
  status versioning.version_status DEFAULT 'active',
  parent_version_id UUID REFERENCES versioning.dataset_versions(version_id),
  change_description TEXT, -- Description of what changed in this version
  
  -- Constraints
  UNIQUE(dataset_name, version_number),
  UNIQUE(dataset_name, version_tag) -- Ensure unique tags per dataset
);

-- Rollback status enum
CREATE TYPE versioning.rollback_status AS ENUM ('in_progress', 'success', 'failed', 'cancelled');

-- Dataset rollbacks table
CREATE TABLE versioning.dataset_rollbacks (
  rollback_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dataset_name TEXT NOT NULL,
  from_version_id UUID NOT NULL REFERENCES versioning.dataset_versions(version_id),
  to_version_id UUID NOT NULL REFERENCES versioning.dataset_versions(version_id),
  backup_version_id UUID REFERENCES versioning.dataset_versions(version_id), -- Backup of current before rollback
  reason TEXT NOT NULL, -- Why the rollback was performed
  status versioning.rollback_status DEFAULT 'in_progress',
  initiated_by TEXT NOT NULL DEFAULT 'system',
  initiated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE,
  error_message TEXT, -- Error details if rollback failed
  metadata JSONB DEFAULT '{}' -- Additional rollback metadata
);

-- Version lineage table (tracks relationships between versions)
CREATE TABLE versioning.version_lineage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dataset_name TEXT NOT NULL,
  child_version_id UUID NOT NULL REFERENCES versioning.dataset_versions(version_id),
  parent_version_id UUID NOT NULL REFERENCES versioning.dataset_versions(version_id),
  relationship_type TEXT DEFAULT 'derived_from', -- 'derived_from', 'merged_from', 'forked_from'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Version comparison results (cached comparisons)
CREATE TABLE versioning.version_comparisons (
  comparison_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version1_id UUID NOT NULL REFERENCES versioning.dataset_versions(version_id),
  version2_id UUID NOT NULL REFERENCES versioning.dataset_versions(version_id),
  comparison_result JSONB NOT NULL, -- Detailed comparison results
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(version1_id, version2_id)
);

-- Indexes for performance
CREATE INDEX idx_dataset_versions_name ON versioning.dataset_versions(dataset_name);
CREATE INDEX idx_dataset_versions_status ON versioning.dataset_versions(status);
CREATE INDEX idx_dataset_versions_created_at ON versioning.dataset_versions(created_at);
CREATE INDEX idx_dataset_versions_version_number ON versioning.dataset_versions(dataset_name, version_number);

CREATE INDEX idx_rollbacks_dataset ON versioning.dataset_rollbacks(dataset_name);
CREATE INDEX idx_rollbacks_status ON versioning.dataset_rollbacks(status);
CREATE INDEX idx_rollbacks_initiated_at ON versioning.dataset_rollbacks(initiated_at);

CREATE INDEX idx_lineage_dataset ON versioning.version_lineage(dataset_name);
CREATE INDEX idx_lineage_child ON versioning.version_lineage(child_version_id);
CREATE INDEX idx_lineage_parent ON versioning.version_lineage(parent_version_id);

-- Views for common queries

-- Current active versions
CREATE OR REPLACE VIEW versioning.current_versions AS
SELECT 
  v.*,
  -- Calculate version rank (latest = 1)
  ROW_NUMBER() OVER (PARTITION BY dataset_name ORDER BY created_at DESC) as version_rank,
  
  -- Count total versions for this dataset
  COUNT(*) OVER (PARTITION BY dataset_name) as total_versions,
  
  -- Previous version info
  LAG(version_number) OVER (PARTITION BY dataset_name ORDER BY created_at) as previous_version,
  LAG(version_id) OVER (PARTITION BY dataset_name ORDER BY created_at) as previous_version_id
  
FROM versioning.dataset_versions v
WHERE v.status = 'active';

-- Version history with lineage
CREATE OR REPLACE VIEW versioning.version_history AS
SELECT 
  v.*,
  p.version_number as parent_version_number,
  p.created_at as parent_created_at,
  
  -- Calculate days since last version
  EXTRACT(EPOCH FROM (v.created_at - p.created_at)) / 86400 as days_since_parent,
  
  -- File size change from parent
  CASE 
    WHEN p.file_size IS NOT NULL AND p.file_size > 0 
    THEN ((v.file_size - p.file_size) * 100.0 / p.file_size) 
    ELSE NULL 
  END as file_size_change_pct
  
FROM versioning.dataset_versions v
LEFT JOIN versioning.dataset_versions p ON v.parent_version_id = p.version_id
ORDER BY v.dataset_name, v.created_at DESC;

-- Rollback summary
CREATE OR REPLACE VIEW versioning.rollback_summary AS
SELECT 
  r.*,
  fv.version_number as from_version_number,
  tv.version_number as to_version_number,
  bv.version_number as backup_version_number,
  
  -- Duration of rollback
  EXTRACT(EPOCH FROM (r.completed_at - r.initiated_at)) as duration_seconds,
  
  -- Days rolled back
  EXTRACT(EPOCH FROM (fv.created_at - tv.created_at)) / 86400 as days_rolled_back
  
FROM versioning.dataset_rollbacks r
JOIN versioning.dataset_versions fv ON r.from_version_id = fv.version_id
JOIN versioning.dataset_versions tv ON r.to_version_id = tv.version_id
LEFT JOIN versioning.dataset_versions bv ON r.backup_version_id = bv.version_id
ORDER BY r.initiated_at DESC;

-- Functions

-- Get latest version of a dataset
CREATE OR REPLACE FUNCTION versioning.get_latest_version(p_dataset_name TEXT)
RETURNS TABLE (
  version_id UUID,
  version_number TEXT,
  file_path TEXT,
  created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    v.version_id,
    v.version_number,
    v.file_path,
    v.created_at
  FROM versioning.dataset_versions v
  WHERE v.dataset_name = p_dataset_name 
    AND v.status = 'active'
  ORDER BY v.created_at DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Semantic version comparison
CREATE OR REPLACE FUNCTION versioning.compare_versions(v1 TEXT, v2 TEXT)
RETURNS INTEGER AS $$
DECLARE
  v1_parts TEXT[];
  v2_parts TEXT[];
  v1_major INTEGER;
  v1_minor INTEGER; 
  v1_patch INTEGER;
  v2_major INTEGER;
  v2_minor INTEGER;
  v2_patch INTEGER;
BEGIN
  -- Parse version strings
  v1_parts := string_to_array(v1, '.');
  v2_parts := string_to_array(v2, '.');
  
  v1_major := COALESCE(v1_parts[1]::INTEGER, 0);
  v1_minor := COALESCE(v1_parts[2]::INTEGER, 0);
  v1_patch := COALESCE(v1_parts[3]::INTEGER, 0);
  
  v2_major := COALESCE(v2_parts[1]::INTEGER, 0);
  v2_minor := COALESCE(v2_parts[2]::INTEGER, 0);
  v2_patch := COALESCE(v2_parts[3]::INTEGER, 0);
  
  -- Compare versions
  IF v1_major > v2_major THEN
    RETURN 1;
  ELSIF v1_major < v2_major THEN
    RETURN -1;
  ELSIF v1_minor > v2_minor THEN
    RETURN 1;
  ELSIF v1_minor < v2_minor THEN
    RETURN -1;
  ELSIF v1_patch > v2_patch THEN
    RETURN 1;
  ELSIF v1_patch < v2_patch THEN
    RETURN -1;
  ELSE
    RETURN 0;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Get version statistics
CREATE OR REPLACE FUNCTION versioning.get_version_stats(p_dataset_name TEXT DEFAULT NULL)
RETURNS TABLE (
  dataset_name TEXT,
  total_versions BIGINT,
  active_versions BIGINT,
  archived_versions BIGINT,
  latest_version TEXT,
  total_rollbacks BIGINT,
  successful_rollbacks BIGINT,
  first_version_date TIMESTAMP WITH TIME ZONE,
  latest_version_date TIMESTAMP WITH TIME ZONE,
  avg_days_between_versions NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  WITH version_stats AS (
    SELECT 
      v.dataset_name,
      COUNT(*) as total_versions,
      COUNT(*) FILTER (WHERE v.status = 'active') as active_versions,
      COUNT(*) FILTER (WHERE v.status = 'archived') as archived_versions,
      MAX(v.version_number) as latest_version,
      MIN(v.created_at) as first_version_date,
      MAX(v.created_at) as latest_version_date,
      
      -- Calculate average days between versions
      CASE 
        WHEN COUNT(*) > 1 THEN
          EXTRACT(EPOCH FROM (MAX(v.created_at) - MIN(v.created_at))) / 86400.0 / (COUNT(*) - 1)
        ELSE NULL
      END as avg_days_between_versions
      
    FROM versioning.dataset_versions v
    WHERE (p_dataset_name IS NULL OR v.dataset_name = p_dataset_name)
    GROUP BY v.dataset_name
  ),
  rollback_stats AS (
    SELECT 
      r.dataset_name,
      COUNT(*) as total_rollbacks,
      COUNT(*) FILTER (WHERE r.status = 'success') as successful_rollbacks
    FROM versioning.dataset_rollbacks r
    WHERE (p_dataset_name IS NULL OR r.dataset_name = p_dataset_name)
    GROUP BY r.dataset_name
  )
  SELECT 
    vs.dataset_name,
    vs.total_versions,
    vs.active_versions,
    vs.archived_versions,
    vs.latest_version,
    COALESCE(rs.total_rollbacks, 0) as total_rollbacks,
    COALESCE(rs.successful_rollbacks, 0) as successful_rollbacks,
    vs.first_version_date,
    vs.latest_version_date,
    vs.avg_days_between_versions
  FROM version_stats vs
  LEFT JOIN rollback_stats rs ON vs.dataset_name = rs.dataset_name
  ORDER BY vs.latest_version_date DESC;
END;
$$ LANGUAGE plpgsql;

-- Triggers

-- Update parent_version_id automatically
CREATE OR REPLACE FUNCTION versioning.set_parent_version()
RETURNS TRIGGER AS $$
DECLARE
  latest_version_id UUID;
BEGIN
  -- Only set parent if not explicitly provided
  IF NEW.parent_version_id IS NULL THEN
    SELECT version_id INTO latest_version_id
    FROM versioning.dataset_versions 
    WHERE dataset_name = NEW.dataset_name
      AND version_id != NEW.version_id
      AND status IN ('active', 'archived')
    ORDER BY created_at DESC
    LIMIT 1;
    
    NEW.parent_version_id := latest_version_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_parent_version
  BEFORE INSERT ON versioning.dataset_versions
  FOR EACH ROW EXECUTE FUNCTION versioning.set_parent_version();

-- Insert sample data
INSERT INTO versioning.dataset_metadata (dataset_name, category, description, created_date, total_size_bytes, record_count) VALUES
('daily_transactions', 'gold', 'Daily aggregated transaction data', '2025-01-01', 50*1024*1024, 10000),
('store_rankings', 'gold', 'Store performance rankings', '2025-01-01', 5*1024*1024, 500),
('store_features', 'platinum', 'ML features for stores', '2025-01-01', 30*1024*1024, 1000)
ON CONFLICT (dataset_name) DO NOTHING;

-- Insert initial versions
INSERT INTO versioning.dataset_versions (dataset_name, version_number, file_path, file_size, checksum, created_by, change_description) VALUES
('daily_transactions', '1.0.0', 'exports/daily_transactions_v1.0.0.parquet', 50*1024*1024, 'abc123def456', 'system', 'Initial version'),
('daily_transactions', '1.0.1', 'exports/daily_transactions_v1.0.1.parquet', 52*1024*1024, 'def456ghi789', 'system', 'Bug fixes in aggregation logic'),
('daily_transactions', '1.1.0', 'exports/daily_transactions_v1.1.0.parquet', 55*1024*1024, 'ghi789jkl012', 'system', 'Added payment method breakdown'),

('store_rankings', '1.0.0', 'exports/store_rankings_v1.0.0.parquet', 5*1024*1024, 'xyz789abc123', 'system', 'Initial version'),
('store_rankings', '1.0.1', 'exports/store_rankings_v1.0.1.parquet', 5*1024*1024, 'abc123xyz789', 'system', 'Fixed ranking calculation'),

('store_features', '1.0.0', 'exports/store_features_v1.0.0.parquet', 30*1024*1024, 'mno345pqr678', 'system', 'Initial ML features'),
('store_features', '2.0.0', 'exports/store_features_v2.0.0.parquet', 45*1024*1024, 'pqr678stu901', 'system', 'Major schema update with new features')
ON CONFLICT (dataset_name, version_number) DO NOTHING;

-- Set the latest versions as active, others as archived
UPDATE versioning.dataset_versions SET status = 'archived' WHERE version_id NOT IN (
  SELECT DISTINCT ON (dataset_name) version_id
  FROM versioning.dataset_versions
  ORDER BY dataset_name, created_at DESC
);

-- Grant permissions
GRANT USAGE ON SCHEMA versioning TO authenticated, anon, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA versioning TO authenticated, anon;
GRANT ALL ON ALL TABLES IN SCHEMA versioning TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA versioning TO authenticated, anon, service_role;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA versioning TO service_role;

-- Row Level Security
ALTER TABLE versioning.dataset_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE versioning.dataset_rollbacks ENABLE ROW LEVEL SECURITY;
ALTER TABLE versioning.version_lineage ENABLE ROW LEVEL SECURITY;
ALTER TABLE versioning.version_comparisons ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view dataset versions" ON versioning.dataset_versions
  FOR SELECT USING (true);

CREATE POLICY "Service role can manage versions" ON versioning.dataset_versions
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Users can view rollback history" ON versioning.dataset_rollbacks
  FOR SELECT USING (true);

CREATE POLICY "Service role can manage rollbacks" ON versioning.dataset_rollbacks
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Users can view version lineage" ON versioning.version_lineage
  FOR SELECT USING (true);

CREATE POLICY "Service role can manage lineage" ON versioning.version_lineage
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Users can view version comparisons" ON versioning.version_comparisons
  FOR SELECT USING (true);

CREATE POLICY "Service role can manage comparisons" ON versioning.version_comparisons
  FOR ALL USING (auth.role() = 'service_role');