# Security CI/CD Pipeline

This document describes the production-ready security CI/CD pipeline that integrates Trivy, Semgrep, and TruffleHog with GitHub Actions, policy enforcement, and Slack notifications.

## 🚀 Quick Start

1. **Scanner Images**: Already pulled and configured
2. **Test Locally**: `./scripts/test-security-pipeline.sh`
3. **Add Slack Secret**: `gh secret set SLACK_WEBHOOK_URL --body "$SLACK_WEBHOOK_URL"`
4. **Open PR**: Security checks will run automatically

## 📋 What's Included

### ✅ GitHub Actions Workflows

#### PR Security Workflow (`.github/workflows/security.yml`)
- **Triggers**: Pull requests and pushes to `main`
- **Scanners**: Trivy (dependencies), Semgrep (SAST), TruffleHog (secrets on changed files only)
- **Policy Enforcement**: Fails PRs based on configurable thresholds
- **SARIF Upload**: Integrates with GitHub Code Scanning

#### Nightly Security Sweep (`.github/workflows/security-nightly.yml`)
- **Triggers**: Daily at 02:30 Asia/Manila (18:30 UTC)
- **Scope**: Full git history secrets scan + comprehensive SAST/dependency checks
- **Notifications**: Slack alerts with summary dashboard
- **Artifacts**: 7-day retention of detailed reports

### 🔧 Policy Configuration

#### Central Policy File (`security/policy/policy.yaml`)
```yaml
fail_thresholds:
  trivy:
    CRITICAL: 0    # No critical vulnerabilities allowed
    HIGH: 0        # No high vulnerabilities allowed  
    MEDIUM: 10     # Max 10 medium vulnerabilities
  semgrep:
    ERROR: 0       # No errors allowed
    WARNING: 20    # Max 20 warnings
  trufflehog:
    VERIFIED_FINDINGS: 0  # No verified secrets allowed
```

#### Policy Enforcement Script (`security/policy/enforce.ts`)
- Reads SARIF/JSON reports from scanners
- Applies thresholds from `policy.yaml`
- Exits with non-zero code on violations
- Used in both PR and nightly workflows

### 🎯 Scanner Configuration

#### Trivy (Container & Dependency Security)
- **Image**: `aquasec/trivy` (pinned by digest)
- **Scope**: Dependencies, container images, IaC files
- **Output**: SARIF format for GitHub integration
- **Cache**: Vulnerability database cached in CI

#### Semgrep (Static Application Security Testing)
- **Image**: `returntocorp/semgrep` (pinned by digest)
- **Rules**: OWASP Top 10 + custom rules in `rules/semgrep/`
- **Languages**: JavaScript, TypeScript, Python, PHP, etc.
- **Output**: SARIF format for GitHub integration

#### TruffleHog (Secret Detection)
- **Image**: `trufflesecurity/trufflehog` (pinned by digest)
- **PR Mode**: Changed files only, verified secrets only
- **Nightly Mode**: Full git history scan
- **Output**: JSON format

### 🛡️ Security Features

#### Pinned Scanner Images
All scanner images are pinned by digest to prevent supply-chain attacks:
```yaml
aquasec/trivy@sha256:7dc2d3f9c63f6e63d0f7b21a0d9d4e9e0d776b7a4b6d3a1b4cb6b2a6f5e37b39
returntocorp/semgrep@sha256:3a5608b3b8e0f2b6f2e3a9c7a7b6b3d1bfb8a0a2a45e9f0a9f2db46be8d9ae9a
trufflesecurity/trufflehog@sha256:2f2a1a7c6e38de8e0d4a0fb0b7f7b5d86ebc27b8c3f1d35f8a0a54c953fdfb33
```

#### Clean Allowlists
- `security/allowlists/.trivyignore`: CVE exceptions
- `security/allowlists/.semgrepignore`: Path exclusions
- `security/allowlists/trufflehog.exclude`: File/pattern exclusions

### 📊 Monitoring & Alerts

#### Slack Integration
- **Nightly Reports**: Structured Slack messages with findings summary
- **Format**: Slack blocks with metric cards and context
- **Configuration**: `SLACK_WEBHOOK_URL` secret in repository

#### GitHub Code Scanning
- **SARIF Upload**: Trivy and Semgrep results integrated
- **Security Tab**: View findings directly in GitHub UI
- **PR Annotations**: Security issues shown in code diff

## 🔧 Local Development

### Test Security Pipeline
```bash
# Test all scanners locally
./scripts/test-security-pipeline.sh

# Test individual components
npx tsx security/cli/security-cli.ts scan .
npx tsx security/policy/enforce.ts trivy.sarif security/policy/policy.yaml
```

