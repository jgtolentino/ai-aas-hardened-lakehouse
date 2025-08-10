# Environment Configuration Matrix

This directory contains environment-specific configurations for Scout Analytics Platform.

## Environments

### Development (`dev/`)
- Local development settings
- Mock services enabled
- Debug logging
- No rate limiting

### Staging (`staging/`)
- Pre-production validation
- Real services with test data
- Standard logging
- Light rate limiting

### Production (`prod/`)
- Production settings
- Full security enabled
- Structured logging
- Rate limiting enforced

## Configuration Files

Each environment contains:
- `values.yaml` - Helm values for Kubernetes deployments
- `superset.env` - Superset-specific environment variables
- `edge.env` - Edge Functions environment variables
- `secrets.yaml.example` - Template for secret values (never commit actual secrets)

## Usage

```bash
# Deploy to specific environment
helm upgrade scout ./helm/scout -f environments/prod/values.yaml

# Load environment for local development
source environments/dev/edge.env
```