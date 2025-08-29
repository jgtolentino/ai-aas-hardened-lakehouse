# RAG Pipeline Smoke Tests

Comprehensive smoke tests for the Scout Dashboard RAG (Retrieval Augmented Generation) pipeline.

## Overview

These tests verify that all components of the RAG system are working correctly:

- ✅ **Database Infrastructure**: pgvector extension, HNSW indexes, RLS policies
- ✅ **Vector Operations**: Document embedding, similarity search, vector storage
- ✅ **Edge Functions**: Document processing, insight generation APIs
- ✅ **Data Pipeline**: Idempotent writes, checksum validation, token-aware chunking
- ✅ **Security**: Row-level security, authentication, proper permissions

## Quick Start

### 1. Setup Environment

```bash
cd tests/rag
cp .env.example .env
# Edit .env with your Supabase credentials
```

### 2. Install Dependencies

```bash
npm install
npm run install-browsers
```

### 3. Run Smoke Tests

**Shell Script (Fast)**:
```bash
npm run smoke-test
```

**Playwright Tests (Comprehensive)**:
```bash
npm test
```

## Test Structure

### Shell Script Tests (`smoke-test-runner.sh`)
- **Fast**: Completes in ~10 seconds
- **Comprehensive**: Tests all critical components
- **CI/CD Ready**: Returns proper exit codes
- **Minimal Dependencies**: Only requires curl and bash

### Playwright Tests (`smoke-tests.spec.ts`)
- **Detailed**: Full assertions and error reporting  
- **Browser-based**: Tests actual HTTP endpoints
- **Reporting**: Generates HTML and JUnit reports
- **Debugging**: Screenshots on failure, trace collection

## Test Coverage

### Database Infrastructure
```sql
✅ pgvector extension installed
✅ documents table with embedding column (1536 dimensions)
✅ HNSW index optimized for vector similarity
✅ Unique checksum constraint for idempotent writes
✅ RLS policies for authenticated access only
```

### Functions & Procedures
```sql
✅ match_documents(embedding, threshold, count) 
✅ upsert_document(title, content, metadata, ...)
✅ get_conversation_context(conversation_id, limit)
✅ maintain_vector_index()
```

### Edge Functions
```typescript
✅ /functions/v1/process-documents
✅ /functions/v1/ai-generate-insight  
✅ CORS headers properly configured
✅ Authentication middleware working
```

### Chat System
```sql
✅ chat_conversations table with RLS
✅ chat_messages table with RLS
✅ Proper foreign key relationships
✅ User isolation policies
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SUPABASE_URL` | Supabase project URL | ✅ |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key for admin operations | ✅ |
| `OPENAI_API_KEY` | OpenAI API key for full E2E testing | Optional |

## Running Tests

### Local Development
```bash
# Quick smoke test
npm run smoke-test

# Full test suite
npm test

# Debug mode (opens browser)
npm run test:debug

# UI mode (interactive)
npm run test:ui
```

### CI/CD Pipeline
```yaml
# GitHub Actions example
- name: Run RAG Smoke Tests
  env:
    SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
    SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
  run: |
    cd tests/rag
    npm install
    npm run smoke-test
```

## Expected Results

### Success Output
```bash
🔍 RAG Pipeline Smoke Tests
==========================
1. Testing Supabase connectivity...
✅ Supabase connectivity verified

2. Testing pgvector extension...
✅ pgvector extension is installed

3. Testing HNSW index on documents table...
✅ HNSW index exists on documents table

4. Testing match_documents function...
✅ match_documents function is callable

5. Testing upsert_document function...
✅ upsert_document function works

6. Testing process-documents edge function...
✅ process-documents edge function is deployed and responding

7. Testing ai-generate-insight edge function...
✅ ai-generate-insight edge function is deployed and working

8. Testing RLS policies...
✅ RLS policies are configured (2 policies found)

9. Testing chat system tables...
✅ chat_conversations table exists and is accessible
✅ chat_messages table exists and is accessible

🎉 All RAG Pipeline Smoke Tests Passed!

🚀 RAG pipeline is ready for production use!
```

### Failure Scenarios

**Missing pgvector extension**:
```bash
❌ pgvector extension test failed
```
*Solution*: Enable pgvector in Supabase Dashboard → Extensions

**Missing HNSW index**:
```bash
❌ HNSW index test failed
```
*Solution*: Run the RAG hardening migration

**Edge function not deployed**:
```bash
❌ process-documents edge function test failed
```
*Solution*: Deploy edge functions with `supabase functions deploy`

## Troubleshooting

### Common Issues

1. **Authentication Error**
   ```bash
   ❌ Supabase connectivity failed (HTTP 401)
   ```
   - Check `SUPABASE_SERVICE_ROLE_KEY` is correct
   - Verify service role has proper permissions

2. **Missing Dependencies**
   ```bash
   ❌ pgvector extension test failed
   ```
   - Enable pgvector extension in Supabase Dashboard
   - Run RAG hardening migration

3. **Function Deployment**
   ```bash
   ❌ Edge function test failed
   ```
   - Deploy functions: `supabase functions deploy --all`
   - Check function logs in Supabase Dashboard

### Debug Mode

Run tests in debug mode for detailed output:
```bash
npm run test:debug
```

This will:
- Open browser for visual debugging
- Pause on failures
- Show detailed error messages
- Generate trace files

## Integration with Scout Dashboard

These smoke tests validate the RAG components that power:

- **InsightCard**: AI-powered business insights in dashboard tiles
- **Chat System**: RAG-powered conversational interface  
- **Knowledge Base**: Document storage and vector search
- **Context-Aware Analytics**: Business metrics + knowledge retrieval

## Maintenance

### Regular Maintenance
- Run smoke tests after any database schema changes
- Validate after Supabase version upgrades
- Test before production deployments

### Performance Monitoring
- Monitor test execution time (should be < 30 seconds)
- Watch for vector index performance degradation
- Track document processing throughput

### Updating Tests
- Add new tests when RAG features are added
- Update assertions when schema changes
- Maintain test data cleanup procedures