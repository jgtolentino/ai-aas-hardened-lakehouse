# 🔄 Supabase Sync Guide for AI-AAS-Hardened-Lakehouse

This guide ensures your enterprise data platform stays in sync with Supabase across all components.

## 📊 Project Architecture

```
ai-aas-hardened-lakehouse/
├── supabase/                    # Main Supabase configuration
│   ├── migrations/              # Database schema migrations
│   └── functions/               # Edge Functions
├── platform/scout/
│   ├── scout-databank/          # Submodule: Scout Dashboard UI
│   └── blueprint-dashboard/     # Legacy dashboard (to be replaced)
├── services/
│   ├── dashboard/               # New unified dashboard
│   ├── api/                     # Backend API service
│   └── worker/                  # Background jobs
└── .env.local                   # Environment configuration
```

## 🔧 1. Environment Configuration Sync

### Create Unified `.env.local` at Root

```bash
# In ai-aas-hardened-lakehouse root
cat > .env.local << 'EOF'
# Supabase Configuration
SUPABASE_URL=https://cxzllzyxwpyptfretryc.supabase.co
SUPABASE_PROJECT_REF=cxzllzyxwpyptfretryc
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4emxsenl4d3B5cHRmcmV0cnljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyMDYzMzQsImV4cCI6MjA3MDc4MjMzNH0.adA0EO89jw5uPH4qdL_aox6EbDPvJ28NcXGYW7u33Ok
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4emxsenl4d3B5cHRmcmV0cnljIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTIwNjMzNCwiZXhwIjoyMDcwNzgyMzM0fQ.vB9MIfInzX-ch4Kzb-d0_0ndNm-id1MVgQZuDBmtrdw
SUPABASE_ACCESS_TOKEN=sbp_05fcd9a214adbb2721dd54f2f39478e5efcbeffa
DB_PASSWORD=Postgres_26

# Frontend Environment
NEXT_PUBLIC_SUPABASE_URL=$SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
VITE_SUPABASE_URL=$SUPABASE_URL
VITE_SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# API Configuration
API_PORT=3000
WORKER_PORT=8080
DASHBOARD_PORT=5173
EOF
```

## 🔄 2. Submodule Sync Strategy

### Initialize & Update Submodules

```bash
# Initialize submodules if not already done
git submodule init
git submodule update --recursive --remote

# Fix broken submodule mapping
git rm --cached platform/scout/blueprint-dashboard
git submodule add https://github.com/jgtolentino/scout-databank-isolated.git platform/scout/scout-databank

# Keep submodules in sync
git submodule update --remote --merge
```

### Create Sync Script

```bash
cat > scripts/sync-supabase.sh << 'EOF'
#!/bin/bash
set -euo pipefail

echo "🔄 Syncing Supabase configuration..."

# Load environment
source .env.local

# 1. Sync environment to all services
for service in services/*/; do
    if [ -d "$service" ]; then
        echo "📋 Syncing env to $service"
        cp .env.local "$service/.env" 2>/dev/null || true
    fi
done

# 2. Sync to submodules
if [ -d "platform/scout/scout-databank" ]; then
    echo "📋 Syncing env to scout-databank submodule"
    cp .env.local platform/scout/scout-databank/.env.local
fi

# 3. Update frontend configs
if [ -f "services/dashboard/src/config/supabase.ts" ]; then
    cat > services/dashboard/src/config/supabase.ts << EOT
import { createClient } from '@supabase/supabase-js'

export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL || '$SUPABASE_URL',
  import.meta.env.VITE_SUPABASE_ANON_KEY || '$SUPABASE_ANON_KEY'
)
EOT
fi

# 4. Test connectivity
echo "🧪 Testing Supabase connectivity..."
curl -s -H "apikey: $SUPABASE_ANON_KEY" \
     -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
     "$SUPABASE_URL/rest/v1/" >/dev/null && echo "✅ API Connected" || echo "❌ API Failed"

echo "✅ Sync complete!"
EOF

chmod +x scripts/sync-supabase.sh
```

