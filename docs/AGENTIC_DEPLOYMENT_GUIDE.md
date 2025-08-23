# 🚀 Agentic Analytics Deployment Guide

## 🔒 Security First

This deployment uses secure secret management. **Never commit secrets to git**.

### Secret Management Options

#### Option 1: 1Password CLI (Recommended)
```bash
# Install 1Password CLI
brew install --cask 1password-cli

# Sign in
op signin

# Secrets are loaded from .env.op.template
./scripts/deploy-agentic.sh
```

#### Option 2: Local .env File
```bash
# Copy example and fill with real values
cp .env.example .env
# Edit .env with your credentials

# Deploy
./scripts/deploy-agentic.sh
```

#### Option 3: Use existing ~/.env
```bash
# If you have /Users/tbwa/.env with Supabase credentials
# The script will auto-detect and use it
./scripts/deploy-agentic.sh
```

## 📦 What Gets Deployed

1. **Database Schemas**
   - `scout` - Analytics and monitoring
   - `deep_research` - Isko SKU scraping
   - `masterdata` - Brands and products catalog
   - `staging` - CSV import staging

2. **Core Components**
   - Agent Action Ledger (governance)
   - Monitors System (anomaly detection)
   - Contract Checks (data quality)
   - Agent Feed (UI notifications)
   - Isko Job Queue (SKU enrichment)

3. **Edge Functions**
   - `agentic-cron` - Scheduled monitoring

4. **Workers**
   - `isko-worker` - SKU data scraping

## 🛠️ Deployment Steps

### 1. Test Connection
```bash
./scripts/test-connection.sh
```

### 2. Deploy Everything
```bash
./scripts/deploy-agentic.sh
```

### 3. Import SKU Catalog
1. Go to [Supabase Dashboard](https://supabase.com/dashboard/project/cxzllzyxwpyptfretryc/editor)
2. Navigate to Table Editor → `staging.sku_catalog_upload`
3. Click "Import data from CSV"
4. Upload: `/Users/tbwa/Downloads/sku_catalog_with_telco_filled.csv`
5. After upload, run in SQL Editor:
   ```sql
   SELECT * FROM masterdata.import_sku_catalog();
   ```

### 4. Schedule Edge Function
```bash
supabase functions deploy agentic-cron \
  --project-ref cxzllzyxwpyptfretryc \
  --schedule '*/15 * * * *' \
  --no-verify-jwt
```

### 5. Start Isko Worker
```bash
# Option A: Direct
deno run -A workers/isko-worker/index.ts

# Option B: PM2
pm2 start --name isko-worker "deno run -A workers/isko-worker/index.ts"
```

## 🧪 Verification

### Quick Test
```bash
# Test monitors
psql "$SUPABASE_DB_URL" -c "SELECT scout.run_monitors();"

# Check agent feed
psql "$SUPABASE_DB_URL" -c "SELECT * FROM scout.agent_feed ORDER BY created_at DESC LIMIT 5;"

# Check brands/products
psql "$SUPABASE_DB_URL" -c "
  SELECT b.brand_name, COUNT(p.id) as products 
  FROM masterdata.brands b 
  LEFT JOIN masterdata.products p ON p.brand_id = b.id 
  GROUP BY b.brand_name 
  ORDER BY products DESC 
  LIMIT 10;
"
```

### Full Test Suite
```bash
./test-agentic-analytics.sh
```

## 📊 Monitoring

### Agent Feed UI
The agent feed provides real-time notifications:
- Monitor events
- Contract violations
- Isko job status
- System alerts

### Database Views
```sql
-- System overview
SELECT * FROM scout.v_system_status;

-- Monitor activity
SELECT * FROM scout.v_monitor_activity_24h;

-- Product catalog
SELECT * FROM masterdata.v_catalog_summary;
```

## 🚨 Troubleshooting

### Connection Issues
```bash
# Check environment
env | grep SUPABASE_ | sed 's/=.*/=***/'

# Test with explicit URL
SUPABASE_DB_URL="postgresql://..." ./scripts/test-connection.sh
```

### Migration Failures
```bash
# Check which migrations ran
psql "$SUPABASE_DB_URL" -c "
  SELECT filename, executed_at 
  FROM supabase_migrations.schema_migrations 
  WHERE filename LIKE '%agentic%' 
  ORDER BY executed_at;
"
```

### Edge Function Issues
```bash
# Check function logs
supabase functions logs agentic-cron --project-ref cxzllzyxwpyptfretryc
```

## 🔐 Security Checklist

- [ ] No secrets in git history
- [ ] Pre-commit hook installed
- [ ] Using 1Password or encrypted .env
- [ ] Database connections use SSL
- [ ] Service role keys never exposed to client

## 📚 Additional Resources

- [Operational Runbook](./AGENTIC_ANALYTICS_RUNBOOK.md)
- [Implementation Summary](./AGENTIC_ANALYTICS_SUMMARY.md)
- [Scout Analytics Architecture](./SCOUT_ARCHITECTURE.md)