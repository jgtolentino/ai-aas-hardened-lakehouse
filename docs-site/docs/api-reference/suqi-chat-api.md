---
sidebar_position: 5
title: Suqi Chat API Reference
---

# Suqi Chat API Reference

Complete API documentation for the Suqi Chat natural language interface.

## Base URL

```
https://{project-ref}.supabase.co/rest/v1/rpc
```

## Authentication

All requests require authentication via API key or JWT token:

```http
apikey: {SUPABASE_ANON_KEY}
Authorization: Bearer {SUPABASE_ANON_KEY}
Content-Type: application/json
x-platform: analytics  # Required for platform gating
```

## Endpoints

### ask_suqi_query

Submit natural language questions about your data.

**POST** `/ask_suqi_query`

#### Request Body

```typescript
interface AskSuqiRequest {
  question: string;           // Natural language query
  context_limit?: number;     // Max documents to retrieve (default: 10)
  include_metadata?: boolean; // Include usage metrics (default: false)
  use_cache?: boolean;        // Use cached responses (default: true)
  search_depth?: number;      // RAG search depth (default: 5)
  p_tenant_id?: string;       // Tenant ID (auto-filled from JWT)
  p_vendor_id?: string;       // Vendor ID (auto-filled from JWT)
}
```

#### Response

```typescript
interface AskSuqiResponse {
  answer: string;              // AI-generated response
  sources: Array<{             // Source documents used
    id: string;
    title: string;
    chunk: string;
    score?: number;
  }>;
  usage?: {                    // Token usage metrics
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
    embedding_tokens: number;
  };
  cached: boolean;             // Whether response was cached
  response_time_ms: number;    // Processing time
  platform: string;            // Platform context
}
```

#### Example Request

```bash
curl -X POST https://your-project.supabase.co/rest/v1/rpc/ask_suqi_query \
  -H "apikey: your-anon-key" \
  -H "Authorization: Bearer your-anon-key" \
  -H "Content-Type: application/json" \
  -H "x-platform: analytics" \
  -d '{
    "question": "What were the top 5 stores by revenue last month?",
    "context_limit": 10,
    "include_metadata": true
  }'
```

#### Example Response

```json
{
  "answer": "Based on last month's data (December 2023), the top 5 stores by revenue were:\n\n1. **Store S001 - Makati Central** - ₱2,547,320\n2. **Store S015 - BGC High Street** - ₱2,103,450\n3. **Store S023 - Cebu IT Park** - ₱1,892,100\n4. **Store S007 - Ortigas Center** - ₱1,756,890\n5. **Store S031 - Davao Downtown** - ₱1,623,440\n\nThese stores accounted for 35% of total revenue across all locations.",
  "sources": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "title": "Monthly Revenue Report - December 2023",
      "chunk": "Store performance metrics show Makati Central (S001) leading with ₱2,547,320 in revenue...",
      "score": 0.92
    }
  ],
  "usage": {
    "prompt_tokens": 523,
    "completion_tokens": 187,
    "total_tokens": 710,
    "embedding_tokens": 50
  },
  "cached": false,
  "response_time_ms": 1847,
  "platform": "analytics"
}
```

### search_ai_corpus

Search for relevant documents using semantic similarity.

**POST** `/search_ai_corpus`

#### Request Body

```typescript
interface SearchCorpusRequest {
  p_tenant_id: string;      // Tenant ID
  p_vendor_id?: string;     // Optional vendor filter
  p_qvec: number[];         // 1536-dimensional embedding vector
  p_k?: number;             // Number of results (default: 6)
}
```

#### Response

```typescript
interface SearchCorpusResponse {
  id: string;               // Document ID
  title: string;            // Document title
  chunk: string;            // Text content
}[]
```

#### Example Request

```javascript
// First generate embedding
const embedding = await generateEmbedding("revenue analysis");

// Then search
const response = await supabase.rpc('search_ai_corpus', {
  p_tenant_id: 'default',
  p_vendor_id: null,
  p_qvec: embedding,
  p_k: 5
});
```

### get_suqi_chat_history

Retrieve previous chat interactions.

**POST** `/get_suqi_chat_history`

#### Request Body

```typescript
interface ChatHistoryRequest {
  p_limit?: number;         // Max results (default: 50)
  p_offset?: number;        // Pagination offset (default: 0)
}
```

#### Response

```typescript
interface ChatHistoryResponse {
  id: string;
  question: string;
  answer: object;
  sources: object[];
  created_at: string;
  response_time_ms: number;
}[]
```

#### Example Response

```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "question": "What was our best performing region last quarter?",
    "answer": {
      "text": "Metro Manila was the best performing region in Q4 2023..."
    },
    "sources": [
      {
        "id": "doc_001",
        "title": "Q4 Regional Performance Report"
      }
    ],
    "created_at": "2024-01-15T10:30:00Z",
    "response_time_ms": 1523
  }
]
```

### get_suqi_usage_stats

Monitor AI usage and costs over time.

**POST** `/get_suqi_usage_stats`

#### Request Body

```typescript
interface UsageStatsRequest {
  p_start_date?: string;    // Start date (default: 30 days ago)
  p_end_date?: string;      // End date (default: today)
}
```

#### Response

