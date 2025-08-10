# Model Card: ingest-doc
## Auto-Generated from Edge Function Analysis

### Model Details
- **Function**: ingest-doc
- **Type**: Generation
- **Provider**: OpenAI
- **Version**: text-embedding-3-small

### Input/Output Schema
```typescript
// Auto-discovered from function signature
interface Input {
  texts: string[];
}

interface Output {
  embeddings: number[][];
}
```

### Performance Metrics
- **Latency p95**: < 2s
- **Throughput**: 100 req/min
- **Error Rate**: < 0.1%

### Privacy & Security
- No PII in prompts
- Results cached for 5 minutes
- Rate limited per user
