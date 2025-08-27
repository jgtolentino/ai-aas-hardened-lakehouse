# Scout Dashboard Migration Checklist

**Date**: August 28, 2025  
**Source**: scout-analytics-blueprint-doc  
**Target**: ai-aas-hardened-lakehouse  
**Status**: Ready for execution

## Migration Overview

This checklist provides step-by-step instructions to migrate the complete Scout Analytics Platform from the blueprint repository to the main enterprise repository.

**Effort Estimate**: 9-14 days  
**Complexity**: High (500+ person-hours of work to migrate)  
**Risk**: Medium (well-tested source code)

---

## Pre-Migration Assessment ✅

- [x] Gap analysis completed (`docs/scout/gap-analysis.md`)
- [x] Blueprint repository validated (100% feature complete)
- [x] Main repository current state documented
- [x] Stakeholder approval for migration approach
- [x] Development environment prepared

---

## Phase 1: Core Infrastructure (Days 1-3)

### 1.1 Database Schema Migration
**Priority**: Critical 🚨  
**Effort**: 1 day

```bash
# Step 1: Export blueprint database schema
cd /Users/tbwa/scout-analytics-blueprint-doc
supabase db dump --schema scout --data-only > scout-data.sql
supabase db dump --schema scout --schema-only > scout-schema.sql

# Step 2: Copy migration files
cp -r supabase/migrations/* /Users/tbwa/ai-aas-hardened-lakehouse/supabase/migrations/

# Step 3: Apply migrations to main repository
cd /Users/tbwa/ai-aas-hardened-lakehouse
supabase db reset
supabase migration repair
supabase db push
```

**Validation**: 
- [ ] 403 migrations applied successfully
- [ ] 147 scout.* tables created
- [ ] 12 API functions deployed
- [ ] RLS policies active

### 1.2 Package Dependencies
**Priority**: Critical 🚨  
**Effort**: 0.5 day

```bash
# Copy package.json dependencies from blueprint
cd /Users/tbwa/ai-aas-hardened-lakehouse

# Required dependencies from blueprint:
npm install \
  @supabase/supabase-js@^2.45.4 \
  @tanstack/react-query@^5.56.2 \
  @radix-ui/react-accordion@^1.2.0 \
  @radix-ui/react-alert-dialog@^1.1.1 \
  @radix-ui/react-aspect-ratio@^1.1.0 \
  @radix-ui/react-avatar@^1.1.0 \
  @radix-ui/react-checkbox@^1.1.1 \
  @radix-ui/react-collapsible@^1.1.0 \
  @radix-ui/react-dialog@^1.1.1 \
  @radix-ui/react-dropdown-menu@^2.1.1 \
  @radix-ui/react-hover-card@^1.1.1 \
  @radix-ui/react-label@^2.1.0 \
  @radix-ui/react-menubar@^1.1.1 \
  @radix-ui/react-navigation-menu@^1.2.0 \
  @radix-ui/react-popover@^1.1.1 \
  @radix-ui/react-progress@^1.1.0 \
  @radix-ui/react-radio-group@^1.2.0 \
  @radix-ui/react-scroll-area@^1.1.0 \
  @radix-ui/react-select@^2.1.1 \
  @radix-ui/react-separator@^1.1.0 \
  @radix-ui/react-slider@^1.2.0 \
  @radix-ui/react-switch@^1.1.0 \
  @radix-ui/react-tabs@^1.1.0 \
  @radix-ui/react-toast@^1.2.1 \
  @radix-ui/react-toggle@^1.1.0 \
  @radix-ui/react-toggle-group@^1.1.0 \
  @radix-ui/react-tooltip@^1.1.2 \
  @visx/axis@^3.10.1 \
  @visx/curve@^3.3.0 \
  @visx/gradient@^3.3.0 \
  @visx/group@^3.3.0 \
  @visx/scale@^3.5.0 \
  @visx/shape@^3.5.0 \
  clsx@^2.1.1 \
  class-variance-authority@^0.7.0 \
  cmdk@^1.0.0 \
  d3@^7.9.0 \
  date-fns@^3.6.0 \
  lucide-react@^0.436.0 \
  mapbox-gl@^3.6.0 \
  react@^18.3.1 \
  react-day-picker@^8.10.1 \
  react-dom@^18.3.1 \
  react-hook-form@^7.53.0 \
  react-resizable-panels@^2.1.1 \
  react-router-dom@^6.26.2 \
  recharts@^2.12.7 \
  sonner@^1.5.0 \
  tailwind-merge@^2.5.2 \
  tailwindcss-animate@^1.0.7 \
  vaul@^0.9.1 \
  zod@^3.23.8
```

