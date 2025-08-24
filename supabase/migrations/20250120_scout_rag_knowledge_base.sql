-- Scout v5.2 RAG Knowledge Base Implementation
-- Adds semantic search, vector storage, and AI-powered Q&A capabilities
-- Compatible with OpenAI text-embedding-ada-002 (1536 dims)

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create schema (keep it inside your unified namespace)
CREATE SCHEMA IF NOT EXISTS scout;

-- =====================================================================
-- Knowledge base tables
-- =====================================================================
CREATE TABLE IF NOT EXISTS scout.knowledge_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  source TEXT,                            -- e.g., url, path, system
  tags TEXT[] DEFAULT '{}',
  chunk_count INT DEFAULT 0,
  bytes INT DEFAULT 0,
  created_by UUID,                        -- auth.uid() of ingester
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Additional Scout-specific columns
  document_type TEXT,                     -- 'dashboard', 'report', 'manual', 'api_doc'
  version TEXT,                           -- Document version tracking
  is_active BOOLEAN DEFAULT true          -- Soft delete support
);

CREATE TABLE IF NOT EXISTS scout.knowledge_chunks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID NOT NULL REFERENCES scout.knowledge_documents(id) ON DELETE CASCADE,
  chunk_index INT NOT NULL,
  content TEXT NOT NULL,
  embedding vector(1536) NOT NULL,        -- OpenAI ada-002 dimensions
  metadata JSONB DEFAULT '{}'::JSONB,     -- page, section, widget, etc.
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Scout-specific metadata
  widget_context TEXT[],                  -- Associated dashboard widgets
  insight_category TEXT,                  -- Link to insights engine categories
  relevance_score FLOAT DEFAULT 1.0       -- For weighted search
);

-- =====================================================================
-- Indexes for performance
-- =====================================================================

-- Helpful search columns
CREATE INDEX IF NOT EXISTS idx_chunks_gin_trgm 
  ON scout.knowledge_chunks USING gin (content gin_trgm_ops);

-- Vector index (IVFFlat). Note: requires ANALYZE before fast index is used.
-- Lists=100 is good for up to 1M vectors
CREATE INDEX IF NOT EXISTS idx_chunks_embedding_ivf
  ON scout.knowledge_chunks USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

-- Fast filter by document
CREATE INDEX IF NOT EXISTS idx_chunks_doc 
  ON scout.knowledge_chunks(document_id);

-- Scout-specific indexes
CREATE INDEX IF NOT EXISTS idx_chunks_widget_context 
  ON scout.knowledge_chunks USING gin (widget_context);
CREATE INDEX IF NOT EXISTS idx_docs_type 
  ON scout.knowledge_documents(document_type);
CREATE INDEX IF NOT EXISTS idx_docs_active 
  ON scout.knowledge_documents(is_active) WHERE is_active = true;

-- =====================================================================
-- Triggers for data integrity
-- =====================================================================

-- Keep chunk_count in sync
CREATE OR REPLACE FUNCTION scout.tg_update_chunk_count() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE scout.knowledge_documents
    SET chunk_count = (SELECT COUNT(*) FROM scout.knowledge_chunks WHERE document_id = NEW.document_id)
    WHERE id = NEW.document_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE scout.knowledge_documents
    SET chunk_count = (SELECT COUNT(*) FROM scout.knowledge_chunks WHERE document_id = OLD.document_id)
    WHERE id = OLD.document_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_chunk_count_ins ON scout.knowledge_chunks;
CREATE TRIGGER trg_update_chunk_count_ins
AFTER INSERT ON scout.knowledge_chunks
FOR EACH ROW EXECUTE PROCEDURE scout.tg_update_chunk_count();

DROP TRIGGER IF EXISTS trg_update_chunk_count_del ON scout.knowledge_chunks;
CREATE TRIGGER trg_update_chunk_count_del
AFTER DELETE ON scout.knowledge_chunks
FOR EACH ROW EXECUTE PROCEDURE scout.tg_update_chunk_count();

-- =====================================================================
-- RLS (Row Level Security)
-- =====================================================================
ALTER TABLE scout.knowledge_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.knowledge_chunks ENABLE ROW LEVEL SECURITY;

-- Read policies - authenticated users can read
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='scout' AND tablename='knowledge_chunks' AND policyname='read_chunks_authenticated'
  ) THEN
    CREATE POLICY read_chunks_authenticated
      ON scout.knowledge_chunks
      FOR SELECT
      USING (auth.role() = 'authenticated');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='scout' AND tablename='knowledge_documents' AND policyname='read_docs_authenticated'
  ) THEN
    CREATE POLICY read_docs_authenticated
      ON scout.knowledge_documents
      FOR SELECT
      USING (auth.role() = 'authenticated' AND is_active = true);
  END IF;
