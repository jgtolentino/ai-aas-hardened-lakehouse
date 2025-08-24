# 🗄️ Canonical Production Database Repository

**ai-aas-hardened-lakehouse** is now the **single source of truth** for Scout v5.2 production database schema and data.

## 🎯 Overview

This repository manages:
- ✅ **Schema migrations** → Supabase project `cxzllzyxwpyptfretryc`
- ✅ **Seed data** via Supabase Storage buckets 
- ✅ **Automated CI/CD** with drift protection
- ✅ **Cross-repo synchronization** (scout-databank-new, scout-analytics-blueprint-doc)

## 🚀 Quick Start

### 1. One-time Setup
```bash
# Clone and setup
cd ~/Documents/GitHub/ai-aas-hardened-lakehouse
./scripts/setup-canonical-repo.sh

# Upload seed data to storage bucket
./scripts/upload-seeds.sh
```

### 2. Add GitHub Secrets
In GitHub repo → **Settings** → **Secrets and variables** → **Actions**:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `SUPABASE_ACCESS_TOKEN` | `sbp_...` | Personal Access Token from [Supabase dashboard](https://app.supabase.com/account/tokens) |
| `SUPABASE_PROJECT_REF` | `cxzllzyxwpyptfretryc` | Production project reference |
| `SUPABASE_DB_URL` | `postgresql://...` | Connection string from Supabase dashboard |

### 3. Deploy
```bash
git add .
git commit -m "setup: canonical db repo with Scout v5.2"
git push origin main
```

## 📂 Repository Structure

```
ai-aas-hardened-lakehouse/
├── .github/workflows/
│   ├── ci.yml              # Schema drift detection + validation
│   └── deploy-prod.yml     # Production deployment automation
├── supabase/
│   ├── migrations/         # Source of truth migrations
│   ├── seed.sql           # Calls fn_seed_dev_data()
│   └── config.toml        # Project: cxzllzyxwpyptfretryc
├── scripts/
│   ├── setup-canonical-repo.sh    # One-time setup
│   └── upload-seeds.sh            # Upload CSV data to storage
├── data/                  # Generated CSV files (for bucket upload)
└── db/migrations/         # Legacy migrations (if any)
```

## 🔄 Automated Workflows

### CI Pipeline (PR checks)
- **Schema drift detection** → Prevents production divergence
- **Migration validation** → Ensures proper naming (YYYYMMDDHHMMSS_*.sql)
- **SQL safety checks** → Blocks dangerous operations

### Production Deployment (main branch)
- **Apply migrations** → `supabase db push`
- **Load seed data** → From storage bucket via `fn_load_seed_data()`
- **Smoke tests** → Verify critical objects exist
- **Status reporting** → Deployment success/failure

## 🌱 Seed Data System

### Storage Bucket Architecture
```
https://cxzllzyxwpyptfretryc.supabase.co/storage/v1/object/public/seed-data/
├── ref_sources.csv              # Data provenance
├── ref_categories.csv           # Product categories
├── ref_brands.csv              # Brand master data
├── health_category_rules.csv   # Health x Category lift factors
├── seasonality_factors.csv     # Seasonal demand patterns
└── sample_sku_catalog.csv      # Sample product catalog
```

### Loading Functions
```sql
-- Load all reference data from storage bucket
SELECT scout.fn_load_seed_data();

-- Development seeding (includes sample transactions)
SELECT scout.fn_seed_dev_data();

-- Validate bucket access
SELECT * FROM scout.fn_validate_seed_bucket();
```

## 🔒 Migration Policy

### ✅ DO
- Create migrations in `supabase/migrations/` with format: `YYYYMMDDHHMMSS_description.sql`
- Use `CREATE TABLE IF NOT EXISTS` for safety
- Test locally first: `supabase db reset && supabase db push`
- Open PR → CI validates → Merge → Auto-deploy

### ❌ DON'T  
- Run ad-hoc SQL in Supabase dashboard for production
- Use `DROP TABLE` or `TRUNCATE` in migrations
- Commit large CSV files (use storage bucket instead)
- Push directly to main (use PR workflow)

## 🔍 Drift Detection

The CI automatically detects schema drift between repo and production:

```bash
# Manual drift check
supabase db diff

# Fix drift by syncing from production
supabase db pull --schema scout,public
```

## 📊 Monitoring & Validation

### Health Checks
```sql
-- Check migration status
SELECT * FROM scout.migration_manifest ORDER BY applied_at DESC;

-- Validate reference data
SELECT 
  (SELECT COUNT(*) FROM scout.ref_categories) as categories,
  (SELECT COUNT(*) FROM scout.ref_brands) as brands,
  (SELECT COUNT(*) FROM scout.ref_health_category_rules) as health_rules;

-- Test bucket connectivity  
SELECT file_name, exists, size_bytes FROM scout.fn_validate_seed_bucket();
```

### Deployment Status
- **GitHub Actions**: [Repository Actions Tab](https://github.com/your-username/ai-aas-hardened-lakehouse/actions)
- **Supabase Logs**: https://app.supabase.com/project/cxzllzyxwpyptfretryc/logs
- **Database Health**: Automated in deploy-prod.yml workflow

## 🔄 Cross-Repository Sync

This canonical repo coordinates with:
- **scout-databank-new** (frontend) → Mirrors critical migrations
- **scout-analytics-blueprint-doc** (documentation) → Mirrors schema updates

Use existing sync scripts in those repos to pull from this canonical source.

## 🛠️ Development Workflow

### Local Development
```bash
# Start local Supabase
supabase start

# Apply migrations locally
supabase db reset

# Load development seed data
echo "SELECT scout.fn_seed_dev_data();" | supabase db execute

# Test changes
# ... make changes to migrations ...
supabase db push
```

### Production Deployment
```bash
# Create feature branch
git checkout -b feature/new-health-rules

# Add migration file
supabase migration new add_pregnancy_health_rules
# Edit: supabase/migrations/20250824120500_add_pregnancy_health_rules.sql

# Test locally
supabase db reset && supabase db push

# Open PR → CI validates → Review → Merge → Auto-deploy
```

## 🚨 Troubleshooting

### Common Issues

**❌ Schema drift detected**
```bash
# Pull latest from production
supabase db pull --schema scout,public
git add . && git commit -m "sync: latest production schema"
```

**❌ Migration failed**
```bash
# Check logs in GitHub Actions
# Fix migration file
# Test locally first
supabase db reset && supabase db push
```

**❌ Seed data not loading**
```bash
# Check bucket access
SELECT * FROM scout.fn_validate_seed_bucket();

# Re-upload seed data
./scripts/upload-seeds.sh

# Test loading
SELECT scout.fn_load_seed_data();
```

### Emergency Procedures

**🚨 Production is broken**
1. Check GitHub Actions for deployment failure details
2. Revert last commit if needed: `git revert HEAD && git push`
3. Monitor deployment status in Supabase dashboard
4. If data corruption: Use backup from Supabase dashboard

## 📞 Support

- **Technical Issues**: Check GitHub Actions logs
- **Schema Questions**: Review migration files in `supabase/migrations/`
- **Data Issues**: Validate with seed data functions
- **Emergency**: Use Supabase dashboard direct access

## 🎉 Success Metrics

When properly configured, this repo provides:
- ✅ **Zero-drift** production database
- ✅ **Automated migrations** with safety checks  
- ✅ **Consistent seed data** across environments
- ✅ **Full audit trail** via Git + GitHub Actions
- ✅ **Fast recovery** from known-good state

---

🚀 **ai-aas-hardened-lakehouse** is now your production-grade, drift-protected, canonical database repository!