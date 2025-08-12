# SuperClaude Integration

This directory contains the secure integration of SuperClaude Framework v3 with our AI-AAS Hardened Lakehouse platform.

## Architecture

```
SuperClaude Personas → Adapter → Pulser Agents → Bruno (Executor)
                           ↓
                    Security Guards
                           ↓
                      MCP Servers
```

## Security Model

1. **No Direct Execution**: All operations must go through Bruno
2. **Environment Protection**: Anthropic credentials cannot be overridden
3. **Payload Validation**: Sensitive data detection in execution intents
4. **Read-Only MCP**: Context7 operates in read-only mode

## Directory Structure

```
infra/superclaude/
├── vendor/              # SuperClaude Framework (submodule)
├── adapters/            # SC → Pulser translation layer
│   ├── sc_to_pulser.ts  # Main adapter logic
│   ├── persona_map.yaml # Persona → Agent mappings
│   └── types.ts         # TypeScript interfaces
├── mcp/                 # MCP server configurations
│   └── context7.json    # Context7 documentation server
├── guards/              # Security enforcement
│   ├── env_guard.sh     # Environment variable protection
│   └── exec_guard.ts    # Execution path enforcement
├── bin/                 # Utility scripts
│   ├── sc-install.sh    # Installation script
│   └── sc-validate.sh   # Validation script
└── tests/               # Integration tests

```

## Installation

1. Run the installation script:
   ```bash
   ./infra/superclaude/bin/sc-install.sh
   ```

2. Set required environment variables:
   ```bash
   export CONTEXT7_API_KEY="your-api-key"
   ```

3. Validate the installation:
   ```bash
   ./infra/superclaude/bin/sc-validate.sh
   ```

## Persona Mappings

| SuperClaude Persona | Pulser Agent | Purpose |
|-------------------|--------------|---------|
| System Architect | Devstral | Architecture, PRDs, system design |
| Frontend Developer | Dash | React/TypeScript UI development |
| Security Engineer | BrunoSecurityRunner | Security scanning & audits |
| Scribe | Maya | Documentation generation |
| Data Engineer | Pulser | Data pipelines & ETL |
| DevOps Engineer | InfraBot | Infrastructure automation |

## Usage

### In Claude Code CLI

Add to your Claude Code configuration:

```json
{
  "extensions": {
    "superclaude": {
      "command": "/sc",
      "handler": "infra/superclaude/adapters/cli-handler.ts"
    }
  }
}
```

### Example Commands

```bash
# Generate a PRD
/sc "System Architect" "Create PRD for user authentication system"

# Create React component
/sc "Frontend Developer" "Build dashboard chart component"

# Run security scan
/sc "Security Engineer" "Scan repository for vulnerabilities"

# Generate documentation
/sc "Scribe" "Document the API endpoints"
```

## Security Considerations

1. **Credential Isolation**: All credentials are managed by Bruno, not SuperClaude
2. **Execution Boundary**: SuperClaude cannot execute shell commands directly
3. **MCP Restrictions**: Context7 is limited to documentation retrieval only
4. **Audit Trail**: All operations are logged with metadata

## Troubleshooting

### Installation Issues

If submodule addition fails:
```bash
git clone https://github.com/SuperClaude-Org/SuperClaude_Framework.git \
  infra/superclaude/vendor/SuperClaude_Framework
```

### Validation Failures

1. Check guards are executable: `chmod +x infra/superclaude/guards/*.sh`
2. Ensure TypeScript compiles: `tsc --noEmit infra/superclaude/**/*.ts`
3. Verify MCP config: `jq . infra/superclaude/mcp/context7.json`

### Runtime Errors

Enable debug logging:
```bash
export SUPERCLAUDE_DEBUG=true
export BRUNO_TRACE=true
```

## Development

### Adding New Personas

1. Update `persona_map.yaml` with the new mapping
2. Add case handler in `sc_to_pulser.ts`
3. Create corresponding Pulser agent configuration
4. Update validation tests

### Testing

Run integration tests:
```bash
npm test -- infra/superclaude/tests/
```

## Maintenance

- Review SuperClaude updates monthly
- Run security guards before each update
- Keep persona mappings synchronized with agent capabilities
- Monitor execution logs for anomalies