# Model Card: genie-query
## Auto-Generated from Edge Function Analysis

### Model Details
- **Function**: genie-query
- **Type**: Generation
- **Provider**: OpenAI
- **Version**: GPT-4

### Input/Output Schema
```typescript
// Auto-discovered from function signature
interface Input {
  query: string;
}

interface Output {
  sql: string; results: any[];
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
