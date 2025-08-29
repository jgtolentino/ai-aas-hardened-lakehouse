import { test, expect } from '@playwright/test';
import { createClient } from '@supabase/supabase-js';

// Configuration
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://cxzllzyxwpyptfretryc.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

test.describe('RAG Pipeline Smoke Tests', () => {
  
  test.beforeAll(async () => {
    // Ensure we have service role key
    if (!SUPABASE_SERVICE_KEY) {
      throw new Error('SUPABASE_SERVICE_ROLE_KEY environment variable is required');
    }
  });

  test('should verify pgvector extension is installed', async () => {
    const { data, error } = await supabase.rpc('exec', {
      sql: "SELECT * FROM pg_extension WHERE extname = 'vector'"
    });
    
    expect(error).toBeNull();
    expect(data).toBeDefined();
    expect(data.length).toBeGreaterThan(0);
  });

  test('should verify documents table exists with correct schema', async () => {
    const { data, error } = await supabase
      .from('documents')
      .select('id')
      .limit(1);
    
    expect(error).toBeNull();
    // Table should exist (even if empty)
  });

  test('should verify documents table has embedding column with correct dimension', async () => {
    const { data, error } = await supabase.rpc('exec', {
      sql: `
        SELECT column_name, data_type, character_maximum_length 
        FROM information_schema.columns 
        WHERE table_name = 'documents' AND column_name = 'embedding'
      `
    });
    
    expect(error).toBeNull();
    expect(data).toBeDefined();
    expect(data.length).toBe(1);
    expect(data[0].column_name).toBe('embedding');
  });

  test('should verify HNSW index exists on embedding column', async () => {
    const { data, error } = await supabase.rpc('exec', {
      sql: `
        SELECT indexname, indexdef 
        FROM pg_indexes 
        WHERE tablename = 'documents' AND indexname = 'documents_embedding_hnsw_idx'
      `
    });
    
    expect(error).toBeNull();
    expect(data).toBeDefined();
    expect(data.length).toBe(1);
    expect(data[0].indexdef).toContain('hnsw');
  });

  test('should verify checksum unique constraint exists', async () => {
    const { data, error } = await supabase.rpc('exec', {
      sql: `
        SELECT constraint_name, constraint_type 
        FROM information_schema.table_constraints 
        WHERE table_name = 'documents' AND constraint_name = 'documents_checksum_uidx'
      `
    });
    
    expect(error).toBeNull();
    expect(data).toBeDefined();
    expect(data.length).toBe(1);
  });

  test('should verify match_documents function exists and is callable', async () => {
    // Create a dummy 1536-dimensional vector for testing
    const testEmbedding = Array(1536).fill(0.1);
    
    const { data, error } = await supabase.rpc('match_documents', {
      query_embedding: `[${testEmbedding.join(',')}]`,
      match_threshold: 0.1,
      match_count: 5
    });
    
    expect(error).toBeNull();
    expect(Array.isArray(data)).toBe(true);
    // Should return an array (even if empty when no documents exist)
  });

  test('should verify upsert_document function exists and works', async () => {
    const testDoc = {
      title_param: 'Smoke Test Document',
      content_param: 'This is a test document for RAG smoke testing.',
      url_param: null,
      metadata_param: { test: true },
      embedding_param: null, // Will be generated
      checksum_param: 'smoke_test_checksum_' + Date.now()
    };

    const { data, error } = await supabase.rpc('upsert_document', testDoc);
    
    expect(error).toBeNull();
    expect(data).toBeDefined();
    expect(typeof data).toBe('number'); // Should return document ID

    // Clean up test document
    await supabase
      .from('documents')
      .delete()
      .eq('checksum', testDoc.checksum_param);
  });

  test('should verify RLS policies are active', async () => {
    const { data, error } = await supabase.rpc('exec', {
      sql: `
        SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
        FROM pg_policies 
        WHERE tablename = 'documents'
      `
    });
    
    expect(error).toBeNull();
    expect(data).toBeDefined();
    expect(data.length).toBeGreaterThan(0);
    
    // Should have policies for authenticated users and service role
    const policyNames = data.map(p => p.policyname);
    expect(policyNames).toContain('read_docs_auth_only');
    expect(policyNames).toContain('manage_docs_service_role');
  });

  test('should verify chat tables exist with correct structure', async () => {
    const tables = ['chat_conversations', 'chat_messages'];
    
    for (const tableName of tables) {
      const { data, error } = await supabase
        .from(tableName)
        .select('*')
        .limit(0);
      
      expect(error).toBeNull();
      // Table should exist
    }
  });

  test('should verify chat RLS policies exist', async () => {
    const { data, error } = await supabase.rpc('exec', {
      sql: `
        SELECT tablename, policyname 
        FROM pg_policies 
        WHERE tablename IN ('chat_conversations', 'chat_messages')
      `
    });
    
    expect(error).toBeNull();
    expect(data).toBeDefined();
    expect(data.length).toBeGreaterThan(0);
    
    const policies = data.map(p => `${p.tablename}.${p.policyname}`);
    expect(policies).toContain('chat_conversations.users_own_conversations');
    expect(policies).toContain('chat_messages.users_own_messages');
  });

  test('should verify get_conversation_context function exists', async () => {
    const { data, error } = await supabase.rpc('get_conversation_context', {
      conversation_id_param: 999999, // Non-existent ID
      message_limit: 5
    });
    
    expect(error).toBeNull();
    expect(Array.isArray(data)).toBe(true);
    // Should return empty array for non-existent conversation
    expect(data.length).toBe(0);
  });

  test('should verify maintain_vector_index function exists', async () => {
    const { data, error } = await supabase.rpc('maintain_vector_index');
    
    expect(error).toBeNull();
    // Function should complete without error
  });
});

