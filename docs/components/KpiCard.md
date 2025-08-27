# KPI Card Component

## Overview
The KPI Card component displays key performance indicators with trend visualization, supporting multiple states (loading, empty, error, ready) for robust data presentation.

## Component Location
`apps/scout-dashboard/src/components/scout/KpiCard/`

## Features
- 4 distinct states: loading, empty, error, ready
- Trend indicators with positive/negative visualization
- Customizable icons and prefixes/suffixes
- Full accessibility support with ARIA labels
- Responsive design with Tailwind CSS
- TypeScript support with full type safety

## Usage

```tsx
import { KpiCard } from '@/components/scout/KpiCard';

// Basic usage
<KpiCard
  title="GMV"
  value="₱0"
  change={12.5}
  changeType="increase"
  icon="gmv"
/>

// With all states
<KpiCard state="loading" title="Revenue" value="" />
<KpiCard state="empty" title="Revenue" value="" />
<KpiCard state="error" title="Revenue" value="" errorMessage="Failed to load" />
<KpiCard state="ready" title="Revenue" value="125K" change={15} />
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| title | string | required | KPI metric name |
| value | string \| number | required | Metric value |
| change | number | - | Percentage change |
| changeType | 'increase' \| 'decrease' | 'increase' | Direction of change |
| prefix | string | '' | Value prefix (e.g., '$', '₱') |
| suffix | string | '' | Value suffix (e.g., '%', '/mo') |
| icon | string \| ComponentType | - | Icon identifier or component |
| state | 'loading' \| 'empty' \| 'error' \| 'ready' | 'ready' | Component state |
| errorMessage | string | 'Failed to load data' | Custom error message |
| className | string | - | Additional CSS classes |
| ariaLabel | string | - | Custom accessibility label |

## Database Schema

### Tables

#### scout.kpi_cards
- `id` (SERIAL PRIMARY KEY)
- `card_key` (VARCHAR UNIQUE)
- `title` (VARCHAR)
- `icon_type` (VARCHAR)
- `display_order` (INT)
- `is_active` (BOOLEAN)

#### scout.kpi_card_values
- `id` (SERIAL PRIMARY KEY)
- `card_id` (INT REFERENCES)
- `value` (DECIMAL)
- `formatted_value` (VARCHAR)
- `change_percentage` (DECIMAL)
- `change_type` (VARCHAR)
- `prefix` (VARCHAR)
- `suffix` (VARCHAR)
- `state` (VARCHAR)

#### scout.kpi_card_history
- `id` (SERIAL PRIMARY KEY)
- `card_id` (INT REFERENCES)
- `value` (DECIMAL)
- `recorded_at` (TIMESTAMPTZ)

### Functions

#### scout.get_latest_kpi_values()
Returns the latest KPI values for all active cards.

```sql
SELECT * FROM scout.get_latest_kpi_values();
```

## Figma Integration

### Export Variants
The component exports 4 state variants to Figma:
1. **Loading** - Skeleton loader with animation
2. **Empty** - No data state with placeholder
3. **Error** - Error state with warning icon
4. **Ready** - Default state with data and trends

### Design Tokens
- Border: `border-gray-200`
- Hover: `border-gray-300`
- Title: `text-gray-500`
- Value: `text-gray-900`
- Increase: `text-green-600`
- Decrease: `text-red-600`

## Testing

Run tests:
```bash
pnpm test KpiCard
```

Run Storybook:
```bash
pnpm storybook
```

## Accessibility

- ARIA labels for all states
- Proper heading hierarchy (h3)
- Role attributes for loading/error states
- Color contrast compliant
- Keyboard navigable

## Performance

- Optimized re-renders with React.memo
- Database indexes on frequently queried columns
- Lazy loading for historical data
- Efficient state management

## Migration

Applied via:
```bash
supabase migration apply 20250828_add_kpi_card_states.sql
```

## Related Components
- MetricGrid (wrapper for multiple KPI cards)
- TrendChart (detailed trend visualization)
- DashboardLayout (page container)