## 🚀 3. Frontend UI Sync

### Unified Dashboard Strategy

1. **Primary Dashboard**: `services/dashboard/` (Vite + React)
2. **Scout Module**: `platform/scout/scout-databank/` (Next.js submodule)
3. **Legacy**: `platform/scout/blueprint-dashboard/` (to be deprecated)

### Frontend Build Commands

```bash
# Build all frontends
npm run build:all

# Or individually:
cd services/dashboard && npm run build
cd platform/scout/scout-databank && npm run build
```

### Create Unified Build Script

```bash
cat > package.json << 'EOF'
{
  "name": "ai-aas-hardened-lakehouse",
  "scripts": {
    "sync": "./scripts/sync-supabase.sh",
    "build:dashboard": "cd services/dashboard && npm run build",
    "build:scout": "cd platform/scout/scout-databank && npm run build",
    "build:all": "npm run build:dashboard && npm run build:scout",
    "dev:dashboard": "cd services/dashboard && npm run dev",
    "dev:scout": "cd platform/scout/scout-databank && npm run dev",
    "migrate": "npx supabase db push",
    "deploy:functions": "npx supabase functions deploy --all"
  }
}
EOF
```

## 📡 4. Supabase Migration Sync

### Migration Strategy

```bash
# Create unified migration
cat > supabase/migrations/$(date +%Y%m%d%H%M%S)_unified_sync.sql << 'SQL'
-- Ensure all schemas exist
CREATE SCHEMA IF NOT EXISTS scout;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS warehouse;

-- Grant permissions
GRANT USAGE ON SCHEMA scout TO anon, authenticated;
GRANT USAGE ON SCHEMA analytics TO anon, authenticated;
GRANT USAGE ON SCHEMA warehouse TO anon, authenticated;
SQL

# Apply migrations
npx supabase db push
```

## 🔐 5. MCP Configuration for Project

Create `.mcp.yaml` in project root:

```yaml
mcpServers:
  supabase_lakehouse:
    command: npx
    args: 
      - "-y"
      - "@supabase/mcp-server-supabase@latest"
      - "--project-ref=${SUPABASE_PROJECT_REF}"
      - "--access-token=${SUPABASE_ACCESS_TOKEN}"
    env:
      SUPABASE_ACCESS_TOKEN: "${SUPABASE_ACCESS_TOKEN}"
      SUPABASE_PROJECT_REF: "${SUPABASE_PROJECT_REF}"
  filesystem:
    command: npx
    args: ["-y", "@modelcontextprotocol/server-filesystem", "."]
```

## 🚨 6. Git Hooks for Auto-Sync

Create `.git/hooks/post-merge`:

```bash
#!/bin/bash
# Auto-sync after git pull
if [ -f "scripts/sync-supabase.sh" ]; then
    ./scripts/sync-supabase.sh
fi
```

## 📋 7. Daily Sync Checklist

```bash
# Morning sync routine
git pull origin main
git submodule update --remote --merge
./scripts/sync-supabase.sh
npm run build:all
npm run migrate
```

## 🎯 8. Deployment Sync

```bash
# Deploy everything to production
./scripts/sync-supabase.sh
npm run build:all
npm run migrate
npm run deploy:functions
vercel --prod  # For frontend deployments
```

## 🔍 9. Verification

```bash
# Check all components are synced
curl -s $SUPABASE_URL/rest/v1/ -H "apikey: $SUPABASE_ANON_KEY"
curl -s http://localhost:5173  # Dashboard
curl -s http://localhost:3000  # API
curl -s http://localhost:3001  # Scout
```

## 🚀 Quick Commands

```bash
# Full sync and deploy
npm run sync && npm run build:all && npm run migrate

# Development mode with sync
npm run sync && npm run dev:dashboard

# Update submodules
git submodule foreach git pull origin main
```

---

Run `./scripts/sync-supabase.sh` to keep everything in sync!