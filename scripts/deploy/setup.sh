#!/usr/bin/env bash
# Setup deployment scripts permissions
set -euo pipefail

echo "Setting up Scout v6.0 deployment scripts..."

# Make all deployment scripts executable
chmod +x scripts/deploy/deploy-scout-batch.sh
chmod +x scripts/deploy/rollback-from-snapshot.sh
chmod +x scripts/deploy/smoke.sh

echo "✅ Deployment scripts are now executable"
echo ""
echo "Quick Start:"
echo "  1. Copy .env.deploy.example to .env and fill in your values"
echo "  2. Run 'make deploy-staging' for staging deployment"
echo "  3. Run 'make deploy-prod' for production deployment"
echo "  4. Run 'make smoke' to test endpoints"
echo ""
echo "GitHub Actions:"
echo "  - Workflow: .github/workflows/deploy-scout-v6.yml"
echo "  - Trigger: Manual dispatch from Actions tab"
echo "  - Environments: staging, prod"
echo ""
echo "Rollback:"
echo "  - Snapshots saved to .snapshots/"
echo "  - Run 'make rollback SNAP=path/to/snapshot.sql.gz'"
