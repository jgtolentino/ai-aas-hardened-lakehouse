# Scout Dashboard Scaffold Generator Examples

## 🚀 Quick Start

The scaffold generator creates all the boilerplate code you need to add a new dashboard slice (metric/chart/component) to the Scout Analytics Platform.

### Basic Usage

```bash
# Install dependencies first (if not already done)
pnpm install

# Generate a new slice
pnpm scaffold:slice <slice-name>

# or use the shorter alias
pnpm gen:slice <slice-name>
```

## 📊 Example: Revenue by Channel

Let's say you want to add a "Revenue by Channel" chart to the dashboard:

```bash
pnpm scaffold:slice revenue-by-channel
```

This generates:

```
✓ Created: scripts/migrations/add_revenue_by_channel_view.sql
✓ Created: packages/types/src/revenueByChannel.ts
✓ Created: packages/services/src/revenueByChannelService.ts
✓ Created: apps/web/src/components/slices/RevenueByChannel.tsx
✓ Created: apps/web/src/components/slices/RevenueByChannel.test.tsx
✓ Created: docs/database/revenue_by_channel.md

✨ Scaffold complete!
```

### What Gets Generated

#### 1. SQL View (`scripts/migrations/add_revenue_by_channel_view.sql`)
```sql
CREATE OR REPLACE VIEW scout.gold_revenue_by_channel AS
WITH base_data AS (
  SELECT 
    date_key as date,
    region,
    brand,
    channel,  -- You'll add this
    SUM(peso_value) as peso_value
  FROM scout.silver_transactions_cleaned
  GROUP BY date_key, region, brand, channel
)
SELECT * FROM base_data;
```

#### 2. TypeScript Types (`packages/types/src/revenueByChannel.ts`)
```typescript
export type RevenueByChannel = {
  date: string;
  region: string;
  brand: string;
  channel: string;
  peso_value: number;
}
```

#### 3. Service Function (`packages/services/src/revenueByChannelService.ts`)
```typescript
export async function getRevenueByChannel(params: RevenueByChannelFilter) {
  // Supabase query with filters
}
```

#### 4. React Component (`apps/web/src/components/slices/RevenueByChannel.tsx`)
```tsx
export function RevenueByChannel({ from, to, region, brand }: Props) {
  // Complete component with loading, error, and empty states
}
```

#### 5. Tests (`apps/web/src/components/slices/RevenueByChannel.test.tsx`)
```typescript
describe('RevenueByChannel', () => {
  // Full test suite with mocked data
});
```

## 🎯 More Examples

### Customer Segments
```bash
pnpm scaffold:slice customer-segments
```
Good for: Demographics, loyalty tiers, purchase behavior

### Product Performance
```bash
pnpm scaffold:slice product-performance
```
Good for: SKU analysis, category trends, inventory turnover

### Store Comparison
```bash
pnpm scaffold:slice store-comparison
```
Good for: Location performance, regional analysis

### Time Series Forecast
```bash
pnpm scaffold:slice sales-forecast
```
Good for: Predictive analytics, trend projection

## 🔧 Customization After Generation

### 1. Modify the SQL View
Edit the generated SQL to match your specific needs:
```sql
-- Add custom columns
channel_type,
payment_method,
discount_percentage,

-- Add custom calculations
SUM(peso_value - discount_amount) as net_revenue,
COUNT(DISTINCT customer_id) as unique_customers
```

### 2. Update the Chart Type
Change from BarChart to LineChart, AreaChart, PieChart, etc:
```tsx
import { LineChart, Line, Area, AreaChart } from 'recharts';

// Change the visualization
<AreaChart data={chartData}>
  <Area type="monotone" dataKey="y" fill="#8884d8" />
</AreaChart>
```

### 3. Add Custom Filters
Extend the filter interface:
```typescript
export type RevenueByChannelFilter = {
  from: string;
  to: string;
  region?: string;
  brand?: string;
  channel?: string;  // Add this
  minAmount?: number; // Add this
}
```

### 4. Add to Dashboard
Import and use in your dashboard:
```tsx
import { RevenueByChannel } from '@/components/slices/RevenueByChannel';

// In your dashboard grid
<Grid cols={2}>
  <RevenueByChannel 
    from={dateRange.from}
    to={dateRange.to}
    region={filters.region}
    brand={filters.brand}
  />
</Grid>
```

## 📋 Post-Scaffold Checklist

After running the scaffold generator:

1. **Review SQL** - Customize the view for your specific metrics
2. **Run Migration** - `supabase db push` or apply via SQL editor
3. **Test Query** - `pnpm test:connection` to verify the view works
4. **Customize Component** - Adjust chart type, colors, layout
5. **Add to Dashboard** - Import and place in your page
6. **Run Tests** - `pnpm test RevenueByChannel`
7. **Update Docs** - Fill in the TODO sections in the generated docs

## 🚨 Troubleshooting

### "Permission denied"
```bash
chmod +x scripts/scaffold-slice.ts
```

### "Module not found"
```bash
pnpm install tsx
```

### "Name must be kebab-case"
Use lowercase with hyphens:
- ✅ `revenue-by-channel`
- ❌ `RevenueByChannel`
- ❌ `revenue_by_channel`

## 🎉 Advanced Usage

### Generate Multiple Slices
```bash
# Create a batch script
for slice in "revenue-by-channel" "customer-retention" "inventory-turnover"; do
  pnpm scaffold:slice $slice
done
```

### Custom Templates
Copy and modify `scripts/scaffold-slice.ts` to create specialized generators:
- `scaffold:kpi` - For single metric cards
- `scaffold:table` - For data tables
- `scaffold:map` - For geographic visualizations

---

**Happy scaffolding!** 🏗️

The generator saves you 30-45 minutes per new dashboard component by creating all the boilerplate code with proper types, error handling, and tests.