# Planning — Scout Analytics Blueprint → Production

## Current State
- `/Users/tbwa/scout-analytics-blueprint-doc` contains:
  - **SCOUT_DASHBOARD_VISUALIZATION_BLUEPRINT.md** (30+ charts, 5 pages, AI overlays)
  - **VISUAL_LAYOUT_GRID.md** (grid rules, responsive design)
  - **chart-type-suggestions.yaml** (rules for chart selection)
  - **TSX stubs** (DonutChart.tsx, HeatmapChart.tsx, registry)

- ai-aas-hardened-lakehouse repo already has:
  - Supabase integration
  - Medallion schema (v5.2, gold/platinum)
  - CI/CD pipelines
  - MCP Hub adapters for automation

## Gap Analysis
- ✅ Data layer exists and is production-secure
- ✅ CI/CD + security gates working
- ❌ Frontend integration incomplete: blueprint TSX files not wired into dashboard pages
- ❌ AI overlays defined in blueprint but not linked to Supabase RPCs
- ❌ Layout/grid spec not imported into React routing
- ❌ No end-to-end smoke test of dashboard pages in Vercel

## Roadmap
1. **Blueprint Review**
   - Parse PRD + blueprint docs
   - Extract chart → metric → RPC mappings
2. **Component Integration**
   - Wire DonutChart, HeatmapChart, Chart Registry into app routes
   - Add missing components from blueprint
3. **Supabase RPC Layer**
   - Confirm each chart's data source has a matching RPC
   - Generate if missing
4. **Layout Application**
   - Apply VISUAL_LAYOUT_GRID rules to dashboard pages
   - Validate responsive behavior
5. **AI Insight Integration**
   - Attach AI overlay hooks (`useAIInsights`) to key charts
   - Ensure toggle between raw data vs AI annotation
6. **Production Deployment**
   - Deploy to Vercel preview
   - Run security + gitleaks + CI/CD checks
   - Validate supabase-diff produces no drift

## Timeline
- Week 1: PRD → gap doc + component mapping
- Week 2: Integrate charts + Supabase RPCs
- Week 3: Apply grid/layout, AI overlays
- Week 4: Full QA, deploy preview → merge to main
