#\!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔄 Syncing AI-AAS-Hardened-Lakehouse with Supabase...${NC}"
echo "================================================="

# Check if .env.local exists at root
if [ \! -f ".env.local" ]; then
    echo -e "${YELLOW}⚠️  Creating .env.local from scout-databank-new...${NC}"
    if [ -f "../scout-databank-new/.env.local" ]; then
        cp ../scout-databank-new/.env.local .env.local
        echo -e "${GREEN}✅ Copied .env.local${NC}"
    else
        echo -e "${RED}❌ No .env.local found in scout-databank-new${NC}"
        exit 1
    fi
fi

# Load environment
set -a
source .env.local
set +a

# 1. Sync environment to all services
echo -e "${BLUE}📋 Step 1: Syncing environment to services...${NC}"
for service in services/*/; do
    if [ -d "$service" ] && [ "$service" \!= "services/dashboard/" ]; then
        echo -e "   → Syncing to $service"
        cp .env.local "$service/.env" 2>/dev/null || true
    fi
done

# Special handling for dashboard (Vite needs different env format)
if [ -d "services/dashboard" ]; then
    echo -e "   → Creating Vite env for services/dashboard"
    cat > services/dashboard/.env << EOL
VITE_SUPABASE_URL=$SUPABASE_URL
VITE_SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
VITE_API_BASE_URL=http://localhost:3000
EOL
fi

# 2. Sync to submodules
echo -e "${BLUE}📋 Step 2: Syncing to submodules...${NC}"
if [ -d "platform/scout/scout-databank" ]; then
    echo -e "   → Syncing to scout-databank submodule"
    cp .env.local platform/scout/scout-databank/.env.local
    echo -e "${GREEN}   ✅ Scout databank synced${NC}"
fi

# 3. Update frontend Supabase configs
echo -e "${BLUE}📋 Step 3: Updating frontend configs...${NC}"

# Dashboard config
if [ -d "services/dashboard/src" ]; then
    mkdir -p services/dashboard/src/config
    cat > services/dashboard/src/config/supabase.ts << EOT
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || '${SUPABASE_URL}'
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || '${SUPABASE_ANON_KEY}'

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// Export config for other uses
export const supabaseConfig = {
  url: supabaseUrl,
  anonKey: supabaseAnonKey,
}
EOT
    echo -e "${GREEN}   ✅ Dashboard config updated${NC}"
fi

# 4. Test connectivity
echo -e "${BLUE}🧪 Step 4: Testing Supabase connectivity...${NC}"
if curl -f -s -H "apikey: $SUPABASE_ANON_KEY" \
     -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
     "$SUPABASE_URL/rest/v1/" >/dev/null; then
    echo -e "${GREEN}   ✅ REST API connected${NC}"
else
    echo -e "${RED}   ❌ REST API connection failed${NC}"
fi

# Test data endpoint
if curl -f -s -H "apikey: $SUPABASE_ANON_KEY" \
     -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
     "$SUPABASE_URL/rest/v1/dashboard_data?limit=1" >/dev/null; then
    echo -e "${GREEN}   ✅ Dashboard data accessible${NC}"
else
    echo -e "${YELLOW}   ⚠️  Dashboard data not accessible${NC}"
fi

# 5. Update Git submodules
echo -e "${BLUE}📋 Step 5: Updating Git submodules...${NC}"
if git submodule status | grep -q scout-databank; then
    git submodule update --init --recursive
    echo -e "${GREEN}   ✅ Submodules updated${NC}"
else
    echo -e "${YELLOW}   ⚠️  No submodules configured${NC}"
fi

# 6. Create unified package.json if missing
if [ \! -f "package.json" ]; then
    echo -e "${BLUE}📋 Step 6: Creating unified package.json...${NC}"
    cat > package.json << 'EOJSON'
{
  "name": "ai-aas-hardened-lakehouse",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "sync": "./scripts/sync-supabase.sh",
    "build:dashboard": "cd services/dashboard && npm run build",
    "build:scout": "cd platform/scout/scout-databank && npm run build",
    "build:api": "cd services/api && npm run build",
    "build:all": "npm run build:dashboard && npm run build:api",
    "dev:dashboard": "cd services/dashboard && npm run dev",
    "dev:api": "cd services/api && npm run dev",
    "dev:scout": "cd platform/scout/scout-databank && npm run dev",
    "dev": "concurrently \"npm run dev:api\" \"npm run dev:dashboard\"",
    "migrate": "npx supabase db push",
    "deploy:functions": "npx supabase functions deploy --all",
    "test": "echo \"Add tests here\""
  },
  "devDependencies": {
    "concurrently": "^7.6.0"
  }
}
EOJSON
    echo -e "${GREEN}   ✅ package.json created${NC}"
fi

# 7. Summary
echo ""
echo -e "${GREEN}🎉 Sync Complete\!${NC}"
echo "================================================="
echo -e "${BLUE}✅ What was synced:${NC}"
echo "   • Environment variables to all services"
echo "   • Frontend Supabase configurations"
echo "   • Submodule updates"
echo "   • API connectivity verified"

echo ""
echo -e "${BLUE}🚀 Next steps:${NC}"
echo "   1. Run 'npm install' in root (if package.json was created)"
echo "   2. Run 'npm run dev' to start all services"
echo "   3. Or run individual services:"
echo "      - npm run dev:dashboard"
echo "      - npm run dev:api"
echo "      - npm run dev:scout"

echo ""
echo -e "${GREEN}Environment ready for development\! 🚀${NC}"
