# GitHub Actions Secrets Configuration

Set these in **Settings → Secrets and variables → Actions**:

## Required Secrets

### Database
- `PGURI` - Full Postgres URI for Supabase
  ```
  postgresql://postgres:[YOUR-PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres
  ```

### Supabase
- `SUPABASE_URL` - Your Supabase project URL
  ```
  https://[PROJECT-REF].supabase.co
  ```
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key (keep secret!)

### Superset Connection
- `SB_HOST` - Supabase hostname
  ```
  db.[PROJECT-REF].supabase.co
  ```
- `SB_PORT` - Database port (usually `5432`)
- `SB_DB` - Database name (usually `postgres`)
- `SB_USER` - Database user (usually `postgres`)
- `SB_PASS` - Database password
- `SUPERSET_DB_NAME` - Name for the database in Superset

### Superset API
- `SUPERSET_BASE` - Superset instance URL
  ```
  https://your-superset.example.com
  ```
- `SUPERSET_USER` - Admin username
- `SUPERSET_PASSWORD` - Admin password

### dbt Configuration
- `DBT_PROFILES_YML` - Complete profiles.yml content
  ```yaml
  scout:
    outputs:
      prod:
        type: postgres
        host: db.[PROJECT-REF].supabase.co
        port: 5432
        user: postgres
        password: [YOUR-PASSWORD]
        database: postgres
        schema: scout
        threads: 4
        keepalives_idle: 0
        search_path: [scout]
  ```

### Vercel (Optional)
- `VERCEL_TOKEN` - Personal access token from Vercel
- `VERCEL_ORG_ID` - Your Vercel organization ID
- `VERCEL_DOCS_PROJECT_ID` - Project ID for docs site
- `VERCEL_SCOUT_PROJECT_ID` - Project ID for Scout Dashboard

## Setting Secrets via GitHub CLI

```bash
# Database
gh secret set PGURI --body "postgresql://postgres:YOUR_PASSWORD@db.PROJECT_REF.supabase.co:5432/postgres"

# Supabase
gh secret set SUPABASE_URL --body "https://PROJECT_REF.supabase.co"
gh secret set SUPABASE_SERVICE_ROLE_KEY --body "YOUR_SERVICE_ROLE_KEY"

# Superset Connection
gh secret set SB_HOST --body "db.PROJECT_REF.supabase.co"
gh secret set SB_PORT --body "5432"
gh secret set SB_DB --body "postgres"
gh secret set SB_USER --body "postgres"
gh secret set SB_PASS --body "YOUR_PASSWORD"
gh secret set SUPERSET_DB_NAME --body "Scout Analytics"

# Superset API
gh secret set SUPERSET_BASE --body "https://your-superset.example.com"
gh secret set SUPERSET_USER --body "admin"
gh secret set SUPERSET_PASSWORD --body "YOUR_ADMIN_PASSWORD"

# dbt Profile
gh secret set DBT_PROFILES_YML < ~/.dbt/profiles.yml

# Vercel (if using)
gh secret set VERCEL_TOKEN --body "YOUR_VERCEL_TOKEN"
gh secret set VERCEL_ORG_ID --body "YOUR_ORG_ID"
gh secret set VERCEL_DOCS_PROJECT_ID --body "YOUR_DOCS_PROJECT_ID"
gh secret set VERCEL_SCOUT_PROJECT_ID --body "YOUR_SCOUT_PROJECT_ID"
```

### Notifications (Optional)
- `SLACK_WEBHOOK_URL` - Slack incoming webhook URL for deployment notifications

## Variables (not secrets)

Set these in **Settings → Secrets and variables → Actions → Variables**:

- `DOCS_PUBLIC_URL` - Public URL of deployed docs site
  ```
  https://docs.your-domain.com
  ```
- `SCOUT_PUBLIC_URL` - Public URL of Scout Dashboard
  ```
  https://scout.your-domain.com
  ```

## Setting Variables via GitHub CLI

```bash
# Set public URLs for smoke checks
gh variable set DOCS_PUBLIC_URL --body "https://docs.example.com"
gh variable set SCOUT_PUBLIC_URL --body "https://scout.example.com"
```

## Verification

After setting secrets, trigger a manual workflow run:
```bash
gh workflow run ci-production.yml
```

Check the workflow logs for any missing secrets or configuration issues.

## Post-Deployment Verification

Run the verification script locally:
```bash
# Export required env vars
export PGURI="postgresql://..."
export SUPERSET_BASE="https://..."
export SUPERSET_USER="admin"
export SUPERSET_PASSWORD="..."
export SUPABASE_URL="https://..."
export SUPABASE_SERVICE_ROLE_KEY="..."

# Run verification
bash scripts/verify_deployment.sh
```