-- Dictionary Lifecycle: Automated Brand Dictionary Management
-- This migration creates the infrastructure for auto-generating and maintaining brand dictionaries

-- 1) Canonical brand names consolidation
CREATE OR REPLACE FUNCTION scout.consolidate_brands() RETURNS void AS $$
BEGIN
  -- Consolidate brand names from SRP + snapshots
  WITH brands AS (
    SELECT LOWER(REGEXP_REPLACE(brand_name,'[^a-z0-9 ]','','g')) AS b
    FROM scout.brand_catalog
    UNION
    SELECT LOWER(REGEXP_REPLACE(SPLIT_PART(product_name,' ',1),'[^a-z0-9 ]','','g'))
    FROM scout.product_catalog
    UNION
    SELECT LOWER(REGEXP_REPLACE(COALESCE(sp.source,''),'[^a-z0-9 ]','','g'))
    FROM reference.srp_prices sp
  )
  INSERT INTO scout.brand_catalog(brand_name, norm_name)
  SELECT 
    INITCAP(b) AS brand_name, 
    REGEXP_REPLACE(b,'\s+','_','g') AS norm_name
  FROM (SELECT DISTINCT b FROM brands WHERE LENGTH(b) > 1) x
  ON CONFLICT (norm_name) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- 2) Auto-generate dictionary candidates view
CREATE OR REPLACE VIEW scout.v_dict_candidates AS
SELECT
  bc.brand_id,
  bc.brand_name AS canonical,
  ARRAY_REMOVE(
    ARRAY_AGG(DISTINCT LOWER(REGEXP_REPLACE(pc.product_name,'[^a-z0-9 ]','','g'))), 
    NULL
  ) AS tokens
FROM scout.brand_catalog bc
LEFT JOIN scout.product_catalog pc ON pc.brand_id = bc.brand_id
GROUP BY bc.brand_id, bc.brand_name;

-- Brand aliases table for human-approved variations
CREATE TABLE IF NOT EXISTS scout.brand_aliases(
  brand_id BIGINT REFERENCES scout.brand_catalog(brand_id) ON DELETE CASCADE,
  alias TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by TEXT DEFAULT CURRENT_USER,
  CONSTRAINT uq_brand_alias UNIQUE(brand_id, alias)
);

-- Index for fast lookups
CREATE INDEX idx_brand_aliases_brand_id ON scout.brand_aliases(brand_id);

-- 3) UNK feedback tracking
CREATE TABLE IF NOT EXISTS scout.unknown_clusters (
  id BIGSERIAL PRIMARY KEY,
  phrase TEXT NOT NULL,
  occurrence_count INT NOT NULL,
  first_seen TIMESTAMPTZ DEFAULT NOW(),
  last_seen TIMESTAMPTZ DEFAULT NOW(),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'promoted', 'rejected')),
  promoted_to_brand_id BIGINT REFERENCES scout.brand_catalog(brand_id),
  review_notes TEXT,
  reviewed_at TIMESTAMPTZ,
  reviewed_by TEXT,
  CONSTRAINT uq_unknown_phrase UNIQUE(phrase)
);

-- Index for finding high-volume unknowns
CREATE INDEX idx_unknown_clusters_status_count ON scout.unknown_clusters(status, occurrence_count DESC);

-- Function to identify and cluster unknowns
CREATE OR REPLACE FUNCTION scout.cluster_unknowns() RETURNS void AS $$
BEGIN
  -- Insert or update unknown clusters from last 7 days
  INSERT INTO scout.unknown_clusters (phrase, occurrence_count, last_seen)
  SELECT 
    LOWER(TRIM(p.text_input)) AS phrase, 
    COUNT(*) AS n,
    MAX(p.ts) AS last_seen
  FROM ml.prediction_events p
  WHERE p.ts > NOW() - INTERVAL '7 days' 
    AND p.predicted_brand = 'unknown'
  GROUP BY 1
  HAVING COUNT(*) >= 5
  ON CONFLICT (phrase) DO UPDATE
  SET 
    occurrence_count = EXCLUDED.occurrence_count,
    last_seen = EXCLUDED.last_seen;
