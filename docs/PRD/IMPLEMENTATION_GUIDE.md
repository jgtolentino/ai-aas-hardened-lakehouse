# Implementation Guide: From PRD to Production

## Overview
This guide connects the Financial Dashboard PRD to the Figma designs and implementation steps.

## Documents & Resources

### 1. Product Requirements
- **PRD**: [Financial Dashboard PRD](./FINANCIAL_DASHBOARD_PRD.md)
- **FigJam Board**: [PRD Template](https://www.figma.com/board/BLdSOtPdiUrIbmoNkyhmvF/Product-Requirements-Document--Copy-)

### 2. Design References
- **Dashboard Layout Ideas**: [Community Design](https://www.figma.com/design/yqn8tOpyslgLri0X7tq2eu/Dashboards-Layout-Ideas--Community-)
  - Node: `202-234`
  - Use for: General dashboard layout patterns

- **Finebank Financial Dashboard**: [Financial UI Kit](https://www.figma.com/design/Rjh4xxbrZr8otmfpPqiVPC/Finebank---Financial-Management-Dashboard-UI-Kits--Community-)
  - Node: `56-1396`
  - Use for: Financial metrics cards, charts, transaction tables

## Implementation Steps

### Phase 1: Design to Code Setup ✅

1. **Verify MCP Setup**
```bash
# Check Figma Dev Mode MCP is running
curl http://127.0.0.1:3845/health

# Verify Code Connect dependencies
cd /Users/tbwa/ai-aas-hardened-lakehouse
pnpm run figma:connect:validate
```

2. **Create Component Structure**
```bash
# Create dashboard component directories
mkdir -p apps/scout-ui/src/components/Dashboard/{components,hooks,types,utils}
```

### Phase 2: Generate Core Components

#### A. Metric Cards (from Finebank design)
1. Open Finebank design in Figma Desktop
2. Select metric card component
3. Use this command:
```
sc:figma-generate-ui
Generate MetricCard component from selected frame
Output to: apps/scout-ui/src/components/Dashboard/components/MetricCard.tsx
Include TypeScript types and Storybook story
```

#### B. Revenue Chart (from Dashboard Layout Ideas)
1. Open Dashboard Layout design
2. Select chart component
3. Generate with:
```
sc:figma-generate-ui
Generate RevenueChart component using Recharts
Match the selected Figma chart design
Include responsive behavior
```

#### C. Transaction Table
```typescript
// apps/scout-ui/src/components/Dashboard/components/TransactionTable.tsx
interface TransactionTableProps {
  data: Transaction[]
  columns: ColumnDef[]
  onRowClick?: (transaction: Transaction) => void
}
```

### Phase 3: Create Code Connect Mappings

```bash
# For each component, create a mapping
cat > apps/scout-ui/src/components/Dashboard/Dashboard.figma.tsx << 'EOF'
import figma from '@figma/code-connect'
import { Dashboard } from './Dashboard'

// Link to Finebank dashboard
figma.connect(Dashboard, 'https://www.figma.com/design/Rjh4xxbrZr8otmfpPqiVPC?node-id=56-1396', {
  props: {
    theme: figma.enum('Theme', {
      'Light': 'light',
      'Dark': 'dark'
    }),
    layout: figma.enum('Layout', {
      'Grid': 'grid',
      'List': 'list'
    }),
    period: figma.enum('Period', {
      'Daily': 'daily',
      'Weekly': 'weekly',
      'Monthly': 'monthly',
      'Yearly': 'yearly'
    })
  },
  example: (props) => <Dashboard {...props} />
})
EOF

# Publish to Figma
pnpm run figma:connect:publish
```

### Phase 4: Connect to Scout Data

```typescript
// apps/scout-ui/src/hooks/useDashboardData.ts
import { useSupabase } from '@/hooks/useSupabase'

export const useDashboardData = (period: string) => {
  const { data: metrics } = useSupabase(`
    SELECT 
      date_trunc($1, transaction_date) as period,
      SUM(amount) as revenue,
      COUNT(*) as transactions,
      AVG(amount) as avg_order_value,
      COUNT(DISTINCT customer_id) as unique_customers
    FROM scout.gold_daily_metrics
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY 1
    ORDER BY 1 DESC
  `, [period])
  
  return { metrics }
}
```

### Phase 5: Implement Real-time Updates

```typescript
// apps/scout-ui/src/hooks/useRealtimeMetrics.ts
import { useEffect } from 'react'
import { supabase } from '@/lib/supabase'

export const useRealtimeMetrics = (onUpdate: (payload: any) => void) => {
  useEffect(() => {
    const subscription = supabase
      .channel('dashboard-metrics')
      .on('postgres_changes', 
        { 
          event: 'INSERT',
          schema: 'scout',
          table: 'transactions'
        },
        onUpdate
      )
      .subscribe()
      
    return () => {
      subscription.unsubscribe()
    }
  }, [onUpdate])
}
```

## Testing & Validation

### 1. Component Testing
```bash
# Run component tests
pnpm test apps/scout-ui

# Run Storybook for visual testing
pnpm run storybook
```

### 2. Performance Testing
```bash
# Run Lighthouse CI
pnpm run lighthouse:ci

# Check bundle size
pnpm run analyze:bundle
```

### 3. Data Validation
```sql
-- Verify data accuracy
SELECT 
  COUNT(*) as record_count,
  SUM(amount) as total_revenue,
  AVG(amount) as avg_transaction
FROM scout.gold_daily_metrics
WHERE date >= CURRENT_DATE - INTERVAL '7 days';
```

## Deployment

### Development
```bash
# Start local development
pnpm run dash:dev
```

### Staging
```bash
# Deploy to staging
pnpm run deploy:staging
```

### Production
```bash
# Production deployment
pnpm run deploy:production
```

## Success Metrics Tracking

```sql
-- Create metrics tracking table
CREATE TABLE scout.dashboard_analytics (
  id SERIAL PRIMARY KEY,
  user_id UUID,
  action VARCHAR(50),
  component VARCHAR(50),
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB
);

-- Track dashboard usage
INSERT INTO scout.dashboard_analytics (user_id, action, component, metadata)
VALUES (auth.uid(), 'view', 'dashboard', '{"period": "daily", "device": "desktop"}');
```

## Next Steps

1. [ ] Review PRD with stakeholders
2. [ ] Finalize design selection (Finebank vs Dashboard Ideas)
3. [ ] Generate first component from Figma
4. [ ] Create Code Connect mapping
5. [ ] Connect to Scout database
6. [ ] Add real-time updates
7. [ ] Deploy to staging for UAT
8. [ ] Launch to production

## Support

- **Documentation**: [SuperClaude Overview](../superclaude/OVERVIEW.md)
- **MCP Issues**: [MCP Quick Reference](../claude/mcp-quick-reference.md)
- **Design System**: [Scout UI Components](../../packages/ui/README.md)
