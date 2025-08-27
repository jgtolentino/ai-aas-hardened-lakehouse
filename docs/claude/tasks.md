# Tasks — Scout Analytics Blueprint → Production

## 📄 PRD Review
- [ ] Parse SCOUT_DASHBOARD_VISUALIZATION_BLUEPRINT.md
- [ ] Extract all 30+ charts + 5 page layout
- [ ] Build mapping: chart → metric → Supabase RPC
- [ ] Flag missing RPCs

## 🧱 Component Integration
- [ ] Import DonutChart.tsx, HeatmapChart.tsx, ChartRegistry
- [ ] Scaffold missing TSX components from blueprint
- [ ] Add to `pages/` routing (Executive, Analytics, Consumer, Geographic, Reports)

## 🔌 Supabase RPC Layer
- [ ] Check RPC coverage in `/supabase/functions`
- [ ] Auto-generate RPCs for uncovered metrics
- [ ] Add `.maybeSingle()` and React Query hooks

## 🖼️ Layout & Grid
- [ ] Apply VISUAL_LAYOUT_GRID.md rules to routes
- [ ] Confirm 12-col grid + responsive sizing
- [ ] Validate KPI rows + side nav

## 🤖 AI Overlays
- [ ] Connect `useAIInsights` to charts
- [ ] Ensure toggle between raw + AI annotated view
- [ ] Verify predictive metrics overlays (confidence intervals, forecasts)

## 🛡️ QA & Security
- [ ] Run gitleaks scan (expect only REDACTED placeholders)
- [ ] Verify pre-commit + CI gates still pass
- [ ] E2E smoke test with Supabase + Vercel preview

## 🚀 Deployment
- [ ] Deploy to Vercel preview branch
- [ ] Validate Supabase RLS enforcement on live queries
- [ ] Merge PR only after all checks green