END$$;

-- Write policies - only service role for ingestion
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='scout' AND tablename='knowledge_documents' AND policyname='write_docs_service'
  ) THEN
    CREATE POLICY write_docs_service
      ON scout.knowledge_documents
      FOR ALL
      USING (auth.jwt() ->> 'role' = 'service_role');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='scout' AND tablename='knowledge_chunks' AND policyname='write_chunks_service'
  ) THEN
    CREATE POLICY write_chunks_service
      ON scout.knowledge_chunks
      FOR ALL
      USING (auth.jwt() ->> 'role' = 'service_role');
  END IF;
END$$;

-- =====================================================================
-- RPC: vector_search - Core semantic search function
-- =====================================================================
CREATE OR REPLACE FUNCTION scout.vector_search(
  query_embedding vector(1536),
  match_threshold FLOAT DEFAULT 0.70,
  match_count INT DEFAULT 8,
  filter_widgets TEXT[] DEFAULT NULL,
  filter_categories TEXT[] DEFAULT NULL
)
RETURNS TABLE(
  chunk_id UUID,
  document_id UUID,
  document_title TEXT,
  chunk_index INT,
  content TEXT,
  similarity FLOAT,
  metadata JSONB,
  widget_context TEXT[],
  insight_category TEXT
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    c.id AS chunk_id,
    c.document_id,
    d.title AS document_title,
    c.chunk_index,
    c.content,
    (1 - (c.embedding <=> query_embedding))::FLOAT AS similarity, -- cosine similarity
    c.metadata,
    c.widget_context,
    c.insight_category
  FROM scout.knowledge_chunks c
  JOIN scout.knowledge_documents d ON d.id = c.document_id
  WHERE 
    d.is_active = true
    AND (1 - (c.embedding <=> query_embedding)) >= match_threshold
    AND (filter_widgets IS NULL OR c.widget_context && filter_widgets)
    AND (filter_categories IS NULL OR c.insight_category = ANY(filter_categories))
  ORDER BY c.embedding <=> query_embedding
  LIMIT match_count
$$;

-- =====================================================================
-- RPC: hybrid_search - Combines vector + keyword search
-- =====================================================================
CREATE OR REPLACE FUNCTION scout.hybrid_search(
  query_text TEXT,
  query_embedding vector(1536),
  match_threshold FLOAT DEFAULT 0.70,
  match_count INT DEFAULT 8,
  keyword_weight FLOAT DEFAULT 0.3
)
RETURNS TABLE(
  chunk_id UUID,
  document_id UUID,
  document_title TEXT,
  chunk_index INT,
  content TEXT,
  vector_similarity FLOAT,
  text_similarity FLOAT,
  combined_score FLOAT,
  metadata JSONB
)
LANGUAGE sql
STABLE
AS $$
  WITH vector_results AS (
    SELECT
      c.id AS chunk_id,
      c.document_id,
      d.title AS document_title,
      c.chunk_index,
      c.content,
      (1 - (c.embedding <=> query_embedding))::FLOAT AS vector_similarity,
      c.metadata
    FROM scout.knowledge_chunks c
    JOIN scout.knowledge_documents d ON d.id = c.document_id
    WHERE 
      d.is_active = true
      AND (1 - (c.embedding <=> query_embedding)) >= match_threshold
  ),
  text_results AS (
    SELECT
      c.id AS chunk_id,
      similarity(c.content, query_text) AS text_similarity
    FROM scout.knowledge_chunks c
    WHERE c.content % query_text -- trigram similarity operator
  )
  SELECT
    vr.chunk_id,
    vr.document_id,
    vr.document_title,
    vr.chunk_index,
    vr.content,
    vr.vector_similarity,
    COALESCE(tr.text_similarity, 0) AS text_similarity,
    (vr.vector_similarity * (1 - keyword_weight) + 
     COALESCE(tr.text_similarity, 0) * keyword_weight) AS combined_score,
    vr.metadata
  FROM vector_results vr
  LEFT JOIN text_results tr ON vr.chunk_id = tr.chunk_id
  ORDER BY combined_score DESC
  LIMIT match_count
$$;

-- =====================================================================
-- RPC: semantic_search_with_context - Enhanced search with business context
-- =====================================================================
CREATE OR REPLACE FUNCTION scout.semantic_search_with_context(
  query_embedding vector(1536),
  user_context JSONB DEFAULT '{}'::JSONB,  -- Current dashboard, active filters, etc
  match_threshold FLOAT DEFAULT 0.70,
  match_count INT DEFAULT 8
)
RETURNS TABLE(
  chunk_id UUID,
  document_id UUID,
  document_title TEXT,
  chunk_index INT,
  content TEXT,
  similarity FLOAT,
  relevance_score FLOAT,
  metadata JSONB,
  reasoning TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  active_widget TEXT;
  user_role TEXT;
BEGIN
  -- Extract user context
  active_widget := user_context->>'active_widget';
  user_role := user_context->>'user_role';
  
  RETURN QUERY
  WITH base_results AS (
    SELECT
      c.id AS chunk_id,
      c.document_id,
      d.title AS document_title,
      d.document_type,
      c.chunk_index,
      c.content,
      (1 - (c.embedding <=> query_embedding))::FLOAT AS similarity,
      c.metadata,
      c.widget_context,
      c.relevance_score
    FROM scout.knowledge_chunks c
    JOIN scout.knowledge_documents d ON d.id = c.document_id
    WHERE 
      d.is_active = true
      AND (1 - (c.embedding <=> query_embedding)) >= match_threshold
  )
  SELECT
    br.chunk_id,
    br.document_id,
    br.document_title,
    br.chunk_index,
    br.content,
    br.similarity,
    -- Boost relevance based on context
    (br.similarity * br.relevance_score * 
     CASE 
       WHEN active_widget IS NOT NULL AND active_widget = ANY(br.widget_context) THEN 1.2
       ELSE 1.0
     END) AS relevance_score,
    br.metadata,
    -- Explain why this result is relevant
    CASE
      WHEN active_widget IS NOT NULL AND active_widget = ANY(br.widget_context) 
        THEN 'Highly relevant to current ' || active_widget || ' widget'
      WHEN br.document_type = 'dashboard'
        THEN 'Dashboard-specific insight'
      WHEN br.similarity > 0.9
        THEN 'Very high semantic match'
      ELSE 'Relevant content'
    END AS reasoning
  FROM base_results br
  ORDER BY relevance_score DESC
  LIMIT match_count;
END;
$$;

-- =====================================================================
-- Audit table for search queries (optional but recommended)
-- =====================================================================
CREATE TABLE IF NOT EXISTS scout.search_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  query_text TEXT,
  query_type TEXT, -- 'vector', 'hybrid', 'context'
  result_count INT,
  avg_similarity FLOAT,
  response_time_ms INT,
  user_context JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for analytics
CREATE INDEX IF NOT EXISTS idx_search_audit_user 
  ON scout.search_audit(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_search_audit_type 
  ON scout.search_audit(query_type, created_at DESC);

-- =====================================================================
-- Helper function to get similar documents (for "related content")
-- =====================================================================
CREATE OR REPLACE FUNCTION scout.find_similar_documents(
  source_document_id UUID,
  match_count INT DEFAULT 5
)
RETURNS TABLE(
  document_id UUID,
  title TEXT,
  similarity_score FLOAT,
  common_tags TEXT[]
)
LANGUAGE sql
STABLE
AS $$
  WITH source_embeddings AS (
    SELECT embedding
    FROM scout.knowledge_chunks
    WHERE document_id = source_document_id
    LIMIT 5 -- Sample first 5 chunks
  ),
  avg_embedding AS (
    SELECT AVG(embedding)::vector(1536) AS avg_emb
    FROM source_embeddings
  ),
  similarities AS (
    SELECT 
      c.document_id,
      AVG(1 - (c.embedding <=> ae.avg_emb))::FLOAT AS avg_similarity
    FROM scout.knowledge_chunks c
    CROSS JOIN avg_embedding ae
    WHERE c.document_id != source_document_id
    GROUP BY c.document_id
  )
  SELECT
    s.document_id,
    d.title,
    s.avg_similarity AS similarity_score,
    d.tags AS common_tags
  FROM similarities s
  JOIN scout.knowledge_documents d ON d.id = s.document_id
  WHERE d.is_active = true
  ORDER BY s.avg_similarity DESC
  LIMIT match_count
$$;

-- =====================================================================
-- Helpful ANALYZE after bulk load for IVFFlat performance
-- =====================================================================
ANALYZE scout.knowledge_chunks;

-- =====================================================================
-- Sample data to test the system (optional)
-- =====================================================================
-- INSERT INTO scout.knowledge_documents (title, source, document_type, tags) VALUES
-- ('Scout v5.2 Architecture Guide', 'docs/architecture.md', 'manual', ARRAY['architecture', 'technical']),
-- ('Dashboard Widget Reference', 'docs/widgets.md', 'api_doc', ARRAY['widgets', 'frontend']),
-- ('Business Intelligence Best Practices', 'docs/bi-guide.md', 'report', ARRAY['insights', 'analytics']);

-- Note: Actual chunks with embeddings would be inserted via the Edge Function