END;
$$ LANGUAGE plpgsql;

-- 4) Auto-promotion based on feedback consensus
CREATE OR REPLACE FUNCTION scout.auto_promote_brands() RETURNS void AS $$
BEGIN
  -- When feedback labels agree ≥ 80%, auto-promote
  WITH votes AS (
    SELECT 
      l.true_brand, 
      COUNT(*) AS n,
      COUNT(*)::FLOAT / NULLIF(
        (SELECT COUNT(*) FROM ml.labels l2 
         JOIN ml.prediction_events p2 USING(prediction_id)
         WHERE p2.predicted_brand = 'unknown' 
           AND LOWER(TRIM(p2.text_input)) = LOWER(TRIM(p.text_input))), 
        0
      ) AS consensus_rate
    FROM ml.labels l
    JOIN ml.prediction_events p USING(prediction_id)
    WHERE p.predicted_brand = 'unknown' 
      AND p.ts > NOW() - INTERVAL '14 days'
    GROUP BY 1
    HAVING COUNT(*) >= 20 AND consensus_rate >= 0.8
  )
  INSERT INTO scout.brand_catalog (brand_name, norm_name)
  SELECT 
    INITCAP(true_brand), 
    REGEXP_REPLACE(true_brand,'\s+','_','g')
  FROM votes
  ON CONFLICT DO NOTHING;
  
  -- Mark promoted clusters
  UPDATE scout.unknown_clusters uc
  SET 
    status = 'promoted',
    promoted_to_brand_id = bc.brand_id,
    reviewed_at = NOW(),
    reviewed_by = 'auto-promotion'
  FROM votes v
  JOIN scout.brand_catalog bc ON bc.norm_name = REGEXP_REPLACE(v.true_brand,'\s+','_','g')
  WHERE LOWER(uc.phrase) = LOWER(v.true_brand);
END;
$$ LANGUAGE plpgsql;

-- 5) Reprocessing queue
CREATE TABLE IF NOT EXISTS scout.reprocess_queue (
  id BIGSERIAL PRIMARY KEY,
  entity_type TEXT NOT NULL CHECK (entity_type IN ('transcript', 'transaction', 'product')),
  entity_id BIGINT NOT NULL,
  reason TEXT,
  queued_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  error_message TEXT,
  CONSTRAINT uq_reprocess_entity UNIQUE(entity_type, entity_id)
);

-- Index for efficient queue processing
CREATE INDEX idx_reprocess_queue_pending ON scout.reprocess_queue(status, queued_at) 
WHERE status = 'pending';

-- Function to queue stale items for reprocessing
CREATE OR REPLACE FUNCTION scout.queue_reprocessing(days_back INT DEFAULT 30) RETURNS void AS $$
BEGIN
  -- Queue transcripts
  INSERT INTO scout.reprocess_queue (entity_type, entity_id, reason)
  SELECT 'transcript', t.id, 'dictionary_update'
  FROM bronze.transcripts t
  WHERE t.created_at > NOW() - INTERVAL '1 day' * days_back
  ON CONFLICT DO NOTHING;
  
  -- Mark transcripts as needing redetection
  UPDATE bronze.transcripts
  SET needs_redetect = true
  WHERE created_at > NOW() - INTERVAL '1 day' * days_back;
END;
$$ LANGUAGE plpgsql;

-- 6) Coverage monitoring views
CREATE OR REPLACE VIEW dq.v_brand_coverage AS
SELECT
  DATE_TRUNC('day', p.ts) AS day,
  COUNT(*) FILTER (WHERE p.predicted_brand <> 'unknown')::FLOAT / GREATEST(COUNT(*), 1) AS brand_coverage,
  COUNT(*) AS total_predictions,
  COUNT(*) FILTER (WHERE p.predicted_brand = 'unknown') AS unknown_count
FROM ml.prediction_events p
WHERE p.ts > NOW() - INTERVAL '7 days'
GROUP BY 1;

