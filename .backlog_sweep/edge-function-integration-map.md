# Edge Function Integration Map

**Generated**: 2025-08-29  
**Purpose**: Map deployed edge functions to Scout UI features  
**Status**: 7 edge functions analyzed, 7 backlog items created

## 🔗 Edge Function → Scout UI Feature Mapping

### 1. AI-Generated Insights (`ai-generate-insight`)
- **Backlog ID**: SCOUT-BL-011
- **Edge Function**: `/supabase/functions/ai-generate-insight/index.ts`
- **API Endpoint**: `POST /functions/v1/ai-generate-insight`
- **UI Integration Points**:
  - **Dashboard**: AI insights panel with confidence indicators
  - **Cards**: Contextual insight tooltips on KPI cards
  - **Chat Interface**: AI assistant with RAG-powered responses
  - **Action Items**: Smart recommendations with business priority
- **Key Capabilities**:
  - RAG-powered business intelligence
  - Confidence scoring (0-100%)
  - Action item generation with priorities
  - Source attribution and evidence
  - Multi-model AI support (GPT-4o-mini)

### 2. Natural Language Queries (`semantic-calc`)  
- **Backlog ID**: SCOUT-BL-012
- **Edge Function**: `/supabase/functions/semantic-calc/index.ts`
- **API Endpoint**: `POST /functions/v1/semantic-calc`
- **UI Integration Points**:
  - **Search Bar**: Natural language query input
  - **Query Builder**: "Ask in plain English" mode
  - **Metrics Cards**: NL-powered custom calculations
  - **Report Builder**: Natural language report descriptions
- **Key Capabilities**:
  - Natural language to SQL translation
  - Real-time query interpretation
  - Source schema awareness (`scout.gold_daily_metrics`)
  - Query validation and error handling

### 3. Smart Search (`semantic-suggest`)
- **Backlog ID**: SCOUT-BL-013  
- **Edge Function**: `/supabase/functions/semantic-suggest/index.ts`
- **API Endpoint**: `GET /functions/v1/semantic-suggest`
- **UI Integration Points**:
  - **Global Search**: Intelligent search suggestions
  - **Filter Dropdowns**: Context-aware filter suggestions
  - **Navigation**: Smart page/section recommendations
  - **Quick Actions**: Suggested workflows based on context
- **Key Capabilities**:
  - Context-aware search suggestions
  - Source-based filtering
  - Real-time semantic matching
  - Search result relevance scoring

### 4. Advanced Query Builder (`semantic-proxy`)
- **Backlog ID**: SCOUT-BL-014
- **Edge Function**: `/supabase/functions/semantic-proxy/index.ts`  
- **API Endpoint**: `POST /functions/v1/semantic-proxy`
- **UI Integration Points**:
  - **Analytics Page**: Visual query builder interface
  - **Dashboard Builder**: Drag-and-drop metric configuration
  - **Advanced Filters**: Objects/metrics/groupBy interface
  - **Data Explorer**: Interactive schema navigation
- **Key Capabilities**:
  - Structured semantic queries (objects + metrics + filters)
  - Group-by operations with semantic understanding
  - Query preview and estimation
  - Advanced filter combinations

### 5. Enhanced Data Export (`export-platinum`)
- **Backlog ID**: SCOUT-BL-015
- **Edge Function**: `/supabase/functions/export-platinum/index.ts`
- **API Endpoint**: `GET /functions/v1/export-platinum`
- **UI Integration Points**:
  - **Export Menu**: Multi-format export options
  - **Dashboard Actions**: Export current view as CSV/JSON
  - **Reports Page**: Scheduled export management
  - **Data Science Hub**: ML features and GenieView exports
- **Key Capabilities**:
  - Multiple export formats (CSV, JSON, GenieView)
  - Daily transactions and store rankings
  - ML feature exports for data science
  - Natural language summaries (GenieView)
  - Export manifest and scheduling

