-- ============================================================================
-- Scout Dataset Storage Policies
-- 
-- Secure access control for published datasets in Supabase Storage
-- - Private bucket (no public access)
-- - Service role can write/update under scout/v1/**
-- - Authenticated users can read via signed URLs only
-- - Audit logging for dataset access
-- ============================================================================

-- Ensure the sample bucket exists and is private
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'sample',
  'sample',
  false, -- Keep private
  100 * 1024 * 1024, -- 100MB per file limit
  ARRAY['text/csv', 'application/octet-stream', 'application/json']
)
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = 100 * 1024 * 1024,
  allowed_mime_types = ARRAY['text/csv', 'application/octet-stream', 'application/json'];

-- Service role can write/update datasets under scout/v1/**
CREATE POLICY IF NOT EXISTS "datasets_service_write"
ON storage.objects 
FOR INSERT
TO service_role
WITH CHECK (
  bucket_id = 'sample' 
  AND (storage.foldername(name))[1] = 'scout'
  AND (storage.foldername(name))[2] = 'v1'
);

CREATE POLICY IF NOT EXISTS "datasets_service_update"
ON storage.objects 
FOR UPDATE
TO service_role
USING (
  bucket_id = 'sample' 
  AND (storage.foldername(name))[1] = 'scout'
  AND (storage.foldername(name))[2] = 'v1'
)
WITH CHECK (
  bucket_id = 'sample' 
  AND (storage.foldername(name))[1] = 'scout'
  AND (storage.foldername(name))[2] = 'v1'
);

-- Service role can delete old dataset versions
CREATE POLICY IF NOT EXISTS "datasets_service_delete"
ON storage.objects 
FOR DELETE
TO service_role
USING (
  bucket_id = 'sample' 
  AND (storage.foldername(name))[1] = 'scout'
  AND (storage.foldername(name))[2] = 'v1'
);

-- Authenticated users can read datasets (signed URLs only, no direct public access)
CREATE POLICY IF NOT EXISTS "datasets_authenticated_read"
ON storage.objects 
FOR SELECT
TO authenticated
USING (
  bucket_id = 'sample' 
  AND (storage.foldername(name))[1] = 'scout'
  AND (storage.foldername(name))[2] = 'v1'
);

-- Create audit log table for dataset access
CREATE TABLE IF NOT EXISTS scout.dataset_access_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dataset_id TEXT NOT NULL,
  user_identifier TEXT NOT NULL,
  success BOOLEAN NOT NULL DEFAULT false,
  error_message TEXT,
  accessed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  user_agent TEXT,
  ip_address INET,
  
  -- Indexes for common queries
  CONSTRAINT dataset_access_logs_dataset_id_idx
    UNIQUE (id)
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_dataset_access_logs_dataset_id 
ON scout.dataset_access_logs (dataset_id);

CREATE INDEX IF NOT EXISTS idx_dataset_access_logs_accessed_at 
ON scout.dataset_access_logs (accessed_at DESC);

CREATE INDEX IF NOT EXISTS idx_dataset_access_logs_user_identifier 
ON scout.dataset_access_logs (user_identifier);

-- RLS for audit logs (only service role and authenticated users can read their own logs)
ALTER TABLE scout.dataset_access_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "dataset_access_logs_service_all"
ON scout.dataset_access_logs
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

CREATE POLICY IF NOT EXISTS "dataset_access_logs_user_read_own"
ON scout.dataset_access_logs
FOR SELECT
TO authenticated
USING (user_identifier = COALESCE(auth.jwt() ->> 'sub', 'anonymous'));

-- Grant necessary permissions
GRANT SELECT ON scout.dataset_access_logs TO authenticated;
GRANT ALL ON scout.dataset_access_logs TO service_role;

-- Create a function to clean up old access logs (retention policy)
CREATE OR REPLACE FUNCTION scout.cleanup_old_access_logs()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM scout.dataset_access_logs 
  WHERE accessed_at < NOW() - INTERVAL '90 days';
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  RETURN deleted_count;
END;
$$;

-- Schedule cleanup to run daily (requires pg_cron extension)
-- Uncomment if pg_cron is available:
-- SELECT cron.schedule('cleanup-dataset-logs', '0 2 * * *', 'SELECT scout.cleanup_old_access_logs();');

-- Create a view for dataset access analytics
CREATE OR REPLACE VIEW scout.dataset_access_analytics AS
SELECT 
  dataset_id,
  DATE_TRUNC('day', accessed_at) as access_date,
  COUNT(*) as total_requests,
  COUNT(CASE WHEN success THEN 1 END) as successful_requests,
  COUNT(CASE WHEN NOT success THEN 1 END) as failed_requests,
  COUNT(DISTINCT user_identifier) as unique_users,
  ROUND(
    COUNT(CASE WHEN success THEN 1 END)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 
    2
  ) as success_rate_percent
FROM scout.dataset_access_logs
WHERE accessed_at >= NOW() - INTERVAL '30 days'
GROUP BY dataset_id, DATE_TRUNC('day', accessed_at)
ORDER BY access_date DESC, dataset_id;

-- Grant access to the analytics view
GRANT SELECT ON scout.dataset_access_analytics TO authenticated;
GRANT ALL ON scout.dataset_access_analytics TO service_role;

-- Add helpful comments
COMMENT ON TABLE scout.dataset_access_logs IS 'Audit log for dataset access via the dataset-proxy function';
COMMENT ON VIEW scout.dataset_access_analytics IS 'Analytics view showing dataset access patterns over the last 30 days';
COMMENT ON FUNCTION scout.cleanup_old_access_logs() IS 'Cleanup function to remove access logs older than 90 days';