-- Price coverage view
CREATE OR REPLACE VIEW dq.v_price_coverage AS
SELECT
  DATE_TRUNC('day', t.transaction_date) AS day,
  COUNT(*) FILTER (WHERE t.total_amount > 0)::FLOAT / GREATEST(COUNT(*), 1) AS price_coverage,
  COUNT(*) AS total_transactions,
  COUNT(*) FILTER (WHERE t.total_amount IS NULL OR t.total_amount = 0) AS missing_price_count
FROM scout_gold.fact_transactions t
WHERE t.transaction_date > CURRENT_DATE - INTERVAL '7 days'
GROUP BY 1;

-- Combined coverage metrics
CREATE OR REPLACE VIEW dq.v_coverage_summary AS
SELECT
  COALESCE(b.day, p.day) AS day,
  b.brand_coverage,
  p.price_coverage,
  b.total_predictions,
  p.total_transactions
FROM dq.v_brand_coverage b
FULL OUTER JOIN dq.v_price_coverage p ON b.day = p.day
ORDER BY 1 DESC;

-- 7) Dictionary version tracking
CREATE TABLE IF NOT EXISTS scout.dictionary_versions (
  version_id BIGSERIAL PRIMARY KEY,
  version_hash TEXT NOT NULL,
  brand_count INT NOT NULL,
  alias_count INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  deployed_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT FALSE,
  metadata JSONB
);

-- Ensure only one active version
CREATE UNIQUE INDEX idx_dictionary_versions_active ON scout.dictionary_versions(is_active) 
WHERE is_active = TRUE;

-- Function to generate dictionary JSON
CREATE OR REPLACE FUNCTION scout.generate_dictionary_json() RETURNS JSONB AS $$
DECLARE
  dict_data JSONB;
  version_hash TEXT;
BEGIN
  -- Generate dictionary data
  WITH dict_entries AS (
    SELECT 
      c.brand_id,
      c.canonical,
      ARRAY_REMOVE(
        ARRAY_CAT(
          ARRAY[REGEXP_REPLACE(c.canonical,'[^A-Za-z0-9]+','\\W+', 'g')],
          ARRAY_AGG(DISTINCT REGEXP_REPLACE(a.alias,'[^A-Za-z0-9]+','\\W+','g'))
        ), 
        NULL
      ) AS patterns
    FROM scout.v_dict_candidates c
    LEFT JOIN scout.brand_aliases a ON a.brand_id = c.brand_id
    GROUP BY c.brand_id, c.canonical
  )
  SELECT 
    JSONB_BUILD_OBJECT(
      'version', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'),
      'brands', JSONB_AGG(
        JSONB_BUILD_OBJECT(
          'canonical', canonical,
          'patterns', patterns
        )
      )
    ) INTO dict_data
  FROM dict_entries;
  
  -- Calculate version hash
  version_hash := MD5(dict_data::TEXT);
  
  -- Record version
  INSERT INTO scout.dictionary_versions (version_hash, brand_count, alias_count, metadata)
  SELECT 
    version_hash,
    (SELECT COUNT(DISTINCT brand_id) FROM scout.brand_catalog),
    (SELECT COUNT(*) FROM scout.brand_aliases),
    dict_data;
  
  RETURN dict_data;
END;
$$ LANGUAGE plpgsql;

-- 8) Grant permissions
GRANT SELECT ON scout.v_dict_candidates TO authenticated;
GRANT SELECT ON scout.brand_aliases TO authenticated;
GRANT INSERT, UPDATE ON scout.brand_aliases TO authenticated;
GRANT SELECT ON scout.unknown_clusters TO authenticated;
GRANT UPDATE ON scout.unknown_clusters TO authenticated;
GRANT SELECT ON dq.v_brand_coverage TO authenticated;
GRANT SELECT ON dq.v_price_coverage TO authenticated;
GRANT SELECT ON dq.v_coverage_summary TO authenticated;
GRANT EXECUTE ON FUNCTION scout.consolidate_brands() TO authenticated;
GRANT EXECUTE ON FUNCTION scout.cluster_unknowns() TO authenticated;
GRANT EXECUTE ON FUNCTION scout.generate_dictionary_json() TO authenticated;