### 6. File Upload & Ingestion (`ingest-bronze`)
- **Backlog ID**: SCOUT-BL-016
- **Edge Function**: `/supabase/functions/ingest-bronze/index.ts`
- **API Endpoint**: Webhook trigger from Supabase Storage
- **UI Integration Points**:
  - **Data Upload Page**: Drag-and-drop file interface
  - **Settings**: Device registration and file management
  - **Data Pipeline**: Ingestion status and monitoring
  - **Preview Mode**: File content validation before processing
- **Key Capabilities**:
  - CSV/JSON file processing
  - Device ID extraction and validation
  - Bronze layer medallion architecture integration
  - Real-time ingestion status tracking
  - Automatic downstream processing triggers

### 7. Knowledge Management (`process-documents`)
- **Backlog ID**: SCOUT-BL-017
- **Edge Function**: `/supabase/functions/process-documents/index.ts`
- **API Endpoint**: `POST /functions/v1/process-documents`
- **UI Integration Points**:
  - **Knowledge Base**: Document upload and management
  - **Help System**: AI-powered contextual help
  - **Settings**: Document processing configuration
  - **Search**: Knowledge base search integration
- **Key Capabilities**:
  - HTML/Markdown/text processing
  - Automatic content chunking with overlap
  - OpenAI embeddings for semantic search
  - Content deduplication with checksums
  - Multi-format document support

## 📊 Integration Priority Matrix

| Edge Function | UI Priority | Technical Risk | Business Value | Ready Status |
|---------------|-------------|----------------|----------------|--------------|
| `ai-generate-insight` | P1 | Medium | High | Ready ✅ |
| `semantic-calc` | P1 | High | Very High | Ready ✅ |
| `semantic-suggest` | P1 | Low | High | Ready ✅ |
| `semantic-proxy` | P2 | Medium | High | Ready ✅ |
| `export-platinum` | P2 | Low | Medium | Ready ✅ |
| `ingest-bronze` | P2 | Medium | Medium | Ready ✅ |
| `process-documents` | P2 | Medium | Medium | Ready ✅ |

## 🚀 Implementation Roadmap

### Phase 1: Core AI Features (v6.1)
- **SCOUT-BL-011**: AI-Powered Insights Panel
- **SCOUT-BL-012**: Natural Language Query Interface  
- **SCOUT-BL-013**: Smart Search with Semantic Suggestions
- **SCOUT-BL-015**: Enhanced Data Export Center

### Phase 2: Advanced Analytics (v6.2)
- **SCOUT-BL-014**: Advanced Semantic Query Builder
- **SCOUT-BL-016**: File Upload & Data Ingestion UI

### Phase 3: Knowledge & Content (v6.3)  
- **SCOUT-BL-017**: Knowledge Base & Document Management

## 🛠️ Technical Integration Notes

### Authentication & Security
All edge functions use Supabase service role authentication:
```typescript
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)
```

### Error Handling Pattern
Consistent error handling across all functions:
```typescript
try {
  // Function logic
} catch (error) {
  console.error('Function error:', error)
  return new Response(JSON.stringify({ 
    error: error.message,
    timestamp: new Date().toISOString()
  }), { 
    status: 500,
    headers: corsHeaders 
  })
}
```

### CORS Configuration
All functions use consistent CORS headers for web integration:
```typescript
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
}
```

## 📋 Next Steps

1. **UI Component Development**: Create React components for each integration point
2. **API Client Setup**: Implement edge function client wrappers
3. **State Management**: Add Redux/Zustand state for edge function data
4. **Error Boundaries**: Implement UI error handling for edge function failures
5. **Performance Monitoring**: Add telemetry for edge function performance
6. **User Testing**: A/B test edge function features against existing UI

## 🔍 Edge Function Discovery Commands

To discover more edge functions in the future:
```bash
# List all edge functions
find supabase/functions -name "index.ts" -exec basename $(dirname {}) \;

# Analyze function capabilities  
grep -r "serve\|Deno.serve" supabase/functions/*/index.ts

# Check for new RPC functions
grep -r "supabase.rpc" supabase/functions/*/index.ts
```

---

**Integration Complete**: All 7 deployed edge functions mapped to Scout UI features  
**Backlog Updated**: SCOUT-BL-011 through SCOUT-BL-017 added  
**Status**: Ready for UI development and implementation