**Validation**:
- [ ] All dependencies installed successfully
- [ ] No version conflicts
- [ ] TypeScript builds without errors

### 1.3 Build System Configuration
**Priority**: High  
**Effort**: 0.5 day

```bash
# Copy configuration files from blueprint
cp /Users/tbwa/scout-analytics-blueprint-doc/vite.config.ts ./
cp /Users/tbwa/scout-analytics-blueprint-doc/tailwind.config.ts ./
cp /Users/tbwa/scout-analytics-blueprint-doc/tsconfig.json ./
cp /Users/tbwa/scout-analytics-blueprint-doc/components.json ./
cp /Users/tbwa/scout-analytics-blueprint-doc/postcss.config.js ./
```

**Validation**:
- [ ] `npm run build` succeeds
- [ ] `npm run dev` starts without errors
- [ ] Tailwind CSS loads correctly

---

## Phase 2: Component Migration (Days 4-7)

### 2.1 UI Component Library (shadcn/ui)
**Priority**: High  
**Effort**: 1 day

```bash
# Create apps/scout-dashboard directory structure
mkdir -p apps/scout-dashboard/src/components/ui

# Copy all 23 shadcn components
cp -r /Users/tbwa/scout-analytics-blueprint-doc/src/components/ui/* \
  apps/scout-dashboard/src/components/ui/

# Components to verify:
# - accordion.tsx, alert-dialog.tsx, alert.tsx, aspect-ratio.tsx
# - avatar.tsx, badge.tsx, breadcrumb.tsx, button.tsx, calendar.tsx
# - card.tsx, carousel.tsx, chart.tsx, checkbox.tsx, collapsible.tsx
# - command.tsx, context-menu.tsx, dialog.tsx, drawer.tsx
# - dropdown-menu.tsx, form.tsx, hover-card.tsx, input-otp.tsx
# - input.tsx, label.tsx, menubar.tsx, navigation-menu.tsx
# - pagination.tsx, popover.tsx, progress.tsx, radio-group.tsx
# - resizable.tsx, scroll-area.tsx, select.tsx, separator.tsx
# - sheet.tsx, sidebar.tsx, skeleton.tsx, slider.tsx, sonner.tsx
# - switch.tsx, table.tsx, tabs.tsx, textarea.tsx, toast.tsx
# - toaster.tsx, toggle-group.tsx, toggle.tsx, tooltip.tsx
```

**Validation**:
- [ ] All 23 components copied
- [ ] TypeScript compiles without errors
- [ ] Components render correctly

### 2.2 Layout Components
**Priority**: Critical 🚨  
**Effort**: 1 day

```bash
# Copy core layout components
cp /Users/tbwa/scout-analytics-blueprint-doc/src/components/Layout.tsx \
  apps/scout-dashboard/src/components/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/components/Navbar.tsx \
  apps/scout-dashboard/src/components/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/components/Sidebar.tsx \
  apps/scout-dashboard/src/components/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/components/FilterBar.tsx \
  apps/scout-dashboard/src/components/
```

**Validation**:
- [ ] Layout renders with sidebar navigation
- [ ] Navbar displays correctly
- [ ] Mobile responsiveness works
- [ ] Navigation links function

### 2.3 Chart Components  
**Priority**: Critical 🚨  
**Effort**: 2 days

```bash
# Copy chart components
mkdir -p apps/scout-dashboard/src/components/charts

cp /Users/tbwa/scout-analytics-blueprint-doc/src/components/RevenueChart.tsx \
  apps/scout-dashboard/src/components/charts/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/components/BrandBarChart.tsx \
  apps/scout-dashboard/src/components/charts/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/components/TrendChart.tsx \
  apps/scout-dashboard/src/components/charts/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/components/MetricCard.tsx \
  apps/scout-dashboard/src/components/charts/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/components/TopPerformers.tsx \
  apps/scout-dashboard/src/components/charts/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/components/TransactionsTable.tsx \
  apps/scout-dashboard/src/components/charts/

# Copy advanced chart components (visx)
mkdir -p apps/scout-dashboard/src/components/visx

cp -r /Users/tbwa/scout-analytics-blueprint-doc/src/components/visx/* \
  apps/scout-dashboard/src/components/visx/
```

**Validation**:
- [ ] All chart components render
- [ ] Recharts integration works
- [ ] visx components display
- [ ] Responsive behavior verified

### 2.4 AI and Domain Components
**Priority**: Medium  
**Effort**: 1 day

