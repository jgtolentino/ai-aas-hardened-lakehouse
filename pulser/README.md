# Pulser Agent Registry & Orchestration

Pulser is the intelligent agent orchestration system for the AI-AAS Hardened Lakehouse. It provides a secure, scalable framework for registering, routing, and executing AI agents.

## Architecture

```
Request → Validation → Routing → Agent Selection → Execution (Bruno) → Response
                          ↓
                    Agent Registry
                          ↓
                 Metrics & Monitoring
```

## Core Components

### 1. Agent Registry
- Dynamic agent registration and discovery
- Health monitoring and metrics tracking
- Capability-based agent matching
- State management (idle, busy, error, offline)

### 2. Intelligent Routing
- **Capability-based**: Match agents by required capabilities
- **Load balancing**: Distribute work evenly
- **Type-based**: Route by request/agent type
- **Priority-based**: High-priority request handling

### 3. Security & Validation
- Request validation and sanitization
- Permission enforcement
- Sensitive data detection
- Sandboxed execution via Bruno

### 4. Monitoring & Metrics
- Success rate tracking
- Execution time monitoring
- Error counting and analysis
- Health check automation

## Quick Start

### Installation

```bash
# Install dependencies
npm install

# Initialize Pulser
npx pulser init
```

### CLI Usage

```bash
# List all agents
pulser agents

# Execute a task
pulser execute generate_prd --payload '{"title": "My Feature"}'

# Check agent health
pulser health

# View metrics
pulser metrics

# List jobs
pulser jobs --status completed
```

## Agent Configuration

Agents are defined in YAML files in the `pulser/agents/` directory:

```yaml
metadata:
  id: my-agent-v1
  name: MyAgent
  version: "1.0.0"
  description: "My custom agent"
  tags: ["custom", "example"]
  status: active

type: generator  # executor|transformer|analyzer|generator|validator
runtime: bruno   # bruno|node|python|deno

capabilities:
  - name: my_capability
    description: "What this capability does"
    inputSchema:
      type: object
      properties:
        input: { type: string }
    permissions:
      - file:read
      - file:write

security:
  sandboxed: true
  allowedHosts: []
  deniedActions: ["execute", "network"]

limits:
  maxExecutionTime: 300000  # 5 minutes
  maxMemoryMB: 512
  maxConcurrent: 3

routing:
  priority: 70
  patterns: ["my:*", "custom:*"]
```

## Built-in Agents

### Devstral
- **Purpose**: System architecture and PRD generation
- **Capabilities**: `generate_prd`, `design_architecture`, `scaffold_project`
- **Type**: Generator

### Dash
- **Purpose**: TypeScript/React UI development
- **Capabilities**: `codegen_tsx`, `create_chart`, `generate_form`
- **Type**: Generator

### Maya
- **Purpose**: Documentation generation
- **Capabilities**: `generate_docs`, `create_adr`, `generate_api_docs`
- **Type**: Generator

### SecurityScanner
- **Purpose**: Security vulnerability scanning
- **Capabilities**: `scan_repository`, `audit_dependencies`, `check_secrets`
- **Type**: Analyzer

## API Usage

```typescript
import { pulser } from './pulser/pulser';
import type { RoutingRequest } from './pulser/routing/router';

// Initialize Pulser
await pulser.initialize();

// Execute a request
const request: RoutingRequest = {
  type: 'task',
  category: 'generate_prd',
  payload: {
    title: 'User Authentication System',
    requirements: ['OAuth2', 'MFA', 'Session Management']
  },
  context: {
    priority: 'high',
    timeout: 60000
  }
};

const result = await pulser.execute(request);
```

## Routing Strategies

### Capability-Based (Default)
Routes to agents that have all required capabilities, scoring by:
- Number of capabilities
- Success rate
- Error count
- Availability

### Load Balancing
Distributes work to the least busy agents based on total executions.

### Type-Based
Matches request types to appropriate agent types:
- `task` → executor, transformer
- `query` → analyzer, validator
- `command` → executor, generator

### Priority-Based
Routes high-priority requests to high-priority agents.

## Security Model

### Permission System
- Granular permission model (e.g., `file:read`, `network:api`)
- Capability-specific permissions
- Runtime permission validation

### Sandboxing
- All agents run sandboxed by default
- Bruno provides secure execution environment
- Network access restricted to allowed hosts

### Validation
- Input validation on all requests
- Payload size limits (10MB default)
- Sensitive data detection and redaction

## Configuration

### Environment Variables
```bash
# Pulser configuration
PULSER_CONFIG=/path/to/pulser.config.json

# Bruno integration
BRUNO_ENDPOINT=http://localhost:8080

# Node environment
NODE_ENV=production
```

### Configuration File
Create `pulser.config.json`:

```json
{
  "registry": {
    "dataPath": "./pulser/registry/data",
    "autoSave": true
  },
  "routing": {
    "defaultStrategy": "capability-based",
    "timeoutMs": 30000
  },
  "execution": {
    "defaultExecutor": "bruno",
    "maxConcurrentJobs": 10
  },
  "security": {
    "enforcePermissions": true,
    "auditLogging": true
  }
}
```

## Monitoring

### Metrics Available
- Total/active/queued jobs
- Agent success rates
- Average execution times
- Error counts
- Health status

### Health Checks
- Automatic periodic health checks
- Manual health check via CLI
- Health status in agent registry

### Event System
Pulser emits events for key operations:
- `initialized`
- `agent:registered`
- `job:created`
- `job:completed`
- `job:failed`

## Development

### Creating Custom Agents

1. Create agent configuration in `pulser/agents/`
2. Define capabilities and permissions
3. Implement execution logic (if custom runtime)
4. Register with Pulser

### Adding Routing Strategies

```typescript
import { RoutingStrategy } from './pulser/routing/router';

class CustomStrategy implements RoutingStrategy {
  name = 'custom';
  
  evaluate(request, agents) {
    // Custom routing logic
    return {
      agentId: selectedAgent.id,
      score: 100,
      reason: 'Custom selection'
    };
  }
}

router.registerStrategy(new CustomStrategy());
```

### Testing

```bash
# Run tests
npm test pulser/

# Test specific agent
npm test pulser/tests/agents/devstral.test.ts
```

## Troubleshooting

### Agent Not Found
- Check agent file is in correct location
- Verify YAML/JSON syntax
- Ensure agent ID is unique

### Routing Failures
- Verify agents are active
- Check capability requirements
- Review routing strategy logs

### Permission Denied
- Check agent permissions match requirements
- Verify security configuration
- Review audit logs

### Performance Issues
- Monitor concurrent job limits
- Check agent execution times
- Review memory limits

## Integration with SuperClaude

Pulser integrates with SuperClaude personas:

```typescript
// SuperClaude → Pulser mapping
"System Architect" → Devstral
"Frontend Developer" → Dash
"Scribe" → Maya
"Security Engineer" → SecurityScanner
```

All SuperClaude commands are routed through Pulser for secure execution.

## Future Enhancements

- [ ] Python runtime support
- [ ] Deno runtime support
- [ ] Distributed agent execution
- [ ] Advanced scheduling
- [ ] Agent versioning
- [ ] Hot reload capabilities
- [ ] GraphQL API
- [ ] WebSocket support