### Add Custom Rules
```bash
# Semgrep rules
echo 'rules:
  - id: my-custom-rule
    pattern: dangerous_function($X)
    message: Avoid dangerous_function
    severity: ERROR' >> rules/semgrep/custom.yaml

# Policy exceptions
echo 'CVE-2023-12345  # False positive' >> security/allowlists/.trivyignore
```

## 📈 Operational Guidelines

### Policy Tuning
1. **Start Conservative**: Begin with strict thresholds (0 critical/high)
2. **Monitor Noise**: Adjust based on false positives
3. **Regular Reviews**: Update thresholds quarterly
4. **Document Exceptions**: All allowlist entries need justification

### Incident Response
1. **Critical Secrets**: Rotate immediately, check logs
2. **High Vulnerabilities**: Fix within 24 hours
3. **Policy Violations**: Block PR until resolved
4. **False Positives**: Add to allowlist with expiry date

### Maintenance
- **Monthly**: Review scanner image updates
- **Quarterly**: Update pinned image digests
- **Annually**: Review and update policies

## 🔍 Scanner Details

### Trivy Capabilities
- **CVE Detection**: 180,000+ vulnerabilities
- **Languages**: Go, Rust, Node.js, Python, Java, etc.
- **IaC Scanning**: Kubernetes, Terraform, CloudFormation
- **Container Scanning**: Docker images, registries

### Semgrep Coverage
- **Languages**: 30+ languages supported
- **Rule Sources**: Community rules + custom rules
- **Security Focus**: OWASP Top 10, CWE mappings
- **Performance**: Fast AST-based scanning

### TruffleHog Accuracy
- **Entropy Analysis**: Detects high-entropy strings
- **Regex Patterns**: 700+ secret patterns
- **Verification**: Tests if secrets are active
- **Git History**: Scans entire repository history

## 🚨 Common Issues & Solutions

### High False Positive Rate
```bash
# Add specific exceptions
echo 'test_api_key_12345  # Test credential' >> security/allowlists/.trivyignore

# Exclude test directories
echo 'tests/**' >> security/allowlists/.semgrepignore
```

### Slow Scans
```bash
# Limit Trivy to critical/high only
--severity CRITICAL,HIGH

# Exclude large directories from Semgrep
--exclude 'vendor' --exclude 'node_modules'

# Use TruffleHog verified mode only
--only-verified
```

### CI/CD Failures
1. **Check Policy Thresholds**: May need adjustment
2. **Review Scanner Logs**: Look for configuration issues  
3. **Verify Secrets**: Ensure `SLACK_WEBHOOK_URL` is set
4. **Image Availability**: Confirm Docker images are accessible

## 📚 Integration Examples

### Pre-commit Hooks
```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: security-scan
        name: Security Scan
        entry: ./scripts/test-security-pipeline.sh
        language: system
        pass_filenames: false
```

### IDE Integration
```bash
# VS Code with Semgrep extension
code --install-extension semgrep.semgrep

# CLI usage
semgrep --config=auto .
trivy fs .
trufflehog filesystem .
```

### Custom Webhooks
```typescript
// Custom Slack webhook formatting
const payload = {
  text: `Security Alert: ${findings} issues found`,
  blocks: [
    {
      type: "section", 
      text: { type: "mrkdwn", text: `*Critical Issues: ${critical}*` }
    }
  ]
};
```

## 🎯 Success Metrics

### Security KPIs
- **Mean Time to Fix**: Average time from detection to resolution
- **False Positive Rate**: % of findings marked as false positives
- **Coverage**: % of codebase scanned by security tools
- **Compliance**: % of policies passing threshold requirements

### Operational KPIs  
- **CI/CD Speed**: Security scan duration impact
- **Developer Experience**: Time spent on security fixes
- **Alert Fatigue**: Number of ignored/suppressed findings

## 🔮 Future Enhancements

### Planned Features
- [ ] Auto-remediation for common vulnerabilities
- [ ] Integration with ticketing systems (Jira, Linear)
- [ ] Advanced policy engine with ML-based risk scoring
- [ ] Container runtime security monitoring
- [ ] Compliance framework mapping (SOC2, PCI DSS)

### Integration Roadmap
- [ ] SonarQube integration for code quality + security
- [ ] Snyk integration for enhanced vulnerability data
- [ ] SIEM integration for security event correlation
- [ ] Vault integration for secret rotation automation

---

**🔒 This security pipeline provides comprehensive protection against the most common attack vectors while maintaining developer productivity through smart policy enforcement and noise reduction.**