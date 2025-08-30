# @scout/ai-cookbook

Structured AI tooling for TBWA enterprise platform. Provides JSON guards, retry logic, observability, and typed MCP contracts to ensure 100% reliable AI operations.

## Features

- **🛡️ JSON Guards**: Zod-based validation with prose contamination prevention
- **🔄 Retry Logic**: Exponential backoff with circuit breaker patterns
- **📊 Observability**: OpenTelemetry integration with cost/latency tracking
- **🔌 MCP Contracts**: Type-safe tool interfaces for Supabase, Figma, GitHub
- **📈 Adapters**: Hardened wrappers for common MCP operations

## Installation

```bash
pnpm add @scout/ai-cookbook
```

## Quick Start

### JSON Guards

Eliminate prose contamination and ensure 100% JSON conformance:

```typescript
import { createJSONGuard } from '@scout/ai-cookbook';
import { z } from 'zod';

const componentSchema = z.object({
  name: z.string(),
  props: z.record(z.string(), z.any()),
});

const guard = createJSONGuard(componentSchema);

// Validates and extracts JSON from AI responses
const result = guard.validate('Here is your component: {"name": "Button", "props": {"onClick": "function"}}');
// Returns: { name: "Button", props: { onClick: "function" } }

// Add prefill to prompts for better conformance
const prompt = guard.prefill('Generate a React component');
// Returns: "Generate a React component\n\nRespond with JSON only, no explanation:\n{"
```

### Retry Logic

Automatic retry with exponential backoff for MCP operations:

```typescript
import { withRetry } from '@scout/ai-cookbook';

const resilientOperation = withRetry(
  async () => {
    return await mcpTool('supabase:execute_sql', { query: 'SELECT * FROM users' });
  },
  {
    retries: 3,
    factor: 2,
    minTimeout: 1000,
    maxTimeout: 5000,
  }
);

const result = await resilientOperation();
```

### MCP Adapters

Pre-built adapters with error mapping and observability:

```typescript
import { SupabaseAdapter } from '@scout/ai-cookbook/adapters';

const supabase = new SupabaseAdapter(
  'your-project-ref',
  'your-access-token',
  mcpExecute
);

// Automatic retry, error mapping, and cost tracking
const tables = await supabase.listTables('public');
const result = await supabase.executeSQL('SELECT * FROM users WHERE active = true');
```

### Observability

Track AI operation costs and performance:

```typescript
import { trackCost, withObservability } from '@scout/ai-cookbook';

const operation = trackCost('figma:generate_component');
const startTime = operation.start();

try {
  const result = await generateComponent();
  operation.end({
    model: 'claude-3-5-sonnet',
    input_tokens: 150,
    output_tokens: 500,
    success: true,
  });
} catch (error) {
  operation.end({
    success: false,
    error: error.message,
  });
}

// Or use the wrapper
const instrumentedFunction = withObservability(
  'component_generation',
  'claude-3-5-sonnet',
  generateComponent
);
```

## Pre-built Guards

Common validation patterns ready to use:

```typescript
import { guards } from '@scout/ai-cookbook/guards';

// Component generation
const component = guards.component.validate(aiResponse);

// Database schema
const schema = guards.schema.validate(aiResponse);

// Migration files
const migration = guards.migration.validate(aiResponse);

// Analytics queries
const query = guards.analytics.validate(aiResponse);

// Task orchestration
const tasks = guards.task.validate(aiResponse);

// Diagram generation
const diagram = guards.diagram.validate(aiResponse);
```

## MCP Tool Contracts

Type-safe contracts for all MCP tools:

```typescript
import { validateMCPCall, validateMCPResult, mcpContracts } from '@scout/ai-cookbook/mcp-contracts';

// Validate tool inputs
const validInput = validateMCPCall('supabase', 'mcp__supabase__execute_sql', {
  query: 'SELECT * FROM users',
});

// Validate tool outputs
const validOutput = validateMCPResult('supabase', 'mcp__supabase__execute_sql', result);

// Get contract definitions
const contract = mcpContracts.supabase['mcp__supabase__execute_sql'];
```

## Error Handling

Common error patterns are automatically mapped:

```typescript
// PostgreSQL errors → User-friendly messages
// 42P01 → "Table or view does not exist. Check schema and table name."
// 42703 → "Column does not exist. Check column names in query."
// 23505 → "Duplicate key violation. Record already exists."

// Figma timeouts → Graceful fallback with suggestions
// Network errors → Automatic retry with exponential backoff
// Rate limits → Circuit breaker with backoff
```

## Integration Examples

### Claude Desktop MCP

```json
{
  "mcpServers": {
    "diagram-bridge": {
      "command": "npx",
      "args": ["@scout/diagram-bridge-mcp"],
      "env": {
        "KROKI_URL": "https://kroki.io"
      }
    }
  }
}
```

### CI/CD Validation

```bash
# Validate Code Connect mappings
node scripts/validate-code-connect.js

# Test JSON conformance
pnpm test:json-guards

# Check accessibility compliance  
pnpm test:a11y
```

## Development

```bash
# Install dependencies
pnpm install

# Build package
pnpm build

# Run tests
pnpm test

# Type check
pnpm type-check

# Lint
pnpm lint
```

## Architecture

- **Guards**: Zod schemas with JSON extraction and validation
- **Adapters**: Retry-enabled wrappers for MCP tools with error mapping
- **Contracts**: Type-safe interfaces ensuring tool consistency
- **Observability**: OpenTelemetry spans with cost calculation
- **Core**: Shared utilities for JSON parsing, retry logic, and tracking

## License

MIT - TBWA Enterprise Platform