# Scout Analytics Dashboard

A modern analytics dashboard built with Next.js, React Query, and Supabase.

## Features

- **Live Data Integration**: Connected to Supabase with automatic fallback to RPCs
- **Role-Based Navigation**: Navigation filtered by user role (Executive, Manager, Analyst)
- **Real-Time Updates**: React Query with stale-time caching for optimal performance
- **Responsive Design**: Built with Tailwind CSS for mobile-first design
- **Interactive Charts**: Recharts for revenue trends and brand performance visualization

## Environment Variables

```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key

# Optional: require auth in UI (client gate)
NEXT_PUBLIC_REQUIRE_AUTH=false

# Optional: user roles are read from Supabase JWT:
# - app_metadata.role OR user_metadata.role
# Expected values: Executive | Manager | Analyst
```

## Data Sources

The dashboard queries these Supabase views/RPCs:

1. **KPIs**: `gold_executive_kpis` view → `get_executive_summary` RPC fallback
2. **Revenue Trend**: `gold_revenue_trend_14d` view → `get_revenue_trend_14d` RPC fallback  
3. **Top Brands**: `gold_top_brands_5` view → `get_top_brands_5` RPC fallback

## Role-Based Access

- **Executive**: Access to all dashboard sections
- **Manager**: Access to Analytics, Consumer, Geographic, Reports
- **Analyst**: Access to Analytics, Consumer, Geographic, Reports

## Getting Started

```bash
# Install dependencies
pnpm install

# Set environment variables
cp .env.example .env.local

# Run development server
pnpm dev
```

Open [http://localhost:3000](http://localhost:3000) to view the dashboard.

## Architecture

- **Frontend**: Next.js 15 with App Router
- **State Management**: React Query for server state
- **Authentication**: Supabase Auth with role-based navigation
- **Styling**: Tailwind CSS with custom brand colors
- **Charts**: Recharts for data visualization
- **TypeScript**: Full type safety throughout