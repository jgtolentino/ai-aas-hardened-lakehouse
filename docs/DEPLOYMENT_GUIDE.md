# 🚀 Scout v6.0 Production Deployment Guide

## Overview
Complete deployment pipeline for Scout Financial Intelligence Platform v6.0 with atomic rollouts, health checks, and rollback capabilities.

## 🏗️ Architecture
```
┌─────────────────────────────────────────────────┐
│            Scout v6.0 Deployment                │
├─────────────┬────────────┬─────────────────────┤
│  Migrations │ Edge Func  │   Frontend Build    │
├─────────────┴────────────┴─────────────────────┤
│         Supabase Infrastructure                 │
├─────────────────────────────────────────────────┤
│     Vercel/Netlify (Optional Deploy)           │
└─────────────────────────────────────────────────┘
```

## 📋 Prerequisites

### Required Tools
- `supabase` CLI (latest)
- `jq` for JSON parsing
- `curl` for health checks
- `pnpm` or `npm` for builds
- `pg_dump` (optional, for snapshots)
- `vercel` CLI (optional, for Vercel deploy)

### Environment Variables
Copy `.env.deploy.example` to `.env` and configure:

```bash
# Required
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<anon_public_key>
SUPABASE_SERVICE_ROLE_KEY=<service_role_key>
SUPABASE_PROJECT_REF=<projref>

# Optional
PG_CONN_URL=postgresql://...  # For DB snapshots
VERCEL_TOKEN=<token>          # For Vercel deploy
VERCEL_PROJECT_ID=<id>
VERCEL_ORG_ID=<org_id>
```

## 🎯 Deployment Commands

### Quick Deploy
```bash
# Setup (one-time)
chmod +x scripts/deploy/*.sh

# Deploy to staging
make deploy-staging

# Deploy to production
make deploy-prod

# Run smoke tests only
make smoke
```

### Advanced Options
```bash
# Custom target with Vercel
TARGET=prod DEPLOY_VERCEL=1 make deploy

# With specific Supabase project
SUPABASE_PROJECT_REF=xyz123 make deploy

# Dry run (build only, no deploy)
TARGET=staging bash scripts/deploy/deploy-scout-batch.sh
```

## 🔄 Deployment Process

### 1. **Pre-flight Checks**
- Validates environment variables
- Checks tool availability
- Confirms target environment

### 2. **Database Snapshot** (Optional)
- Creates timestamped backup
- Saves to `.snapshots/` directory
- Enables quick rollback

### 3. **Environment Setup**
- Writes `.env.local` for Next.js apps
- Configures Supabase connection
- Sets feature flags

### 4. **Database Migrations**
- Links Supabase project
- Applies pending migrations
- Creates scout schema tables:
  - `scout.consumer_segments`
  - `scout.regional_performance`
  - `scout.competitive_intelligence`
  - `scout.behavioral_analytics`

### 5. **Edge Function Deploy**
- Deploys `broker` function
- Validates deployment with health check
- Confirms function accessibility

### 6. **Frontend Build**
- Installs dependencies
- Builds Scout Dashboard
- Builds Brand Kit Dashboard
- Optimizes production bundles

### 7. **Vercel Deploy** (Optional)
- Atomic production deployment
- Zero-downtime switchover
- Automatic SSL/CDN

### 8. **Health Checks**
- REST API availability
- Edge function response
- Scout schema tables
- RPC functions

## 🛟 Rollback Procedure

### Automatic Snapshots
Snapshots are created automatically if `PG_CONN_URL` is configured:
```bash
.snapshots/
├── pg_staging_20250829_143022.sql.gz
├── pg_staging_20250829_151545.sql.gz
└── pg_prod_20250829_160030.sql.gz
```

### Rollback Command
```bash
# List available snapshots
ls -la .snapshots/

# Perform rollback (requires confirmation)
make rollback SNAP=.snapshots/pg_prod_20250829_160030.sql.gz

# Manual rollback
bash scripts/deploy/rollback-from-snapshot.sh .snapshots/pg_prod_YYYYMMDD_HHMMSS.sql.gz
```

## 🔍 Health Monitoring