```typescript
interface UsageStatsResponse {
  date: string;
  queries_count: number;
  tokens_used: number;
  cost_usd: number;
  avg_response_time_ms: number;
}[]
```

#### Example Request

```bash
curl -X POST https://your-project.supabase.co/rest/v1/rpc/get_suqi_usage_stats \
  -H "apikey: your-anon-key" \
  -H "Authorization: Bearer your-anon-key" \
  -H "Content-Type: application/json" \
  -d '{
    "p_start_date": "2024-01-01",
    "p_end_date": "2024-01-31"
  }'
```

### get_suqi_performance_metrics

Get real-time performance metrics.

**POST** `/get_suqi_performance_metrics`

#### Request Body

No parameters required.

#### Response

```typescript
interface PerformanceMetricsResponse {
  avg_response_time_ms: number;
  p50_response_time_ms: number;
  p95_response_time_ms: number;
  p99_response_time_ms: number;
  cache_hit_rate: number;
  total_queries_24h: number;
  unique_users_24h: number;
}
```

#### Example Response

```json
{
  "avg_response_time_ms": 1650,
  "p50_response_time_ms": 1200,
  "p95_response_time_ms": 1950,
  "p99_response_time_ms": 2500,
  "cache_hit_rate": 0.35,
  "total_queries_24h": 1250,
  "unique_users_24h": 45
}
```

### track_event

Track telemetry events for analytics.

**POST** `/track_event`

#### Request Body

```typescript
interface TrackEventRequest {
  event_name: string;       // Event name (e.g., "Suqi.Query")
  properties?: object;      // Event properties
  p_tenant_id?: string;     // Tenant ID
  p_vendor_id?: string;     // Vendor ID
}
```

#### Response

No response body (void function).

#### Example

```javascript
await supabase.rpc('track_event', {
  event_name: 'Suqi.Query',
  properties: {
    question_length: 45,
    response_time: 1523,
    cache_hit: false
  }
});
```

## Error Responses

### Standard Error Format

```json
{
  "code": "42501",
  "details": null,
  "hint": null,
  "message": "insufficient_privilege"
}
```

### Common Error Codes

| Code | Description | Resolution |
|------|-------------|------------|
| `42501` | Insufficient privilege | Check platform header and permissions |
| `P0001` | Tenant mismatch | Ensure tenant_id matches JWT |
| `22P02` | Invalid input syntax | Check query parameters |
| `23505` | Duplicate key | Query already cached |
| `54000` | Program limit exceeded | Token limit reached |

## Platform Gating

The `x-platform` header controls access levels:

### Analytics Platform

```http
x-platform: analytics
```

- ✅ Full read-only SQL queries
- ✅ Access to all analytics data
- ✅ Advanced query capabilities

### Docs Platform

```http
x-platform: docs
```

- ❌ No direct SQL execution
- ✅ Documentation queries only
- ✅ Help and guidance responses

### Example Platform Check

```bash
# Analytics platform - allowed
curl -X POST .../ask_suqi_query \
  -H "x-platform: analytics" \
  -d '{"question": "SELECT COUNT(*) FROM transactions"}'
# Response: 200 OK with results

# Docs platform - denied
curl -X POST .../ask_suqi_query \
  -H "x-platform: docs" \
  -d '{"question": "SELECT COUNT(*) FROM transactions"}'
# Response: 403 Forbidden
```

## Rate Limits

| Endpoint | Rate Limit | Window |
|----------|------------|--------|
| ask_suqi_query | 100 requests | 1 hour |
| search_ai_corpus | 500 requests | 1 hour |
| get_suqi_chat_history | 200 requests | 1 hour |
| get_suqi_usage_stats | 50 requests | 1 hour |

## SDK Examples

### JavaScript/TypeScript

```typescript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(url, key);

// Ask a question
const { data, error } = await supabase.rpc('ask_suqi_query', {
  question: 'What are the revenue trends?',
  context_limit: 10
});

if (error) {
  console.error('Error:', error.message);
} else {
  console.log('Answer:', data.answer);
}
```

### Python

```python
from supabase import create_client

supabase = create_client(url, key)

# Ask a question
response = supabase.rpc('ask_suqi_query', {
    'question': 'What are the revenue trends?',
    'context_limit': 10
}).execute()

print(f"Answer: {response.data['answer']}")
```

### cURL

```bash
curl -X POST https://your-project.supabase.co/rest/v1/rpc/ask_suqi_query \
  -H "apikey: $SUPABASE_KEY" \
  -H "Authorization: Bearer $SUPABASE_KEY" \
  -H "Content-Type: application/json" \
  -H "x-platform: analytics" \
  -d '{
    "question": "What are the revenue trends?"
  }'
```

## Best Practices

1. **Always set platform header**: Required for proper access control
2. **Use caching**: Enable `use_cache` for repeated queries
3. **Monitor usage**: Track tokens and costs regularly
4. **Handle errors gracefully**: Implement retry logic
5. **Optimize context**: Use appropriate `context_limit`

## Related Documentation

- [Suqi Chat Overview](/docs/features/suqi-chat)
- [Architecture](/docs/architecture/overview)
- [Security Guide](/docs/security/platform-gating)
- [Performance Tuning](/docs/operations/performance)