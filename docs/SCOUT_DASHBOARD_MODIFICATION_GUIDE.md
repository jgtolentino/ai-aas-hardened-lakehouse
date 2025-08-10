# Scout Dashboard Modification Guide (Monorepo-Ready)

## 📍 Where Things Live

```
apps/web/                         # Next.js app (UI)
  src/pages/Dashboard.tsx
  src/components/...
packages/integrations/            # shared clients
  supabase/client.ts
packages/services/                # data-access
  scoutDataService.ts
packages/types/                   # zod/types for DB views
  scout.ts
scripts/                          # infra & SQL
  create-scout-views.sql
docs/                             # runbooks
  SCOUT_DATABASE_SETUP.md
```

## 🔧 1) Add or Change a Metric (End-to-End)

### Step 1: SQL View (Gold Layer)

Edit `scripts/create-scout-views.sql` (or your dbt model if you prefer):

```sql
-- view: scout_gold_revenue_by_dim v1
CREATE OR REPLACE VIEW scout.gold_revenue_by_dim AS
SELECT 
  date_key as date,
  region,
  brand,
  SUM(peso_value) as peso_value
FROM scout.silver_transactions_cleaned
GROUP BY date_key, region, brand;
```

Apply locally:
```bash
supabase db push    # or paste in Supabase SQL Editor
```

Sanity check:
```bash
pnpm ts-node src/test-connection.ts
```

### Step 2: Types

Define/extend types in `packages/types/scout.ts`:

```typescript
export type TRevenueByDim = {
  date: string;
  region: string;
  brand: string;
  peso_value: number;
}

// With Zod validation
export const RevenueByDimSchema = z.object({
  date: z.string(),
  region: z.string(),
  brand: z.string(),
  peso_value: z.number()
});
```

### Step 3: Service Function

Add to `packages/services/scoutDataService.ts`:

```typescript
export async function getRevenueByDim(params: {
  from: string;
  to: string;
  brand?: string;
  region?: string;
}) {
  let query = supabase
    .from('scout_gold_revenue_by_dim')
    .select('date,region,brand,peso_value')
    .gte('date', params.from)
    .lte('date', params.to);

  if (params.brand) query = query.eq('brand', params.brand);
  if (params.region) query = query.eq('region', params.region);

  const { data, error } = await query;
  
  if (error) throw error;
  return data;
}
```

### Step 4: UI Component

Create `apps/web/src/components/slices/RevenueByDim.tsx`:

```tsx
import { useQuery } from '@tanstack/react-query';
import { BarChart, Skeleton, ErrorCard } from '@/components/ui';
import { getRevenueByDim } from '@scout/services';

export function RevenueByDim({
  from,
  to,
  brand,
  region
}: {
  from: string;
  to: string;
  brand?: string;
  region?: string;
}) {
  const { data, isLoading, error } = useQuery(
    ['revByDim', from, to, brand, region],
    () => getRevenueByDim({ from, to, brand, region }),
    {
      staleTime: 5 * 60 * 1000, // 5 minutes
      cacheTime: 10 * 60 * 1000
    }
  );

  if (isLoading) return <Skeleton height={240} />;
  if (error) return <ErrorCard error={error} />;
  if (!data?.length) return <EmptyState title="No data for selected filters" />;

  return (
    <BarChart
      data={data}
      xField="date"
      yField="peso_value"
      seriesField="brand"
      title="Revenue by Dimension"
    />
  );
}
```

### Step 5: Page Wiring

Add to `src/pages/Dashboard.tsx`:

```tsx
import { RevenueByDim } from '@/components/slices/RevenueByDim';

// In your dashboard layout:
<Grid cols={2}>
  <RevenueByDim 
    from={filters.dateRange.from}
    to={filters.dateRange.to}
    brand={filters.brand}
    region={filters.region}
  />
</Grid>
```

### Step 6: Tests

Unit test example:
```typescript
// RevenueByDim.test.tsx
import { render, screen } from '@testing-library/react';
import { RevenueByDim } from './RevenueByDim';

jest.mock('@scout/services', () => ({
  getRevenueByDim: jest.fn().mockResolvedValue([
    { date: '2024-01-01', region: 'NCR', brand: 'A', peso_value: 1000 }
  ])
}));

test('renders revenue chart', async () => {
  render(<RevenueByDim from="2024-01-01" to="2024-01-31" />);
  expect(await screen.findByText('Revenue by Dimension')).toBeInTheDocument();
});
```

### Step 7: Documentation

Update `docs/SCOUT_DATABASE_SETUP.md`:

```markdown
### gold_revenue_by_dim
- **Purpose**: Aggregated revenue by date, region, and brand
- **Source**: silver_transactions_cleaned
- **Refresh**: Real-time view
- **Columns**: date, region, brand, peso_value
- **RLS**: Inherits from silver layer
```

## 🔐 2) Environment & Config

### Development
```env
NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-local-anon-key
SCOUT_ENV=dev
```

### Staging
```env
NEXT_PUBLIC_SUPABASE_URL=https://staging-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-staging-anon-key
SCOUT_ENV=stage
```

### Production
```env
NEXT_PUBLIC_SUPABASE_URL=https://cxzllzyxwpyptfretryc.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-prod-anon-key
SCOUT_ENV=prod
```

