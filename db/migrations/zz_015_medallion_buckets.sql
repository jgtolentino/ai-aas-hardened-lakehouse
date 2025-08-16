-- ============================================================================
-- Scout Medallion Architecture - Storage Buckets
-- Bronze → Silver → Gold → Platinum
-- ============================================================================

-- Create the 4 medallion storage buckets
DO $$
BEGIN
    -- Bronze: Raw ingestion from edge devices
    IF NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'scout-ingest') THEN
        INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
        VALUES (
            'scout-ingest',
            'scout-ingest', 
            false, -- private
            50 * 1024 * 1024, -- 50MB per file
            ARRAY['application/json', 'text/csv', 'application/octet-stream', 'image/jpeg', 'image/png']
        );
    END IF;

    -- Silver: Cleaned and validated data
    IF NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'scout-silver') THEN
        INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
        VALUES (
            'scout-silver',
            'scout-silver',
            false, -- private
            100 * 1024 * 1024, -- 100MB per file
            ARRAY['text/csv', 'application/parquet', 'application/json']
        );
    END IF;

    -- Gold: Business-ready aggregates
    IF NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'scout-gold') THEN
        INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
        VALUES (
            'scout-gold',
            'scout-gold',
            false, -- private but accessible via signed URLs
            200 * 1024 * 1024, -- 200MB per file
            ARRAY['text/csv', 'application/parquet', 'application/json']
        );
    END IF;

    -- Platinum: ML features and specialized exports
    IF NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'scout-platinum') THEN
        INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
        VALUES (
            'scout-platinum',
            'scout-platinum',
            false, -- private
            500 * 1024 * 1024, -- 500MB per file
            ARRAY['text/csv', 'application/parquet', 'application/json', 'application/x-tensorflow']
        );
    END IF;
END $$;

-- Verify bucket creation
SELECT id, name, public, file_size_limit 
FROM storage.buckets 
WHERE id LIKE 'scout-%'
ORDER BY 
    CASE id 
        WHEN 'scout-ingest' THEN 1
        WHEN 'scout-silver' THEN 2
        WHEN 'scout-gold' THEN 3
        WHEN 'scout-platinum' THEN 4
    END;