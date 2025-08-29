#!/bin/bash

# Scout Dashboard v6.0 - Deployment Validation Script

set -e

echo "🚀 Scout Dashboard v6.0 - Deployment Validation"
echo "================================================"

# Check PRD exists
if [ -f "docs/prd/PRD-SCOUT-UI-v6.0.md" ]; then
    echo "✅ PRD documentation found"
else
    echo "❌ PRD documentation missing"
    exit 1
fi

# Check dashboard config
if [ -f "apps/scout-dashboard/dashboard.config.json" ]; then
    echo "✅ Dashboard configuration found"
else
    echo "❌ Dashboard configuration missing"
    exit 1
fi

# Check all tab routes exist
TABS=("overview" "mix" "competitive" "geography" "consumers" "ai")
for tab in "${TABS[@]}"; do
    if [ -f "apps/scout-dashboard/app/$tab/page.tsx" ]; then
        echo "✅ Tab route found: $tab"
    else
        echo "❌ Tab route missing: $tab"
        exit 1
    fi
done

# Check Zustand store
if [ -f "apps/scout-dashboard/src/store/useFilters.ts" ]; then
    echo "✅ Filter store found"
else
    echo "❌ Filter store missing"
    exit 1
fi

# Check contracts
if [ -f "packages/contracts/src/scout.ts" ]; then
    echo "✅ TypeScript contracts found"
else
    echo "❌ TypeScript contracts missing"
    exit 1
fi

# Check data hooks
if [ -f "apps/scout-dashboard/src/data/hooks.ts" ]; then
    echo "✅ Data hooks found"
else
    echo "❌ Data hooks missing"
    exit 1
fi

# Check Supabase client
if [ -f "apps/scout-dashboard/src/data/supabase.ts" ]; then
    echo "✅ Supabase client found"
else
    echo "❌ Supabase client missing"
    exit 1
fi

# Check UI components
if [ -f "apps/scout-ui/src/components/Kpi/KpiCard.tsx" ]; then
    echo "✅ UI components found"
else
    echo "❌ UI components missing"
    exit 1
fi

echo ""
echo "================================================"
echo "✅ All Scout Dashboard v6.0 components are in place!"
echo ""
echo "Next steps:"
echo "1. Install dependencies: cd apps/scout-dashboard && npm install"
echo "2. Add environment variables to .env.local"
echo "3. Run development server: npm run dev"
echo "4. Implement remaining chart components"
echo "5. Connect to existing Supabase RPCs"
echo ""
echo "Ready to build! 🎯"
