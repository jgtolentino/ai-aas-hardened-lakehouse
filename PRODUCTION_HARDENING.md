# Production Hardening - Scout Analytics Platform

## Overview

This document describes the additional production hardening measures implemented beyond the basic readiness gate, addressing supply-chain integrity, runtime hardening, resiliency controls, and continuous data quality enforcement.

## 1. Supply-Chain Integrity

### SBOM Generation
- **Tool**: Syft (SPDX format)
- **Coverage**: All container images pushed to GHCR
- **Storage**: Artifacts attached to each workflow run
- **Format**: SPDX JSON for machine readability

### Keyless Signing with Cosign
- **Provider**: Sigstore (OIDC-based)
- **What's Signed**:
  - Container images
  - SBOM attestations
- **Verification**: `cosign verify ghcr.io/your-org/api:latest`
- **No secrets required**: Uses GitHub OIDC tokens

### Usage
```bash
# Verify image signature
cosign verify ghcr.io/your-org/api:latest \
  --certificate-identity-regexp "https://github.com/your-org/.*" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

# Verify SBOM attestation
cosign verify-attestation ghcr.io/your-org/api:latest \
  --type spdx \
  --certificate-identity-regexp "https://github.com/your-org/.*" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

# View SBOM
cosign download attestation ghcr.io/your-org/api:latest | jq -r .payload | base64 -d | jq
```

## 2. Runtime Hardening

### Security Context
All production workloads enforce:
- **Non-root execution**: `runAsNonRoot: true`
- **Read-only filesystem**: `readOnlyRootFilesystem: true`
- **No privilege escalation**: `allowPrivilegeEscalation: false`
- **Drop all capabilities**: `capabilities: { drop: ["ALL"] }`
- **Seccomp profile**: `RuntimeDefault`

### Resource Management
```yaml
# API Service
resources:
  requests: { cpu: "100m", memory: "128Mi" }
  limits:   { cpu: "500m", memory: "512Mi" }

# Worker Service  
resources:
  requests: { cpu: "100m", memory: "128Mi" }
  limits:   { cpu: "1000m", memory: "1Gi" }

# Brand Model (ML)
resources:
  requests: { cpu: "200m", memory: "512Mi" }
  limits:   { cpu: "2000m", memory: "3Gi" }
```

### Health Probes
- **Readiness**: Checks service is ready for traffic
- **Liveness**: Restarts unhealthy containers
- **Configured timeouts**: Prevent cascading failures

### High Availability
- **PodDisruptionBudget**: Maintains minimum replicas during updates
- **HorizontalPodAutoscaler**: Scales based on CPU (70% target)
- **Rolling updates**: Zero-downtime deployments

### Network Policies
- **Default deny**: All ingress/egress blocked by default
- **Explicit allow**: Only required connections permitted
- **Database isolation**: DB access only from app namespace

## 3. Resiliency Controls

### Canary Deployment Checks
- **Tool**: k6 performance testing
- **Duration**: 1 minute with 10 VUs
- **SLO Thresholds**:
  - Error rate ≤ 0.2%
  - p95 latency ≤ 300ms
- **Auto-rollback**: Deployment fails if SLOs breached

### Rollback Mechanism
```bash
# Automatic on canary failure
if [ "$CANARY_FAIL" == "1" ]; then
  helm rollback scout-app 1  # Or your rollback command
  exit 1
fi
```

### Incident Management
- **Auto-issue creation**: On deployment failure
- **Rollback documentation**: Step-by-step guide
- **Team notification**: Slack/email alerts

## 4. Continuous DQ Enforcement

### Nightly DQ Checks
- **Schedule**: 02:15 PHT daily
- **Scope**: Full production readiness gate
- **Failure action**: Creates GitHub issue
- **Metrics tracked**:
  - Brand coverage
  - Price completeness
  - Data freshness
  - Replication health

### Alert Configuration
```yaml
on_failure:
  - Create GitHub issue with logs
  - Tag: data-quality, nightly-check
  - Assign: data-team
  - Priority: high
```

## 5. Verification Commands

### One-Command Verification
```bash
# Trigger all hardening workflows
gh workflow run "Release Images (GHCR)" -r main
gh workflow run "Production Readiness Gate" -r main
gh workflow run "DQ Nightly" -r main

# Monitor results
gh run list --workflow "Production Readiness Gate" -L 3
gh run view --web $(gh run list --workflow "Production Readiness Gate" -L 1 --json databaseId -q '.[0].databaseId')

# Attempt deployment (blocked unless gate passes)
gh workflow run "Deploy to Production" -r main
```

### Local Testing
```bash
# Test k8s manifests
kubectl apply --dry-run=client -f infra/k8s/overlays/prod/

# Test canary locally
API_BASE=http://localhost:8080 k6 run scripts/k6/canary.js

# Test DQ gate
docker compose -f infra/docker/compose.yml up -d db
./scripts/prod-readiness.sh
```

## 6. Security Best Practices

### Image Security
- ✅ Signed images with Sigstore
- ✅ SBOM for every image
- ✅ Vulnerability scanning (Trivy)
- ✅ Minimal base images (Alpine)

### Runtime Security
- ✅ Non-root containers
- ✅ Read-only root filesystem
- ✅ Network segmentation
- ✅ Resource limits prevent DoS

### Supply Chain
- ✅ Reproducible builds
- ✅ Dependency pinning
- ✅ Automated updates (Dependabot)
- ✅ License compliance via SBOM

## 7. Monitoring & Observability

Post-deployment monitoring:
- **Canary metrics**: Real-time SLO tracking
- **DQ dashboards**: Data quality trends
- **Security alerts**: Runtime anomalies
- **Resource usage**: Cost optimization

## 8. Compliance & Audit

### Evidence Collection
- **SBOM artifacts**: Software inventory
- **Cosign signatures**: Tamper evidence
- **DQ reports**: Data quality history
- **Deployment logs**: Change tracking

### Audit Trail
```bash
# View all signed images
cosign tree ghcr.io/your-org/api

# Download SBOM for compliance
gh run download -n sbom-api

# Query DQ history
psql $DB_URL -c "SELECT * FROM dq_audit_log ORDER BY run_date DESC LIMIT 10;"
```

## 9. Emergency Procedures

### Break-Glass Access
1. **Override canary**: Set `SKIP_CANARY=true`
2. **Fast-track deploy**: Use emergency workflow
3. **Document reason**: Required in PR description
4. **Post-mortem**: Within 48 hours

### Rollback Procedures
```bash
# Helm rollback
helm rollback scout-app

# Git revert
git revert --no-edit HEAD
git push origin main

# Database rollback
psql $DB_URL -f backups/pre-deploy.sql
```

## Summary

The Scout Analytics Platform now implements defense-in-depth with:
- **Supply chain**: Signed, SBOM'd images
- **Runtime**: Hardened, resource-limited containers
- **Resiliency**: Canary checks with auto-rollback
- **Quality**: Continuous DQ enforcement

This ensures production deployments are not just "working" but are secure, resilient, and maintain data quality standards continuously.