### Smoke Tests
```bash
# Run comprehensive smoke tests
make smoke

# Checks performed:
✓ REST API root endpoint
✓ Edge function /broker health
✓ Scout schema tables accessibility
✓ RPC functions availability
```

### Manual Verification
```bash
# Check REST API
curl -H "apikey: $SUPABASE_ANON_KEY" $SUPABASE_URL/rest/v1/

# Check Edge Function
curl https://$SUPABASE_PROJECT_REF.functions.supabase.co/broker?op=health

# Check Scout tables
curl -H "apikey: $SUPABASE_ANON_KEY" \
  $SUPABASE_URL/rest/v1/consumer_segments?limit=1
```

## 🤖 CI/CD Integration

### GitHub Actions
Workflow: `.github/workflows/deploy-scout-v6.yml`

#### Manual Trigger
1. Go to Actions tab in GitHub
2. Select "Deploy Scout v6" workflow
3. Click "Run workflow"
4. Choose environment: `staging` or `prod`
5. Optional: Enable Vercel deployment

#### Required Secrets
Configure in GitHub Settings → Secrets:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_PROJECT_REF`
- `PG_CONN_URL` (optional)
- `VERCEL_TOKEN` (optional)
- `VERCEL_PROJECT_ID` (optional)
- `VERCEL_ORG_ID` (optional)

## 📊 Deployment Checklist

### Pre-Deployment
- [ ] Environment variables configured
- [ ] Database migrations tested locally
- [ ] Edge functions validated
- [ ] Frontend builds successfully
- [ ] Smoke tests passing

### During Deployment
- [ ] Monitor deployment logs
- [ ] Watch for migration errors
- [ ] Verify Edge function health
- [ ] Check build output

### Post-Deployment
- [ ] Run smoke tests
- [ ] Verify API endpoints
- [ ] Test frontend access
- [ ] Check monitoring dashboards
- [ ] Document deployment version

## 🚨 Troubleshooting

### Common Issues

#### Migration Failures
```bash
# Check migration status
supabase db remote status

# Reset and reapply
supabase db reset
supabase db push
```

#### Edge Function Issues
```bash
# Check function logs
supabase functions logs broker

# Redeploy function
supabase functions deploy broker --no-verify-jwt
```

#### Build Failures
```bash
# Clean and rebuild
rm -rf node_modules pnpm-lock.yaml
pnpm install
pnpm build
```

#### Rollback Fails
```bash
# Manual restore
gunzip -c .snapshots/backup.sql.gz | psql $PG_CONN_URL

# Verify restoration
psql $PG_CONN_URL -c "SELECT * FROM scout.consumer_segments LIMIT 1;"
```

## 📈 Performance Metrics

### Expected Deployment Times
- Database snapshot: ~30s
- Migrations: ~10s
- Edge function: ~20s
- Frontend build: ~2-3min
- Vercel deploy: ~1min
- Total: **~5 minutes**

### Resource Usage
- Build memory: ~2GB
- Snapshot size: ~50-200MB
- Bundle sizes:
  - Scout Dashboard: ~180KB gzipped
  - Brand Kit: ~150KB gzipped

## 🔐 Security Notes

1. **Never commit `.env` files**
2. **Use GitHub Secrets for CI/CD**
3. **Rotate service keys regularly**
4. **Enable RLS on all tables**
5. **Audit deployment logs**

## 📚 Related Documentation

- [Scout v6.0 PRD](docs/prd/PRD-SCOUT-UI-v6.0.md)
- [Finebank Integration](apps/scout-dashboard/FINEBANK_INTEGRATION.md)
- [CI/CD Secrets Playbook](docs/CICD_SECRETS_PLAYBOOK.md)
- [Team Onboarding](docs/TEAM_ONBOARDING_QUICK_START.md)

## 🆘 Support

### Deployment Issues
- Check deployment logs in `.logs/`
- Review GitHub Actions output
- Verify environment variables

### Emergency Contacts
- DevOps Team: #devops-channel
- Database Admin: #database-team
- Frontend Team: #frontend-squad

---

**Last Updated**: August 2025
**Version**: 1.0.0
**Maintained by**: TBWA Data & Analytics Team
