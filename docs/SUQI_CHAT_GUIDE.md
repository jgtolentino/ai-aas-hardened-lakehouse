# Suqi Chat - AI-Powered Analytics Interface

## Overview

Suqi Chat is an intelligent natural language interface for the Scout Analytics Platform, powered by GPT-4 and RAG (Retrieval-Augmented Generation). It allows users to query complex analytics data using conversational language.

## Key Features

- **Natural Language Queries**: Ask questions in plain English about your data
- **Intelligent Context**: RAG-powered responses with source citations
- **Platform-Based Access Control**: Different capabilities for different user roles
- **Response Caching**: Sub-second responses for repeated queries
- **Usage Analytics**: Track AI costs and performance
- **Dual Orchestration Modes**: Database or Node.js processing

## Architecture

### Components

1. **AI Corpus**: Vector database of domain knowledge and documentation
2. **Query Processor**: Natural language understanding and SQL generation
3. **RAG Engine**: Semantic search and context retrieval
4. **Response Cache**: Query result caching for performance
5. **Usage Tracker**: Token counting and cost management

### Data Flow

```
User Query → Embedding Generation → Vector Search → Context Retrieval
    ↓                                                       ↓
LLM Processing ← Context Enhancement ← Document Ranking ←──┘
    ↓
Response Generation → Caching → Streaming to User
```

## Configuration

### Environment Variables

```bash
# Orchestration mode
SUQI_CHAT_MODE=db  # 'db' or 'node'

# OpenAI Configuration (for node mode)
OPENAI_API_KEY=your-openai-api-key
OPENAI_API_URL=https://api.openai.com

# Performance Settings
SUQI_P95_TARGET_MS=2000
SUQI_CACHE_TTL_HOURS=24

# Platform Settings
NEXT_PUBLIC_DEFAULT_PLATFORM=analytics
```

### Database Setup

1. **Enable pgvector extension**:
```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

2. **Apply migrations**:
```bash
psql $DATABASE_URL -f supabase/migrations/20240118000001_fix_production_blockers.sql
```

3. **Verify setup**:
```bash
psql $DATABASE_URL -f scripts/validate_production_readiness.sql
```

## Usage Examples

### Basic Query

```javascript
const response = await supabase.rpc('ask_suqi_query', {
  question: "What were our top performing stores last month?",
  context_limit: 10,
  use_cache: true
});

console.log(response.data.answer);
// "Based on last month's data, the top performing stores were:
//  1. Store S123 in Makati - ₱2.5M revenue
//  2. Store S456 in BGC - ₱2.1M revenue..."
```

### Advanced Query with Metadata

```javascript
const response = await supabase.rpc('ask_suqi_query', {
  question: "Compare Q3 vs Q4 sales performance by region",
  context_limit: 15,
  include_metadata: true,
  search_depth: 10
});

// Access detailed metrics
console.log(response.data.usage);
// { prompt_tokens: 450, completion_tokens: 320, total_tokens: 770 }
```

### Streaming Response (Web App)

```javascript
const response = await fetch('/api/ask-suqi', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'x-platform': 'analytics'
  },
  body: JSON.stringify({
    question: "Show me customer retention trends"
  })
});

// Process streaming response
const reader = response.body.getReader();
// ... (see API documentation for full example)
```

## Platform Gating

Different platforms have different access levels:

### Analytics Platform (`x-platform: analytics`)
- Full read-only SQL capabilities
- Access to all data schemas
- Can execute analytical queries
- Example: "Show revenue by store for last quarter"

### Docs Platform (`x-platform: docs`)
- Restricted mode - no direct SQL
- Documentation and help queries only
- Cannot access raw data
- Example: "How do I calculate customer lifetime value?"

### Admin Platform (`x-platform: admin`)
- Full access (requires elevated permissions)
- Can execute write operations
- System configuration queries
- Example: "Update cache TTL to 48 hours"

## Security Features

### JWT Validation
- Tenant/vendor isolation enforced at database level
- Parameters must match JWT claims
- Cross-tenant queries blocked

### SQL Injection Prevention
- Parameterized queries only
- Platform-based SQL keyword blocking
- Query validation before execution

### Rate Limiting
- Per-user query limits
- Token-based throttling
- Cost-based restrictions

## Performance Optimization

### Caching Strategy
- 24-hour cache TTL by default
- Cache key: MD5(question + tenant + vendor)
- Automatic cache invalidation on data updates

### Embedding Optimization
- Pre-computed embeddings for common queries
- Batch embedding generation
- Vector index with HNSW algorithm

### Query Performance Targets
- P50: < 1200ms
- P95: < 2000ms
- P99: < 2500ms
- Cache hit rate: > 30%

## Monitoring

### Performance Metrics

```sql
SELECT * FROM public.get_suqi_performance_metrics();
```

Returns:
- Average response time
- Percentile metrics (P50, P95, P99)
- Cache hit rate
- Query volume (24h)
- Unique users (24h)

### Usage Analytics

```sql
SELECT * FROM public.get_suqi_usage_stats('2024-01-01', '2024-01-31');
```

Returns daily:
- Query count
- Token usage
- Cost in USD
- Average response time

### Error Tracking

Monitor errors via telemetry:
```javascript
// Errors are automatically tracked
telemetry.error('Query failed', { 
  question: userQuestion, 
  error: errorMessage 
});
```

## Troubleshooting

### Common Issues

1. **High Latency**
   - Check cache hit rate
   - Verify vector indexes
   - Monitor embedding generation time

2. **Access Denied Errors**
   - Verify x-platform header
   - Check JWT claims
   - Confirm RLS policies

3. **Empty Responses**
   - Check AI corpus content
   - Verify embedding dimensions
   - Review context retrieval

### Debug Mode

Enable debug logging:
```javascript
const response = await supabase.rpc('ask_suqi_query', {
  question: "Debug: Show query plan",
  include_metadata: true,
  debug: true  // Returns query execution details
});
```

## Best Practices

1. **Query Design**
   - Be specific and concise
   - Include time ranges when relevant
   - Use domain terminology

2. **Performance**
   - Enable caching for repeated queries
   - Limit context to necessary documents
   - Batch related queries when possible

3. **Cost Management**
   - Monitor token usage daily
   - Set up usage alerts
   - Use caching aggressively

4. **Security**
   - Always set platform headers
   - Validate user permissions
   - Audit sensitive queries

## API Reference

See [API Documentation](../API_DOCUMENTATION.md#suqi-chat-ai-interface) for complete endpoint details.

## Roadmap

- [ ] Multi-language support
- [ ] Voice input capabilities
- [ ] Visualization generation
- [ ] Custom model fine-tuning
- [ ] Offline mode support