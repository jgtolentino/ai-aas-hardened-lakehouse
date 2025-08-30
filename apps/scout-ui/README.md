# Scout UI with Figma Code Connect Integration

## 🚀 What We've Built

We've successfully wired up a comprehensive design system that bridges Figma designs with production code:

### ✅ Completed Components

1. **Design Tokens System**
   - CSS variables for theming
   - Support for multiple BI tool themes (Tableau, Power BI, Superset)
   - Responsive color system with dark mode

2. **Core Components Library**
   - `KpiTile` - Metric display tiles with icons and trends
   - `Grid` - Responsive layout system (12/8/4 columns)
   - `Timeseries` - Interactive line charts using Recharts
   - `Button` - Themeable button component
   - `FinebankDashboard` - Full financial management dashboard

3. **Figma Code Connect Mappings**
   - All components have `.figma.tsx` mapping files
   - Ready for Figma Dev Mode integration
   - Node ID references for direct design-to-code sync

4. **Dashboard Routes**
   - `/overview` - Main overview with KPIs and charts
   - `/finebank` - Enhanced Finebank financial dashboard

## 📁 Project Structure

```
apps/
├── scout-ui/                    # Component library
│   ├── figma/
│   │   └── figma.config.json   # Figma configuration
│   └── src/
│       ├── styles/
│       │   └── tokens.css      # Design tokens
│       └── components/
│           ├── Button/
│           ├── Chart/
│           ├── Kpi/
│           ├── Layout/
│           └── FinancialDashboard/
└── scout-dashboard/            # Next.js application
    ├── app/
    │   ├── (main)/
    │   ├── overview/
    │   └── finebank/
    └── src/
        └── styles/
            └── app.css        # Global styles
```

## 🎨 Theme System

The dashboard supports three BI tool themes via CSS variables:

### Tableau Theme (Default)
```css
--accent: #1f77b4;
--bg: #0a0e14;
```

### Power BI Theme
```css
--accent: #f2c811;
--bg: #0b0b0b;
```

### Superset Theme
```css
--accent: #20a29a;
--bg: #0b0e13;
```

Switch themes by changing the `data-face` attribute on the HTML element.

## 🔧 Using the Components

### Import from Scout UI

```typescript
import { 
  KpiTile, 
  Grid, 
  Timeseries, 
  Button,
  FinebankDashboard 
} from 'apps/scout-ui/src/components'
```

### Example: Creating a Dashboard

```tsx
import { Grid, KpiTile, Timeseries } from 'apps/scout-ui/src/components'

export function MyDashboard() {
  return (
    <Grid cols={12}>
      <div className="col-span-3">
        <KpiTile 
          label="Revenue" 
          value="₱12.4M" 
          hint="Last 28 days"
        />
      </div>
      <div className="col-span-9">
        <Timeseries 
          data={[
            {x: 'Jan', y: 100},
            {x: 'Feb', y: 120}
          ]} 
        />
      </div>
    </Grid>
  )
}
```

## 🔗 Figma Integration

Each component has a corresponding `.figma.tsx` file that maps to Figma designs:

```typescript
// Button.figma.tsx
export default {
  component: Button,
  props: {
    children: 'Apply',
    tone: 'primary'
  }
}
```

## 📊 Database Integration

We've set up Supabase RPC stubs for data integration:

- `scout_get_kpis()` - Fetch KPI metrics
- `scout_get_revenue_trend()` - Get timeseries data
- `scout_get_hour_weekday()` - Get heatmap data

These functions are ready to be connected to your actual data sources.

## 🚦 CI/CD Pipeline

GitHub workflow validates Figma mappings on every push:

```yaml
name: Code Connect Parse
on: [push, pull_request]
jobs:
  parse:
    runs-on: ubuntu-latest
    steps:
      - Validates all .figma.tsx files
      - Ensures mappings are syntactically correct
```

## 🎯 Next Steps

1. **Connect to Live Data**
   - Replace RPC stubs with actual queries
   - Connect to your Scout schema tables

2. **Expand Component Library**
   - Add more chart types (bar, pie, area)
   - Create advanced filter components
   - Build notification system

3. **Figma Plugin Setup**
   - Install Figma Code Connect plugin
   - Link components to design nodes
   - Enable bi-directional sync

4. **Production Deployment**
   - Deploy to Vercel/Netlify
   - Set up environment variables
   - Configure authentication

## 🛠️ Development Commands

```bash
# Install dependencies
cd apps/scout-ui && npm install
cd apps/scout-dashboard && npm install

# Run development server
npm run dev

# Validate Figma mappings
npm run figma:parse

# Build for production
npm run build
```

## 📝 Environment Variables

Create `.env.local` in `apps/scout-dashboard`:

```env
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
```

## 🤝 Contributing

1. Create feature branch
2. Add components with Figma mappings
3. Update documentation
4. Submit PR with screenshots

## 📄 License

MIT - See LICENSE file

---

Built with ❤️ using Next.js, Tailwind CSS, and Figma Code Connect