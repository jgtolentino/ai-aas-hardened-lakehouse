# Bruno - Secure Execution Engine

Bruno is the secure execution engine for the AI-AAS Hardened Lakehouse platform. It provides sandboxed execution of jobs with comprehensive security policies, resource limits, and audit logging.

## Architecture

```
Job Request → Policy Validation → Sandbox Creation → Execution → Cleanup
                     ↓                    ↓
              Security Events      Resource Monitoring
```

## Key Features

### 🔒 Security First
- **Policy Engine**: Configurable security policies with allow/deny rules
- **Sandboxing**: Docker or process isolation for all executions
- **Permission System**: Granular permissions (file, network, process, database)
- **Audit Logging**: Complete security event tracking

### 🚀 Execution Types
- **Shell Commands**: Safe command execution with validation
- **Scripts**: Node.js script execution in isolated environment
- **File Operations**: Controlled file system access
- **API Calls**: Network requests with host restrictions
- **Database Queries**: Integrated with Supabase MCP

### 📊 Resource Management
- CPU limits (configurable percentage)
- Memory limits (MB)
- Disk usage limits
- Network bandwidth control
- Execution timeouts

### 🔍 Monitoring & Auditing
- Real-time job tracking
- Security event logging
- Performance metrics
- Resource usage monitoring

## Quick Start

### CLI Usage

```bash
# Execute a shell command
bruno exec shell -c "echo 'Hello Bruno'" --permissions process:execute

# Run a script
bruno exec script -s ./my-script.js --permissions file:read file:write

# Use a template
bruno template generate-react-component -p '{"componentName": "MyButton"}'

# Check status
bruno status

# View security events
bruno security

# Run self-test
bruno test
```

### Programmatic Usage

```typescript
import { brunoExecutor } from './bruno/executor/bruno-executor';
import type { BrunoJob } from './bruno/executor/types';

// Define a job
const job: BrunoJob = {
  id: 'my-job-123',
  type: 'shell',
  command: 'npm test',
  permissions: ['process:execute', 'file:read'],
  timeout: 60000 // 1 minute
};

// Execute
const result = await brunoExecutor.execute(job);

if (result.status === 'success') {
  console.log('Output:', result.stdout);
} else {
  console.error('Failed:', result.error);
}
```

## Security Policies

### Default Policies

1. **Network Access**
   - Deny all external network by default
   - Allow localhost connections
   - Configurable trusted hosts

2. **File System**
   - Deny access to system directories
   - Allow workspace and /tmp access
   - Path traversal protection

3. **Process Execution**
   - Block dangerous commands (rm -rf /, sudo, etc.)
   - Allow safe commands (ls, cat, echo, node, npm)
   - Command validation

4. **Resource Limits**
   - CPU: 50% default
   - Memory: 512MB default
   - Disk: 1GB default
   - Timeout: 5 minutes default

### Custom Policies

Create custom policies:

```typescript
import { PolicyEngine } from './bruno/security/policy-engine';

const customPolicy: BrunoPolicy = {
  name: 'my-policy',
  description: 'Custom security policy',
  enforcement: 'strict',
  rules: [
    {
      id: 'allow-npm',
      type: 'allow',
      resource: 'process:*',
      actions: ['execute'],
      conditions: {
        command: { matches: ['npm *', 'yarn *'] }
      }
    }
  ]
};

policyEngine.addPolicy(customPolicy);
```

## Job Templates

Pre-configured job templates for common tasks:

- `generate-react-component` - Create React components
- `generate-readme` - Generate README files
- `security-scan-npm` - Run npm audit
- `run-unit-tests` - Execute test suites
- `build-production` - Production builds
- `format-code` - Code formatting
- `git-status` - Safe git operations

List all templates:
```bash
bruno template list
```

## Sandboxing

### Docker Sandbox (Recommended)
- Complete isolation
- Resource limits enforced by Docker
- Network isolation
- Read-only root filesystem

### Process Sandbox (Fallback)
- Process isolation
- Limited to platform capabilities
- Working directory isolation
- Environment variable sanitization

## Integration with Pulser

Bruno integrates seamlessly with Pulser agents:

```typescript
// In pulser/pulser.ts
import { updatePulserExecutor } from './bruno/executor/pulser-integration';

// Enable Bruno as executor
updatePulserExecutor();
```

All Pulser agent executions will automatically use Bruno's secure environment.

## Configuration

### Environment Variables
```bash
# Bruno configuration
BRUNO_CONFIG=/path/to/bruno.config.json
BRUNO_SANDBOX_TYPE=docker  # or 'process'
BRUNO_MAX_JOBS=10
BRUNO_LOG_LEVEL=info

# Docker settings
BRUNO_DOCKER_IMAGE=node:18-alpine
```

### Configuration File

Create `bruno.config.json`:

```json
{
  "executor": {
    "maxConcurrentJobs": 10,
    "defaultTimeout": 300000
  },
  "security": {
    "defaultPolicy": "strict",
    "enableNetworkAccess": false,
    "trustedHosts": ["localhost", "api.mycompany.com"]
  },
  "sandbox": {
    "type": "docker",
    "resources": {
      "cpuPercent": 50,
      "memoryMB": 1024
    }
  }
}
```

## Security Best Practices

1. **Least Privilege**: Only grant necessary permissions
2. **Input Validation**: Always validate job inputs
3. **Timeout Everything**: Set appropriate timeouts
4. **Monitor Events**: Regularly review security events
5. **Update Policies**: Keep security policies current
6. **Sandbox Always**: Never disable sandboxing
7. **Audit Regularly**: Review audit logs

## Troubleshooting

### Docker Not Available
- Bruno falls back to process isolation
- Install Docker for better security
- Check Docker daemon is running

### Permission Denied
- Verify job has required permissions
- Check security policy rules
- Review security event logs

### Resource Exceeded
- Increase resource limits in config
- Optimize job resource usage
- Check for resource leaks

### Timeout Issues
- Increase timeout for long-running jobs
- Break large jobs into smaller tasks
- Check for infinite loops

## API Reference

### BrunoJob
```typescript
interface BrunoJob {
  id: string;
  type: 'shell' | 'script' | 'file' | 'api' | 'database';
  command?: string;
  script?: string;
  payload?: any;
  permissions: string[];
  environment?: Record<string, string>;
  workingDirectory?: string;
  timeout?: number;
}
```

### BrunoResult
```typescript
interface BrunoResult {
  jobId: string;
  status: 'success' | 'failure' | 'timeout' | 'cancelled';
  exitCode?: number;
  stdout?: string;
  stderr?: string;
  error?: string;
  duration: number;
  securityEvents?: SecurityEvent[];
}
```

## Development

### Running Tests
```bash
npm test bruno/
```

### Adding New Job Types
1. Update `BrunoJob` type definition
2. Add execution handler in `bruno-executor.ts`
3. Add security policy rules
4. Create job template
5. Add tests

### Contributing
- Follow security-first principles
- Add tests for new features
- Update documentation
- Review security implications

## Future Enhancements

- [ ] WebAssembly sandbox support
- [ ] Distributed execution
- [ ] Job queuing system
- [ ] Advanced resource monitoring
- [ ] Policy versioning
- [ ] Encrypted job storage
- [ ] Multi-tenant support