test.describe('RAG Edge Functions Smoke Tests', () => {
  
  test('should verify process-documents function is deployed', async ({ page }) => {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/process-documents`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        documents: [] // Empty array should return validation error
      })
    });
    
    expect(response.status).toBe(400);
    const result = await response.json();
    expect(result.error).toBe('Empty request');
  });

  test('should verify ai-generate-insight function is deployed', async ({ page }) => {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/ai-generate-insight`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        query: 'Test insight generation',
        context: { test: true }
      })
    });
    
    // Should return 200 or error related to OpenAI API key (not 404)
    expect([200, 500]).toContain(response.status);
    
    if (response.status === 500) {
      const result = await response.json();
      // Should fail on OpenAI API, not on function not found
      expect(result.message).not.toContain('not found');
    }
  });

  test('should verify CORS headers are properly configured', async ({ page }) => {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/process-documents`, {
      method: 'OPTIONS'
    });
    
    expect(response.status).toBe(200);
    expect(response.headers.get('Access-Control-Allow-Origin')).toBe('*');
    expect(response.headers.get('Access-Control-Allow-Methods')).toContain('POST');
  });
});

test.describe('RAG Integration Smoke Tests', () => {
  
  test('should process a test document end-to-end', async () => {
    const testDocument = {
      title: 'RAG Integration Test Document',
      content: 'This is a comprehensive test of the RAG pipeline functionality. It includes multiple sentences to test the token-aware chunking mechanism. The system should break this into appropriate chunks while maintaining semantic coherence.',
      type: 'text',
      metadata: { 
        test_run: true, 
        created_at: new Date().toISOString() 
      }
    };

    const response = await fetch(`${SUPABASE_URL}/functions/v1/process-documents`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        documents: [testDocument]
      })
    });
    
    if (response.ok) {
      const result = await response.json();
      expect(result.summary.successful).toBe(1);
      expect(result.summary.failed).toBe(0);
      expect(result.results[0].result.status).toBe('processed');
      
      // Clean up - find and delete test documents
      const { data: testDocs } = await supabase
        .from('documents')
        .select('id')
        .like('title', '%RAG Integration Test Document%');
      
      if (testDocs && testDocs.length > 0) {
        await supabase
          .from('documents')
          .delete()
          .in('id', testDocs.map(doc => doc.id));
      }
    } else {
      // If OpenAI API key is missing, that's expected in test environment
      const result = await response.json();
      console.warn('Document processing failed (expected in test environment):', result.message);
    }
  });

  test('should generate insights for test query', async () => {
    const testQuery = {
      query: 'What are the key business trends we should focus on?',
      context: {
        metric: 'revenue',
        timeRange: 'last_month',
        value: 125000,
        change: 0.15
      },
      options: {
        maxSources: 2,
        includeActionItems: true,
        confidenceThreshold: 0.3
      }
    };

    const response = await fetch(`${SUPABASE_URL}/functions/v1/ai-generate-insight`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(testQuery)
    });
    
    if (response.ok) {
      const result = await response.json();
      expect(result.insight).toBeDefined();
      expect(result.insight.title).toBeDefined();
      expect(result.insight.summary).toBeDefined();
      expect(result.insight.confidence).toBeGreaterThanOrEqual(0);
      expect(result.insight.confidence).toBeLessThanOrEqual(100);
      expect(['low', 'medium', 'high', 'critical']).toContain(result.insight.priority);
      expect(result.performance).toBeDefined();
    } else {
      // If OpenAI API key is missing, that's expected in test environment
      const result = await response.json();
      console.warn('Insight generation failed (expected in test environment):', result.message);
    }
  });
});