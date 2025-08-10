-- ============================================================================
-- Storage Uploader Role Setup
-- 
-- Creates a limited-permission role for edge devices and team members
-- to upload datasets to Supabase Storage without full admin access
-- ============================================================================

-- Drop role if exists (for re-running)
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'storage_uploader') THEN
        -- Revoke all permissions first
        REVOKE ALL ON SCHEMA storage FROM storage_uploader;
        REVOKE ALL ON ALL TABLES IN SCHEMA storage FROM storage_uploader;
        DROP ROLE storage_uploader;
    END IF;
END $$;

-- Create the limited role (NOLOGIN = can't connect directly to DB)
CREATE ROLE storage_uploader NOLOGIN;

-- Grant minimal required permissions
-- 1. Access to storage schema
GRANT USAGE ON SCHEMA storage TO storage_uploader;

-- 2. Read bucket metadata (to check if bucket exists)
GRANT SELECT ON storage.buckets TO storage_uploader;

-- 3. Insert new objects (upload files)
GRANT INSERT ON storage.objects TO storage_uploader;

-- 4. Update existing objects (for upsert/replace)
GRANT UPDATE ON storage.objects TO storage_uploader;

-- 5. Select own uploads (to verify upload success)
GRANT SELECT ON storage.objects TO storage_uploader;

-- Create RLS policy to limit uploads to scout datasets only
-- This ensures they can only upload to the scout/v1/ path
CREATE POLICY "storage_uploader_scout_only" ON storage.objects
FOR ALL 
TO storage_uploader
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

-- Add helpful comment
COMMENT ON ROLE storage_uploader IS 'Limited role for edge devices to upload Scout datasets only';

-- Verify the setup
SELECT 
    'storage_uploader role created successfully' as status,
    COUNT(*) as permission_count
FROM information_schema.role_table_grants 
WHERE grantee = 'storage_uploader';