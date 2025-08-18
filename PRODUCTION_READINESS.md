# Production Readiness Gate - Scout Analytics Platform

## Overview

This document describes the automated production readiness gate that ensures the Scout Analytics Platform meets strict quality, security, and performance standards before deployment.

## Gate Components

### 1. 🔒 Security Scanning
- **Tool**: Trivy
- **Checks**: 
  - No CRITICAL or HIGH vulnerabilities in dependencies
  - No exposed secrets or credentials
  - Configuration security best practices
- **Exit Criteria**: Zero critical/high vulnerabilities

### 2. ⚡ Performance Testing
- **Tool**: k6
- **Thresholds**:
  - p95 response time ≤ 250ms
  - Error rate ≤ 0.1%
  - Health endpoint p95 ≤ 50ms
  - Brand lookup p95 ≤ 200ms
  - ML inference p95 ≤ 300ms
- **Load Profile**: 20 concurrent users for 2 minutes

### 3. 📊 Data Quality
- **Checks**:
  - Brand coverage ≥ 70%
  - Price coverage ≥ 85%
  - Store completeness ≥ 95%
  - Data freshness ≤ 24 hours
  - Dataset publisher health ≥ 90%
  - Replication success ≥ 95%
  - Brand detection rate ≥ 60%
- **Tool**: SQL-based validation scripts

### 4. 🔐 Row Level Security (RLS)
- **Checks**:
  - All sensitive tables have RLS enabled
  - Critical tables have security policies
  - No "allow all" policies (WHERE true)
  - Sensitive columns are protected
  - Role-based access properly configured
- **Severity Levels**: CRITICAL, HIGH, MEDIUM

### 5. 🚀 Deployment Readiness
- **Checks**:
  - All required files present
  - Dependencies install successfully
  - Build completes without errors
  - Tests pass (if configured)
  - Build size < 10MB
  - Kubernetes manifests valid (if applicable)

## Usage

### Running Locally

```bash
# Make script executable
chmod +x scripts/prod-readiness.sh

# Set database URL
export SUPABASE_DB_URL="postgresql://..."

# Run all checks
./scripts/prod-readiness.sh

# Check results
cat prod-gate-reports/prod-gate-*.log
```

### GitHub Actions

The gate runs automatically on:
- Pull requests to `main` or `production`
- Pushes to `staging` 
- Manual workflow dispatch

### Exit Codes

- `0`: All checks passed
- `1`: Security failures
- `2`: Performance failures
- `3`: Data quality failures
- `4`: RLS failures
- `5`: Deployment failures

## Configuration

### Environment Variables

```bash
# Required
SUPABASE_DB_URL=postgresql://...

# Optional
API_BASE=http://localhost:8080  # For k6 tests
```

### Customizing Thresholds

Edit the following files to adjust thresholds:
- `scripts/k6/api-readiness.js` - Performance thresholds
- `scripts/sql/dq_gate.sql` - Data quality thresholds
- `scripts/sql/rls_check.sql` - Security requirements

## CI/CD Integration

### Branch Protection

Configure branch protection rules as documented in `.github/branch-protection.md`:
- Require gate passage before merge
- Enforce linear history
- Require PR reviews

### Deployment Workflow

```yaml
# Automatic deployment flow
main → staging (auto-deploy) → production (manual approval)
```

### Production Deployment

1. Gate runs on staging push
2. If passed, deployment allowed to production
3. Manual approval required
4. Post-deployment verification
5. Automatic rollback on failure

## Reports and Artifacts

Gate execution generates:
- `prod-gate-reports/prod-gate-{timestamp}.log` - Full execution log
- `prod-gate-reports/prod-gate-summary-{timestamp}.json` - JSON summary
- `trivy-results.sarif` - Security scan results
- `k6-results.json` - Performance test data
- `dq-results.log` - Data quality report
- `rls-results.log` - Security audit

## Troubleshooting

### Common Issues

1. **Database Connection Failed**
   - Verify SUPABASE_DB_URL is correct
   - Check network connectivity
   - Ensure database is accessible

2. **Performance Tests Fail**
   - Check if services are running
   - Verify API endpoints are correct
   - Review k6 thresholds

3. **Data Quality Failures**
   - Run individual DQ queries to identify issues
   - Check data population scripts
   - Verify ETL processes

### Manual Overrides

For emergency deployments only:
```bash
# Skip specific checks (NOT RECOMMENDED)
SKIP_SECURITY=true ./scripts/prod-readiness.sh
SKIP_PERFORMANCE=true ./scripts/prod-readiness.sh
```

## Monitoring

After deployment, monitor:
- Application logs
- Performance metrics
- Error rates
- Data quality metrics
- Security alerts

## Best Practices

1. **Run gate checks early and often**
2. **Fix issues immediately** - Don't accumulate technical debt
3. **Keep dependencies updated** - Regular security patches
4. **Monitor trends** - Track gate passage rate over time
5. **Document exemptions** - Any overrides need justification

## Support

For gate-related issues:
1. Check the detailed logs in `prod-gate-reports/`
2. Review specific check scripts in `scripts/`
3. Consult team leads for threshold adjustments
4. File issues for gate improvements

---

Remember: **The gate ensures production quality. Bypassing it risks system stability and security.**