## 🚀 3) Monorepo Workflow

### Create Feature Branch
```bash
git checkout -b feat/scout-new-kpi
```

### Local Development Checks
```bash
pnpm i                    # Install dependencies
pnpm -w lint              # Lint all packages
pnpm -w build             # Build all packages
pnpm -w test              # Run unit tests
pnpm -w test:integration  # Run integration tests
pnpm -w dev               # Start dev server
```

### Test Database Connection
```bash
pnpm ts-node apps/web/src/test-connection.ts
```

### PR Template
```markdown
## What Changed
- Added new SQL view: `gold_revenue_by_dim`
- Created service function: `getRevenueByDim`
- Added UI component: `RevenueByDim`

## Scope
- Dashboard: Executive Dashboard
- Affected users: All dashboard viewers

## Database Migration
- Script: `scripts/create-scout-views.sql`
- RLS: ✅ Confirmed - inherits from silver layer

## Screenshots
[Before] [After]

## Rollback Plan
1. Revert SQL view
2. Feature flag to hide tile
3. Revert PR
```

## 📊 4) Common Modifications

### Add a KPI Card
```tsx
<MetricCard
  icon={DollarSign}
  label="Total Revenue"
  value={formatCurrency(kpis.totalRevenue)}
  delta={kpis.revGrowth}
  deltaLabel="vs LY"
  trend={kpis.revTrend}
/>
```

### Add Cached Query
```typescript
export async function getExecutiveKPIs(range: DateRange) {
  return queryClient.fetchQuery({
    queryKey: ['exec-kpis', range.from, range.to],
    queryFn: () => supabase.rpc('scout_exec_kpis', range),
    staleTime: 5 * 60 * 1000,
    cacheTime: 10 * 60 * 1000
  });
}
```

### Handle Empty States
```tsx
if (!data?.length) {
  return (
    <EmptyState 
      title="No data available"
      description="Try adjusting your filters"
      icon={ChartBar}
    />
  );
}
```

### Add Loading States
```tsx
if (isLoading) {
  return (
    <div className="grid grid-cols-2 gap-4">
      <Skeleton height={200} />
      <Skeleton height={200} />
    </div>
  );
}
```

## 🔒 5) Security & Privacy

### RLS Policies
Every new `gold_*` view should:
- Include `brand_guard` and `region_guard` columns
- Join to guarded dimension tables
- Test with different user roles

```sql
-- Example RLS policy
CREATE POLICY "Users see own region data"
ON scout.gold_revenue_by_dim
FOR SELECT
USING (region IN (
  SELECT region FROM auth.user_regions 
  WHERE user_id = auth.uid()
));
```

### PII Protection
- No raw customer names, emails, phone numbers
- Use hashed customer IDs
- Age brackets instead of birthdates
- Aggregated data only in gold layer

## 🔄 6) Schema Evolution

### Versioning Strategy
```sql
-- view: scout_gold_revenue_by_dim v1
-- deprecated: 2024-03-01
CREATE VIEW scout.gold_revenue_by_dim_v1 AS ...;

-- view: scout_gold_revenue_by_dim v2
-- changes: added channel column
CREATE VIEW scout.gold_revenue_by_dim AS ...;
```

### Migration Path
1. Create v2 view alongside v1
2. Update services to use v2
3. Deploy and monitor
4. Remove v1 after 2 sprints

## 📈 7) Superset Integration

Export Superset assets:
```
platform/scout/superset/
  datasets/
    - revenue_by_dim.yaml
  charts/
    - revenue_trend.yaml
  dashboards/
    - executive_dashboard.yaml
```

Keep SQL identical between Scout web and Superset to avoid drift.

## ✅ 8) Quick "Add a Tile" Checklist

- [ ] SQL view created/updated in `scripts/create-scout-views.sql`
- [ ] Type defined in `packages/types/scout.ts`
- [ ] Service function in `packages/services/scoutDataService.ts`
- [ ] UI component with loading/error/empty states
- [ ] Wired to page filters
- [ ] Unit tests written
- [ ] Integration test passes
- [ ] Documentation updated
- [ ] RLS/privacy confirmed
- [ ] PR created with screenshots

## 🛠️ 9) Troubleshooting

### Common Issues

#### "No data returned"
- Check date range filters
- Verify RLS policies
- Confirm data exists in silver layer

#### "Type errors"
- Regenerate types: `pnpm supabase gen types`
- Check for schema changes
- Validate with Zod schemas

#### "Slow queries"
- Add appropriate indexes
- Consider materialized views
- Check query execution plan

### Debug Mode
```typescript
// Enable query logging
if (process.env.NODE_ENV === 'development') {
  queryClient.setDefaultOptions({
    queries: {
      onError: (error) => console.error('Query error:', error),
      retry: false
    }
  });
}
```

## 🚀 10) Performance Tips

1. **Use React Query aggressively** - Built-in caching prevents redundant queries
2. **Implement virtual scrolling** - For tables with 1000+ rows
3. **Lazy load heavy components** - Use dynamic imports
4. **Optimize bundle size** - Tree-shake chart libraries
5. **Use CDN for static assets** - Especially for map tiles

---

**Need to add a new dashboard slice?** Run:
```bash
pnpm scaffold:slice revenue-by-channel
```

This will generate all the boilerplate for you! 🎉