#!/bin/bash

# Scout Dashboard v6.0 - Commit and Merge to Main

set -e

echo "📦 Scout Dashboard v6.0 - Preparing to merge to main"
echo "===================================================="

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

# Add all Scout v6.0 files
echo ""
echo "Adding Scout v6.0 files..."
git add docs/prd/PRD-SCOUT-UI-v6.0.md
git add apps/scout-dashboard/dashboard.config.json
git add apps/scout-dashboard/app/overview/page.tsx
git add apps/scout-dashboard/app/mix/page.tsx
git add apps/scout-dashboard/app/competitive/page.tsx
git add apps/scout-dashboard/app/geography/page.tsx
git add apps/scout-dashboard/app/consumers/page.tsx
git add apps/scout-dashboard/app/ai/page.tsx
git add apps/scout-dashboard/src/store/useFilters.ts
git add apps/scout-dashboard/src/data/hooks.ts
git add apps/scout-dashboard/src/data/supabase.ts
git add packages/contracts/src/scout.ts
git add apps/scout-ui/src/components/Kpi/KpiCard.tsx
git add apps/scout-ui/src/components/Skeleton.tsx
git add validate-scout-v6.sh
git add SCOUT_V6_IMPLEMENTATION.md

# Commit with comprehensive message
echo ""
echo "Creating commit..."
git commit -m "feat(scout): implement Scout Analytics Dashboard v6.0 frontend architecture

- Add comprehensive PRD for Scout v6.0 with 6-tab analytics dashboard
- Scaffold all Next.js 14 App Router pages (overview/mix/competitive/geography/consumers/ai)
- Implement Zustand filter store with URL sync and session persistence
- Create TypeScript contracts for all Supabase RPCs (KPIs, trends, geo, demographics)
- Set up React Query hooks for data fetching with proper caching strategies
- Initialize Supabase client with realtime filter broadcasting
- Add initial UI components (KpiCard, Skeleton) in scout-ui library
- Configure JSON-driven dashboard layout (12-col grid, responsive)
- Prepare for AI overlays via MCP router (no tokens in client)
- Support multi-face theming (pbi/tableau/superset via CSS vars)

Aligns with existing:
- platform/scout/blueprint-dashboard patterns
- Figma Connect configuration
- MCP hub infrastructure
- Supabase RLS/RPC architecture

Next steps:
- Install dependencies (zustand, react-query, recharts, mapbox-gl)
- Implement remaining chart components
- Connect to production Supabase RPCs
- Add AI overlay components
- Wire up export functionality

Refs: PRD-SCOUT-UI-v6.0
Co-authored-by: InsightPulseAI <jake@insightpulse.ai>"

echo "✅ Commit created!"
echo ""

# Prompt for merge
echo "Ready to merge to main. Choose an option:"
echo "1) Merge directly to main (if you have permissions)"
echo "2) Create a pull request"
echo "3) Just stay on current branch"
echo ""
read -p "Enter choice (1-3): " choice

case $choice in
    1)
        echo "Merging to main..."
        git checkout main
        git pull origin main
        git merge $CURRENT_BRANCH --no-ff -m "Merge branch '$CURRENT_BRANCH': Scout Dashboard v6.0 implementation"
        echo ""
        echo "✅ Merged to main locally!"
        echo "Run 'git push origin main' to push to remote"
        ;;
    2)
        echo "Pushing branch for PR..."
        git push origin $CURRENT_BRANCH
        echo ""
        echo "✅ Branch pushed! Create PR at:"
        echo "https://github.com/your-org/ai-aas-hardened-lakehouse/compare/$CURRENT_BRANCH?expand=1"
        ;;
    3)
        echo "Staying on $CURRENT_BRANCH"
        echo "✅ Commit complete. Run 'git push' when ready."
        ;;
esac

echo ""
echo "===================================================="
echo "🎯 Scout Dashboard v6.0 implementation committed!"
