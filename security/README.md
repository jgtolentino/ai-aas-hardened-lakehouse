# Security Module - AI-AAS Hardened Lakehouse

Comprehensive security scanning and vulnerability detection system for the AI-AAS platform.

## Features

### 🔍 Multiple Scanner Support
- **Trivy**: Container security, dependency scanning, IaC scanning
- **Semgrep**: Static Application Security Testing (SAST)
- **TruffleHog**: Secret detection and credential scanning

### 📋 Policy Engine
- OWASP Top 10 compliance
- Custom security policies
- Policy exceptions with expiration
- Compliance reporting

### 🚀 Scanner Orchestration
- Parallel scanner execution
- Intelligent scanner selection
- Result deduplication
- Unified reporting

### 🔒 Bruno Integration
- Sandboxed security scanning
- Pre-execution security checks
- Security event monitoring
- Policy enforcement

## Quick Start

### CLI Usage

```bash
# Run a full security scan
security scan /path/to/project

# Run specific scanners
security scan /path/to/project --scanners trivy semgrep

# Quick scan presets
security quick-scan secrets /path/to/project
security quick-scan dependencies /path/to/project
security quick-scan full /path/to/project

# List available scanners
security list-scanners

# List security policies
security list-policies

# Run self-test
security test
```

### Programmatic Usage

```typescript
import { scannerOrchestrator, policyEngine } from '@ai-aas/security';

// Run security scan
const scanResults = await scannerOrchestrator.scan({
  id: 'scan-123',
  target: '/path/to/project',
  scanners: ['trivy', 'semgrep', 'trufflehog']
});

// Evaluate against policies
const policyResults = await policyEngine.evaluate(
  scanResults.results,
  ['owasp-top-10', 'no-secrets']
);

// Generate report
const report = await generateSecurityReport(
  scanResults.results,
  policyResults,
  { format: 'html', outputPath: './security-report.html' }
);
```

## Scanner Details

### Trivy Scanner
- **Type**: Container, dependency, IaC scanning
- **Detects**: CVEs, misconfigurations, secrets
- **Supports**: Docker images, filesystems, git repos

### Semgrep Scanner
- **Type**: Static Application Security Testing
- **Detects**: Security patterns, OWASP issues
- **Supports**: 30+ languages, custom rules

### TruffleHog Scanner
- **Type**: Secret detection
- **Detects**: API keys, passwords, tokens
- **Features**: Entropy analysis, regex patterns, verification

## Security Policies

### Built-in Policies

1. **OWASP Top 10 Policy**
   - Injection vulnerabilities
   - Broken authentication
   - Sensitive data exposure
   - XXE attacks
   - Broken access control

2. **No Secrets Policy**
   - Blocks verified secrets
   - Warns on potential secrets
   - Requires immediate rotation

3. **Container Security Policy**
   - Critical vulnerability blocking
   - Non-root user enforcement
   - Base image currency

### Custom Policies

Create custom policies:

```typescript
const customPolicy: SecurityPolicy = {
  id: 'my-policy',
  name: 'Custom Security Policy',
  enforcement: 'block',
  rules: [
    {
      id: 'no-eval',
      severity: 'high',
      pattern: 'eval\\(',
      message: 'eval() is dangerous',
      remediation: 'Use safer alternatives'
    }
  ]
};

policyEngine.addPolicy(customPolicy);
```

## Integration with Bruno

### Automatic Security Checks

```typescript
import { integrateSecurity } from '@ai-aas/security';

// Enable automatic security checks for Bruno jobs
integrateSecurity();

// Now all Bruno jobs will be scanned before execution
```

### Manual Security Job

```typescript
import { createSecurityScanJob } from '@ai-aas/security';

const scanJob = createSecurityScanJob('/path/to/scan', {
  scanners: ['trivy', 'semgrep'],
  severity: ['critical', 'high'],
  policies: ['owasp-top-10']
});

const result = await brunoExecutor.execute(scanJob);
```

## Configuration

### Scanner Configuration

```typescript
// Configure scanner timeouts and options
const orchestrator = new ScannerOrchestrator({
  parallel: true,
  maxConcurrency: 3,
  failFast: true,
  scanners: ['trivy', 'semgrep', 'trufflehog']
});
```

### Policy Configuration

```typescript
// Configure policy engine
const engine = new SecurityPolicyEngine({
  enforcement: 'block',
  policyPaths: ['./security/policies'],
  exceptionPaths: ['./security/exceptions']
});
```

## Reports and Dashboards

### Generate Reports

```bash
# Markdown report
security scan /path --output report.md

# HTML report
security scan /path --output report.html --format html

# JSON report
security scan /path --output report.json --format json
```

### Terminal Dashboard

```typescript
import { createSecurityDashboard, renderTerminalDashboard } from '@ai-aas/security';

const dashboard = createSecurityDashboard(scanResults);
console.log(renderTerminalDashboard(dashboard));
```

Output:
```
╔════════════════════════════════════════════════════════════════╗
║                    SECURITY DASHBOARD                          ║
╚════════════════════════════════════════════════════════════════╝

Risk Score: 42/100 🟡 [████████░░░░░░░░░░░░]
Trend: 📈 improving

┌─ Findings by Severity ─────────────────┐
│ critical    2 ▓░░░░░░░░░░░░░░░░░░░ │
│ high        5 ▓▓░░░░░░░░░░░░░░░░░░ │
│ medium     12 ▓▓▓▓▓░░░░░░░░░░░░░░░ │
│ low        28 ▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░ │
└────────────────────────────────────────┘
```

## Best Practices

### 1. Regular Scanning
- Scan on every commit
- Schedule daily full scans
- Monitor for new vulnerabilities

### 2. Policy Management
- Start with built-in policies
- Customize based on requirements
- Review and update regularly

### 3. Secret Management
- Never ignore secret findings
- Rotate immediately when found
- Use secret management tools

### 4. Container Security
- Scan base images regularly
- Minimize attack surface
- Use multi-stage builds

### 5. Dependency Management
- Keep dependencies updated
- Monitor for vulnerabilities
- Use lock files

## Troubleshooting

### Scanner Not Available
```bash
# Check Docker is running
docker info

# Pull scanner images manually
docker pull aquasec/trivy:latest
docker pull returntocorp/semgrep:latest
docker pull trufflesecurity/trufflehog:latest
```

### Scan Timeouts
- Increase timeout in scanner config
- Reduce scan scope with filters
- Run scanners individually

### Policy Violations
- Review policy rules
- Add exceptions if needed
- Fix underlying issues

## Security Considerations

- Scanners run in Docker containers for isolation
- Results may contain sensitive information
- Store reports securely
- Rotate credentials after detection
- Never disable security checks in production

## Future Enhancements

- [ ] Additional scanners (Snyk, SonarQube)
- [ ] AI-powered vulnerability analysis
- [ ] Real-time monitoring
- [ ] Integration with CI/CD
- [ ] Vulnerability database
- [ ] Automated remediation
- [ ] Security metrics tracking