```bash
# Copy AI components
cp /Users/tbwa/scout-analytics-blueprint-doc/src/components/AIInsights.tsx \
  apps/scout-dashboard/src/components/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/components/AIQueryInterface.tsx \
  apps/scout-dashboard/src/components/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/components/ChatSwitcher.tsx \
  apps/scout-dashboard/src/components/

# Copy domain-specific components
mkdir -p apps/scout-dashboard/src/components/sari-sari
cp -r /Users/tbwa/scout-analytics-blueprint-doc/src/components/sari-sari/* \
  apps/scout-dashboard/src/components/sari-sari/
```

**Validation**:
- [ ] AI components load
- [ ] Domain components render
- [ ] Interactive features work

---

## Phase 3: Page Components & Routing (Days 8-10)

### 3.1 Dashboard Pages Migration
**Priority**: Critical 🚨  
**Effort**: 2 days

```bash
# Create pages directory
mkdir -p apps/scout-dashboard/src/pages

# Copy all 9 dashboard modules
cp /Users/tbwa/scout-analytics-blueprint-doc/src/pages/ExecutiveOverview.tsx \
  apps/scout-dashboard/src/pages/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/pages/Transactions.tsx \
  apps/scout-dashboard/src/pages/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/pages/ProductMix.tsx \
  apps/scout-dashboard/src/pages/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/pages/Behavior.tsx \
  apps/scout-dashboard/src/pages/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/pages/Profiling.tsx \
  apps/scout-dashboard/src/pages/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/pages/Geo.tsx \
  apps/scout-dashboard/src/pages/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/pages/CompetitiveGeo.tsx \
  apps/scout-dashboard/src/pages/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/pages/AIInsights.tsx \
  apps/scout-dashboard/src/pages/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/pages/SemanticLayer.tsx \
  apps/scout-dashboard/src/pages/

# Copy index and routing
cp /Users/tbwa/scout-analytics-blueprint-doc/src/pages/Index.tsx \
  apps/scout-dashboard/src/pages/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/pages/Dashboard.tsx \
  apps/scout-dashboard/src/pages/
```

**Validation**:
- [ ] All 9 modules accessible via routing
- [ ] Pages load without JavaScript errors
- [ ] Navigation between pages works
- [ ] Responsive layouts function

### 3.2 Routing Configuration
**Priority**: High  
**Effort**: 0.5 day

```bash
# Copy App.tsx and routing setup
cp /Users/tbwa/scout-analytics-blueprint-doc/src/App.tsx \
  apps/scout-dashboard/src/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/main.tsx \
  apps/scout-dashboard/src/
```

**Validation**:
- [ ] React Router works correctly
- [ ] All routes accessible
- [ ] Browser history navigation
- [ ] Deep linking functions

---

## Phase 4: Data Integration Layer (Days 11-12)

### 4.1 React Hooks Migration
**Priority**: Critical 🚨  
**Effort**: 1 day

```bash
# Copy data hooks
mkdir -p apps/scout-dashboard/src/hooks

cp /Users/tbwa/scout-analytics-blueprint-doc/src/hooks/useScoutData.ts \
  apps/scout-dashboard/src/hooks/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/hooks/useGoldDal.ts \
  apps/scout-dashboard/src/hooks/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/hooks/useSariSariData.ts \
  apps/scout-dashboard/src/hooks/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/hooks/useAIInsights.ts \
  apps/scout-dashboard/src/hooks/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/hooks/useGeoCompetitive.ts \
  apps/scout-dashboard/src/hooks/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/hooks/useDQ.ts \
  apps/scout-dashboard/src/hooks/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/hooks/useSemanticQuery.ts \
  apps/scout-dashboard/src/hooks/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/hooks/useSemanticSuggest.ts \
  apps/scout-dashboard/src/hooks/
```

**Validation**:
- [ ] All hooks compile without errors
- [ ] Data fetching works correctly
- [ ] React Query integration active
- [ ] Error handling functional

### 4.2 Service Layer Migration
**Priority**: High  
**Effort**: 0.5 day

```bash
# Copy service layer
mkdir -p apps/scout-dashboard/src/services

cp -r /Users/tbwa/scout-analytics-blueprint-doc/src/services/* \
  apps/scout-dashboard/src/services/

# Copy utility files
mkdir -p apps/scout-dashboard/src/lib
cp -r /Users/tbwa/scout-analytics-blueprint-doc/src/lib/* \
  apps/scout-dashboard/src/lib/

# Copy integrations
mkdir -p apps/scout-dashboard/src/integrations
cp -r /Users/tbwa/scout-analytics-blueprint-doc/src/integrations/* \
  apps/scout-dashboard/src/integrations/
```

**Validation**:
- [ ] Supabase client configured
- [ ] API calls succeed
- [ ] Data transformations work
- [ ] Type definitions loaded

---

## Phase 5: Styling & Assets (Day 13)

