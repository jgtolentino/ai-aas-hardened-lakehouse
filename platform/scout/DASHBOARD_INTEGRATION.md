# Scout Dashboard Integration Guide

The Scout Analytics Blueprint Dashboard is now integrated as a Git submodule in the monorepo.

## Quick Start

```bash
# Initial setup (after cloning the repo)
git submodule update --init --recursive

# Install dependencies and verify connection
make dash-setup
make dash-verify

# Start development server
make dash-dev
```

## Available Commands

### Development
- `make dash-dev` - Run dashboard in development mode
- `make dash-build` - Build for production
- `make dash-preview` - Preview production build locally
- `make dash-test` - Run tests
- `make dash-verify` - Verify Supabase connection

### Deployment
```bash
# Deploy to different targets
make dash-deploy DEPLOY_TARGET=vercel VERCEL_TOKEN=xxx
make dash-deploy DEPLOY_TARGET=netlify NETLIFY_TOKEN=xxx
make dash-deploy DEPLOY_TARGET=s3 S3_BUCKET=my-bucket
make dash-deploy DEPLOY_TARGET=supabase
```

### Maintenance
- `make dash-update` - Update to latest dashboard version
- `make dash-pin TAG=v1.0.0` - Pin to specific version
- `make dash-clean` - Clean build artifacts

## Environment Configuration

The dashboard requires these environment variables in `.env.local`:

```bash
VITE_SUPABASE_URL=https://cxzllzyxwpyptfretryc.supabase.co
VITE_SUPABASE_ANON_KEY=<your-anon-key>
VITE_SUPABASE_PROJECT_REF=cxzllzyxwpyptfretryc
```

## CI/CD Integration

GitHub Actions workflow is configured at `.github/workflows/dashboard.yml`:
- Builds on push to main
- Runs tests
- Creates build artifacts
- Ready for deployment integration

## Data Requirements

The dashboard expects these views in the `scout_dal` schema:
- `v_gold_transactions_flat`
- `v_revenue_trend`
- Other views as documented in the dashboard README

## Troubleshooting

### Submodule not initialized
```bash
git submodule update --init --recursive
```

### Missing dependencies
```bash
cd platform/scout/blueprint-dashboard && npm install
```

### Connection errors
1. Check `.env.local` exists and has correct values
2. Verify CORS settings in Supabase dashboard
3. Run `make dash-verify` to test connection

## Updating the Dashboard

To update to the latest version:
```bash
make dash-update
git add platform/scout/blueprint-dashboard
git commit -m "chore: update dashboard to latest"
```

To pin to a specific release:
```bash
make dash-pin TAG=v1.2.3
```