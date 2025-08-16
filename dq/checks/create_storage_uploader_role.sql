-- ============================================================================
-- Storage Uploader Role Setup for Edge Devices
-- 
-- This script creates a limited-permission role that your colleagues can use
-- to upload datasets from edge devices without having admin access
-- ============================================================================

-- Drop existing role if it exists (safe for re-running)
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'storage_uploader') THEN
        -- First revoke all existing permissions
        REVOKE ALL ON SCHEMA storage FROM storage_uploader;
        REVOKE ALL ON ALL TABLES IN SCHEMA storage FROM storage_uploader;
        
        -- Drop all policies owned by this role
        DROP POLICY IF EXISTS "storage_uploader_scout_only" ON storage.objects;
        
        -- Now safe to drop the role
        DROP ROLE storage_uploader;
        
        RAISE NOTICE 'Existing storage_uploader role dropped';
    END IF;
END $$;

-- Create the limited role 
-- NOLOGIN means it cannot connect directly to the database
CREATE ROLE storage_uploader NOLOGIN;

-- Grant minimal required permissions for storage operations
-- 1. Access to storage schema (required for any storage operations)
GRANT USAGE ON SCHEMA storage TO storage_uploader;

-- 2. Read bucket metadata (to verify bucket exists before upload)
GRANT SELECT ON storage.buckets TO storage_uploader;

-- 3. Core storage permissions:
--    - INSERT: Upload new files
--    - UPDATE: Replace existing files (upsert)
--    - SELECT: Read uploaded files to verify success
GRANT INSERT, UPDATE, SELECT ON storage.objects TO storage_uploader;

-- Create Row Level Security (RLS) policy
-- This is CRITICAL - it restricts uploads to scout/v1/* paths only
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

-- Add documentation
COMMENT ON ROLE storage_uploader IS 'Limited role for edge devices to upload Scout datasets only. Cannot access DB or delete files.';

-- Verify the setup was successful
DO $$
DECLARE
    perm_count INTEGER;
    role_exists BOOLEAN;
BEGIN
    -- Check role exists
    SELECT EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'storage_uploader') INTO role_exists;
    
    -- Count permissions
    SELECT COUNT(*) INTO perm_count
    FROM information_schema.role_table_grants 
    WHERE grantee = 'storage_uploader';
    
    -- Report results
    IF role_exists AND perm_count > 0 THEN
        RAISE NOTICE '✅ SUCCESS: storage_uploader role created with % permissions', perm_count;
        RAISE NOTICE '📁 Can upload to: sample bucket, scout/v1/* paths only';
        RAISE NOTICE '🔒 Cannot: Delete files, access database, or modify other buckets';
    ELSE
        RAISE EXCEPTION '❌ ERROR: Role creation failed';
    END IF;
END $$;