### 5.1 Styling Migration
**Priority**: High  
**Effort**: 0.5 day

```bash
# Copy styles
mkdir -p apps/scout-dashboard/src/styles
cp -r /Users/tbwa/scout-analytics-blueprint-doc/src/styles/* \
  apps/scout-dashboard/src/styles/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/index.css \
  apps/scout-dashboard/src/

cp /Users/tbwa/scout-analytics-blueprint-doc/src/App.css \
  apps/scout-dashboard/src/
```

**Validation**:
- [ ] Tailwind CSS classes work
- [ ] Custom CSS loads
- [ ] Theme consistency maintained
- [ ] Dark/light mode functions

### 5.2 Static Assets
**Priority**: Low  
**Effort**: 0.25 day

```bash
# Copy assets
mkdir -p apps/scout-dashboard/public
cp -r /Users/tbwa/scout-analytics-blueprint-doc/public/* \
  apps/scout-dashboard/public/

mkdir -p apps/scout-dashboard/src/assets  
cp -r /Users/tbwa/scout-analytics-blueprint-doc/src/assets/* \
  apps/scout-dashboard/src/assets/
```

**Validation**:
- [ ] Images load correctly
- [ ] Icons display properly
- [ ] Favicon works

---

## Phase 6: Testing & Validation (Day 14)

### 6.1 Component Testing
**Priority**: High  
**Effort**: 0.5 day

```bash
# Run comprehensive tests
cd apps/scout-dashboard

# Build test
npm run build

# Development server test  
npm run dev

# Check for console errors
# Verify all pages load
# Test all interactive features
```

**Validation Checklist**:
- [ ] Build completes without errors
- [ ] Development server starts successfully
- [ ] All 9 dashboard modules load
- [ ] Charts render with data
- [ ] Navigation functions correctly
- [ ] API calls succeed
- [ ] Performance acceptable (<5s initial load)

### 6.2 Data Integration Testing
**Priority**: Critical 🚨  
**Effort**: 0.5 day

```bash
# Test database connectivity
node -e "
import { supabase } from './src/lib/supabase.ts';
supabase.from('scout_transactions').select('count').then(console.log);
"

# Test each RPC function
# - scout.get_executive_kpis()
# - scout.get_revenue_trend()  
# - scout.get_top_performers()
# - scout.get_ai_insights()
# And 8 more functions...
```

**Validation**:
- [ ] All 12 RPC functions respond
- [ ] Data displays in components
- [ ] Real-time updates work
- [ ] Error states handle gracefully

---

## Post-Migration Tasks

### Documentation Update
- [ ] Update README.md with new structure
- [ ] Document component usage
- [ ] Create troubleshooting guide
- [ ] Update deployment instructions

### Environment Configuration
- [ ] Set up environment variables
- [ ] Configure CI/CD pipeline
- [ ] Update Vercel deployment settings
- [ ] Set up monitoring and logging

### Performance Optimization
- [ ] Run Lighthouse audits
- [ ] Optimize bundle size
- [ ] Configure caching strategies
- [ ] Set up CDN for assets

### Security Review
- [ ] Validate RLS policies
- [ ] Check API security
- [ ] Review authentication flow
- [ ] Run security scans

---

## Rollback Plan

If migration fails, rollback procedure:

1. **Database Rollback**:
   ```bash
   cd /Users/tbwa/ai-aas-hardened-lakehouse
   git checkout HEAD~1 supabase/migrations/
   supabase db reset
   ```

2. **Code Rollback**:
   ```bash
   git stash  # Save work in progress
   git checkout main  # Return to stable state
   ```

3. **Use Blueprint Repository**:
   - Continue using `/Users/tbwa/scout-analytics-blueprint-doc` as production
   - Deploy directly from blueprint repository
   - Plan future integration more carefully

---

## Success Criteria

Migration considered successful when:
- [ ] All 9 dashboard modules functional
- [ ] Performance meets requirements (average <500ms)
- [ ] Security policies active
- [ ] CI/CD pipeline working
- [ ] Documentation complete
- [ ] Team trained on new structure

---

## Next Steps After Migration

1. **Consolidation** (Week 2):
   - Remove duplicate functionality
   - Unify CI/CD pipelines
   - Integrate with enterprise authentication

2. **Enhancement** (Week 3-4):
   - Add missing enterprise features
   - Implement custom branding
   - Optimize for specific use cases

3. **Training** (Week 4):
   - Train development team
   - Document troubleshooting
   - Set up monitoring alerts

---

**Migration Lead**: [Assign team member]  
**Start Date**: [Set date]  
**Target Completion**: [Set date + 14 days]  
**Review Date**: [Set weekly review schedule]