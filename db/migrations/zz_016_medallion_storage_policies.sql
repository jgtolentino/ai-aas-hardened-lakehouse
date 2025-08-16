-- ============================================================================
-- Scout Medallion Architecture - Storage Security Policies
-- Controls who can read/write to each medallion layer
-- ============================================================================

-- Bronze Layer (scout-ingest): Edge devices can write only
CREATE POLICY IF NOT EXISTS "edge_device_write_bronze"
ON storage.objects 
FOR INSERT
TO storage_uploader
WITH CHECK (
    bucket_id = 'scout-ingest' 
    AND (storage.foldername(name))[1] = to_char(CURRENT_DATE, 'YYYY-MM-DD')
);

-- Service role has full access to all buckets for ETL
CREATE POLICY IF NOT EXISTS "service_role_full_access"
ON storage.objects 
FOR ALL
TO service_role
USING (bucket_id IN ('scout-ingest', 'scout-silver', 'scout-gold', 'scout-platinum'))
WITH CHECK (bucket_id IN ('scout-ingest', 'scout-silver', 'scout-gold', 'scout-platinum'));

-- Authenticated users can read Gold layer (for dashboards)
CREATE POLICY IF NOT EXISTS "authenticated_read_gold"
ON storage.objects 
FOR SELECT
TO authenticated
USING (bucket_id = 'scout-gold');

-- Authenticated users can read Platinum with specific permissions
CREATE POLICY IF NOT EXISTS "authenticated_read_platinum_ml"
ON storage.objects 
FOR SELECT
TO authenticated
USING (
    bucket_id = 'scout-platinum' 
    AND auth.jwt() ->> 'role' IN ('ml_engineer', 'data_scientist', 'analyst')
);

-- Public anonymous read for specific Gold exports (optional)
CREATE POLICY IF NOT EXISTS "public_read_gold_exports"
ON storage.objects 
FOR SELECT
TO anon
USING (
    bucket_id = 'scout-gold' 
    AND (storage.foldername(name))[1] = 'public'
);

-- Audit log for all storage access
CREATE TABLE IF NOT EXISTS scout.medallion_storage_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bucket_id TEXT NOT NULL,
    file_path TEXT NOT NULL,
    operation TEXT NOT NULL CHECK (operation IN ('INSERT', 'SELECT', 'UPDATE', 'DELETE')),
    user_id UUID,
    user_role TEXT,
    accessed_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB
);

-- Index for efficient audit queries
CREATE INDEX IF NOT EXISTS idx_medallion_audit_bucket 
ON scout.medallion_storage_audit(bucket_id, accessed_at DESC);

CREATE INDEX IF NOT EXISTS idx_medallion_audit_user 
ON scout.medallion_storage_audit(user_id, accessed_at DESC);

-- Function to log storage access (optional - can be triggered)
CREATE OR REPLACE FUNCTION scout.log_storage_access()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO scout.medallion_storage_audit (
        bucket_id,
        file_path,
        operation,
        user_id,
        user_role,
        metadata
    ) VALUES (
        NEW.bucket_id,
        NEW.name,
        TG_OP,
        auth.uid(),
        auth.jwt() ->> 'role',
        jsonb_build_object(
            'size_bytes', NEW.metadata->>'size',
            'content_type', NEW.metadata->>'mimetype'
        )
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;