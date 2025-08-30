# Technical Specification Document (TSD)
# Scout Financial Intelligence Platform v2.0

## 1. System Overview

### 1.1 Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                         CLIENT LAYER                          │
├────────────────┬──────────────────┬──────────────────────────┤
│   Browser      │   Mobile Web     │   Figma Plugin           │
│   (Chrome 90+) │   (iOS/Android)  │   (Code Connect)         │
└────────────────┴──────────────────┴──────────────────────────┘
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                      PRESENTATION LAYER                       │
├────────────────┬──────────────────┬──────────────────────────┤
│   Next.js 14   │   Scout UI       │   Tailwind CSS           │
│   App Router   │   Components     │   + CSS Variables        │
└────────────────┴──────────────────┴──────────────────────────┘
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                       SERVICE LAYER                           │
├────────────────┬──────────────────┬──────────────────────────┤
│   React Query  │   Zustand        │   Supabase Client        │
│   (Cache)      │   (State)        │   (Auth/Realtime)        │
└────────────────┴──────────────────┴──────────────────────────┘
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                         API LAYER                             │
├────────────────┬──────────────────┬──────────────────────────┤
│   REST API     │   WebSocket      │   Edge Functions         │
│   (CRUD)       │   (Realtime)     │   (Deno Runtime)         │
└────────────────┴──────────────────┴──────────────────────────┘
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                        DATA LAYER                             │
├────────────────┬──────────────────┬──────────────────────────┤
│   PostgreSQL   │   Redis Cache    │   S3 Storage             │
│   (Supabase)   │   (Sessions)     │   (Assets)               │
└────────────────┴──────────────────┴──────────────────────────┘
```

### 1.2 Technology Matrix

| Component | Technology | Version | Rationale |
|-----------|------------|---------|-----------|
| Framework | Next.js | 14.2.x | App Router, RSC, Edge Runtime |
| UI Library | React | 18.3.x | Concurrent features, Suspense |
| Language | TypeScript | 5.5.x | Type safety, IntelliSense |
| Styling | Tailwind CSS | 3.4.x | Utility-first, JIT compiler |
| State | Zustand | 4.5.x | Lightweight, TypeScript support |
| Data Fetching | React Query | 5.x | Caching, background refetch |
| Charts | Recharts | 2.12.x | Composable, responsive |
| Icons | Lucide React | 0.400.x | Tree-shakeable, TypeScript |
| Backend | Supabase | 2.43.x | Auth, Realtime, Storage |
| Database | PostgreSQL | 15.x | JSONB, RLS, Extensions |
| Edge Runtime | Deno | 1.44.x | TypeScript native, secure |
| Testing | Jest + RTL | 29.x | Component testing |
| E2E Testing | Playwright | 1.44.x | Cross-browser testing |
| CI/CD | GitHub Actions | - | Native integration |
| Monitoring | Vercel Analytics | - | Core Web Vitals |

## 2. Component Specifications

### 2.1 Component Architecture

```typescript
// Base Component Structure
interface ComponentProps {
  className?: string        // Optional styling override
  children?: ReactNode      // Child elements
  data-testid?: string      // Testing identifier
  aria-label?: string       // Accessibility
}

// Component Implementation Pattern
export const Component: FC<ComponentProps> = memo(({
  className,
  children,
  ...props
}) => {
  // Hooks
  const [state, setState] = useState()
  const { data } = useQuery()
  
  // Memoized computations
  const computed = useMemo(() => {}, [deps])
  
  // Effects
  useEffect(() => {}, [deps])
  
  // Event handlers
  const handleEvent = useCallback(() => {}, [deps])
  
  // Render
  return (
    <div className={cn('base-styles', className)} {...props}>
      {children}
    </div>
  )
})

Component.displayName = 'Component'
```

### 2.2 Component Library Structure

```
apps/scout-ui/src/components/
├── Button/
│   ├── Button.tsx           # Implementation
│   ├── Button.figma.tsx     # Figma mapping
│   ├── Button.test.tsx      # Unit tests
│   ├── Button.stories.tsx   # Storybook
│   └── index.ts            # Export
├── Chart/
│   ├── Timeseries.tsx
│   ├── Timeseries.figma.tsx
│   └── index.ts
├── DataTable/
│   ├── DataTable.tsx
│   ├── DataTable.figma.tsx
│   └── index.ts
├── FilterPanel/
│   ├── FilterPanel.tsx
│   ├── FilterPanel.figma.tsx
│   └── index.ts
├── Grid/
│   ├── Grid.tsx
│   ├── Grid.figma.tsx
│   └── index.ts
├── Kpi/
│   ├── KpiTile.tsx
│   ├── KpiTile.figma.tsx
│   ├── KpiCard.tsx
│   └── index.ts
└── index.ts                 # Barrel export
```

### 2.3 Props Interface Definitions

```typescript
// KpiTile Props
export interface KpiTileProps {
  label: string              // Metric label
  value: string | number     // Display value
  icon?: ReactNode          // Optional icon
  hint?: string             // Helper text
  loading?: boolean         // Loading state
  error?: boolean           // Error state
  onClick?: () => void      // Click handler
  className?: string        // Style override
}

// Grid Props
export interface GridProps {
  children: ReactNode       // Grid items
  cols?: 12 | 8 | 4       // Column count
  gap?: 2 | 4 | 6 | 8     // Gap size
  className?: string        // Style override
}

// Timeseries Props
export interface TimeseriesProps {
  data: SeriesPoint[]       // Chart data
  xKey?: string            // X-axis key
  yKey?: string            // Y-axis key
  color?: string           // Line color
  height?: number          // Chart height
  loading?: boolean        // Loading state
  className?: string       // Style override
}

export interface SeriesPoint {
  x: string | number       // X value
  y: number               // Y value
  [key: string]: any      // Additional data
}
```

## 3. State Management

### 3.1 Client State (Zustand)

```typescript
// stores/useAppStore.ts
interface AppState {
  // Theme
  theme: 'tableau' | 'pbi' | 'superset'
  setTheme: (theme: AppState['theme']) => void
  
  // Filters
  filters: {
    timeRange: '7d' | '30d' | '90d' | '1y'
    category: string
    status: string
  }
  setFilter: <K extends keyof AppState['filters']>(
    key: K, 
    value: AppState['filters'][K]
  ) => void
  resetFilters: () => void
  
  // UI State
  sidebarOpen: boolean
  toggleSidebar: () => void
  
  // Notifications
  notifications: Notification[]
  addNotification: (notification: Notification) => void
  removeNotification: (id: string) => void
}

export const useAppStore = create<AppState>((set) => ({
  theme: 'tableau',
  setTheme: (theme) => set({ theme }),
  
  filters: {
    timeRange: '30d',
    category: 'all',
    status: 'all'
  },
  setFilter: (key, value) => 
    set((state) => ({
      filters: { ...state.filters, [key]: value }
    })),
  resetFilters: () => 
    set({
      filters: { timeRange: '30d', category: 'all', status: 'all' }
    }),
    
  sidebarOpen: true,
  toggleSidebar: () => 
    set((state) => ({ sidebarOpen: !state.sidebarOpen })),
    
  notifications: [],
  addNotification: (notification) =>
    set((state) => ({
      notifications: [...state.notifications, notification]
    })),
  removeNotification: (id) =>
    set((state) => ({
      notifications: state.notifications.filter(n => n.id !== id)
    }))
}))
```

### 3.2 Server State (React Query)

```typescript
// hooks/useKpis.ts
export const useKpis = (filters: FilterState) => {
  return useQuery({
    queryKey: ['kpis', filters],
    queryFn: () => fetchKpis(filters),
    staleTime: 5 * 60 * 1000,     // 5 minutes
    cacheTime: 10 * 60 * 1000,    // 10 minutes
    refetchInterval: 30 * 1000,    // 30 seconds
    refetchIntervalInBackground: true,
    retry: 3,
    retryDelay: attemptIndex => Math.min(1000 * 2 ** attemptIndex, 30000)
  })
}

// hooks/useTimeseries.ts
export const useTimeseries = (metric: string, range: string) => {
  return useQuery({
    queryKey: ['timeseries', metric, range],
    queryFn: () => fetchTimeseries(metric, range),
    staleTime: 60 * 1000,         // 1 minute
    enabled: !!metric && !!range
  })
}
```

## 4. API Specifications

### 4.1 REST API Endpoints

```typescript
// Base URL: https://api.scout.tbwa.com/v1

// KPIs Endpoint
GET /kpis
Query Parameters:
  - timeRange: string (7d|30d|90d|1y)
  - category?: string
  - status?: string
Response: {
  revenue: number
  transactions: number
  basketSize: number
  activeUsers: number
  trends: {
    revenue: number
    transactions: number
    basketSize: number
    activeUsers: number
  }
}

// Timeseries Endpoint
GET /timeseries/:metric
Path Parameters:
  - metric: string (revenue|transactions|users)
Query Parameters:
  - range: string (7d|30d|90d|1y)
  - interval?: string (hour|day|week|month)
Response: {
  data: Array<{
    timestamp: string
    value: number
  }>
  metadata: {
    metric: string
    range: string
    interval: string
    total: number
    average: number
  }
}

// Export Endpoint
POST /export
Body: {
  format: 'csv' | 'pdf' | 'excel'
  data: any[]
  columns: Column[]
  filters?: FilterState
}
Response: {
  url: string           // Download URL
  expiresAt: string    // Expiration time
}
```

### 4.2 WebSocket Events

```typescript
// WebSocket URL: wss://api.scout.tbwa.com/v1/ws

// Connection
const ws = new WebSocket('wss://api.scout.tbwa.com/v1/ws')

// Authentication
ws.send(JSON.stringify({
  type: 'auth',
  token: 'jwt_token'
}))

// Subscribe to metrics
ws.send(JSON.stringify({
  type: 'subscribe',
  channel: 'metrics',
  filters: { timeRange: '30d' }
}))

// Receive updates
ws.onmessage = (event) => {
  const { type, data } = JSON.parse(event.data)
  
  switch(type) {
    case 'metrics:update':
      updateKpis(data)
      break
    case 'alert':
      showNotification(data)
      break
  }
}

// Event Types
interface WSEvent {
  type: 'auth' | 'subscribe' | 'unsubscribe' | 'ping'
  channel?: 'metrics' | 'alerts' | 'reports'
  data?: any
}

interface WSMessage {
  type: 'metrics:update' | 'alert' | 'error' | 'pong'
  data: any
  timestamp: string
}
```

## 5. Database Schema

### 5.1 Core Tables

```sql
-- Schema: scout

-- KPIs aggregation table
CREATE TABLE scout.kpis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date DATE NOT NULL,
  metric_name TEXT NOT NULL,
  value NUMERIC NOT NULL,
  category TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(date, metric_name, category)
);

-- Transactions table
CREATE TABLE scout.transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_date TIMESTAMPTZ NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('revenue', 'expense', 'transfer')),
  amount NUMERIC NOT NULL,
  currency TEXT DEFAULT 'PHP',
  category TEXT,
  description TEXT,
  status TEXT DEFAULT 'completed',
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Reports table
CREATE TABLE scout.reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  format TEXT NOT NULL,
  filters JSONB,
  data JSONB,
  url TEXT,
  expires_at TIMESTAMPTZ,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User preferences
CREATE TABLE scout.user_preferences (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id),
  theme TEXT DEFAULT 'tableau',
  default_filters JSONB,
  dashboard_layout JSONB,
  notifications JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 5.2 Functions & Procedures

```sql
-- Get KPIs with filters
CREATE OR REPLACE FUNCTION scout.get_kpis(
  p_filters JSONB DEFAULT '{}'
)
RETURNS TABLE (
  revenue NUMERIC,
  transactions NUMERIC,
  basket_size NUMERIC,
  active_users NUMERIC,
  trends JSONB
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  -- Implementation
  RETURN QUERY
  SELECT 
    SUM(CASE WHEN metric_name = 'revenue' THEN value END) as revenue,
    SUM(CASE WHEN metric_name = 'transactions' THEN value END) as transactions,
    AVG(CASE WHEN metric_name = 'basket_size' THEN value END) as basket_size,
    COUNT(DISTINCT CASE WHEN metric_name = 'user' THEN metadata->>'user_id' END) as active_users,
    jsonb_build_object(
      'revenue', 12.5,
      'transactions', 8.3,
      'basket_size', -3.8,
      'active_users', 25.4
    ) as trends
  FROM scout.kpis
  WHERE date >= CURRENT_DATE - INTERVAL '30 days';
END;
$$;

-- Get timeseries data
CREATE OR REPLACE FUNCTION scout.get_timeseries(
  p_metric TEXT,
  p_range TEXT DEFAULT '30d',
  p_interval TEXT DEFAULT 'day'
)
RETURNS TABLE (
  x TEXT,
  y NUMERIC
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    to_char(date_trunc(p_interval, date), 'YYYY-MM-DD') as x,
    SUM(value) as y
  FROM scout.kpis
  WHERE metric_name = p_metric
    AND date >= CURRENT_DATE - p_range::INTERVAL
  GROUP BY date_trunc(p_interval, date)
  ORDER BY date_trunc(p_interval, date);
END;
$$;
```

### 5.3 Row Level Security

```sql
-- Enable RLS
ALTER TABLE scout.kpis ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.reports ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view their own data"
  ON scout.transactions
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view shared reports"
  ON scout.reports
  FOR SELECT
  USING (
    created_by = auth.uid() OR
    metadata->>'shared_with' ? auth.uid()::TEXT
  );
```

## 6. Security Implementation

### 6.1 Authentication Flow

```typescript
// auth/config.ts
export const authConfig = {
  providers: ['email', 'google', 'github'],
  mfa: {
    enabled: true,
    methods: ['totp', 'sms']
  },
  session: {
    expiresIn: '7d',
    refreshThreshold: '1d'
  },
  passwordPolicy: {
    minLength: 12,
    requireUppercase: true,
    requireLowercase: true,
    requireNumbers: true,
    requireSpecialChars: true
  }
}

// auth/middleware.ts
export async function authMiddleware(req: NextRequest) {
  const session = await getSession(req)
  
  if (!session) {
    return NextResponse.redirect('/login')
  }
  
  if (session.expiresAt < Date.now()) {
    const refreshed = await refreshSession(session.refreshToken)
    if (!refreshed) {
      return NextResponse.redirect('/login')
    }
  }
  
  return NextResponse.next()
}
```

### 6.2 API Security

```typescript
// Rate limiting
const rateLimiter = new RateLimiter({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 100,                   // 100 requests
  keyGenerator: (req) => req.ip || req.headers['x-forwarded-for']
})

// CORS configuration
const corsOptions = {
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}

// Input validation
const validateInput = z.object({
  timeRange: z.enum(['7d', '30d', '90d', '1y']),
  category: z.string().optional(),
  status: z.string().optional()
})

// SQL injection prevention (using parameterized queries)
const query = `
  SELECT * FROM scout.kpis 
  WHERE date >= $1 AND category = $2
`
const result = await db.query(query, [startDate, category])
```

## 7. Performance Optimization

### 7.1 Frontend Optimizations

```typescript
// Code splitting
const Dashboard = dynamic(() => import('./Dashboard'), {
  loading: () => <Skeleton />,
  ssr: false
})

// Image optimization
<Image
  src="/chart.png"
  width={800}
  height={400}
  alt="Chart"
  loading="lazy"
  placeholder="blur"
  blurDataURL={shimmer}
/>

// Bundle optimization
// next.config.js
module.exports = {
  compiler: {
    removeConsole: process.env.NODE_ENV === 'production'
  },
  experimental: {
    optimizeCss: true,
    optimizePackageImports: ['lucide-react', 'recharts']
  },
  images: {
    formats: ['image/avif', 'image/webp']
  }
}

// Memoization
const MemoizedChart = memo(Chart, (prev, next) => {
  return JSON.stringify(prev.data) === JSON.stringify(next.data)
})

// Virtual scrolling for large lists
import { VariableSizeList } from 'react-window'

<VariableSizeList
  height={600}
  itemCount={items.length}
  itemSize={getItemSize}
  width="100%"
>
  {Row}
</VariableSizeList>
```

### 7.2 Backend Optimizations

```sql
-- Indexes
CREATE INDEX idx_kpis_date ON scout.kpis(date DESC);
CREATE INDEX idx_kpis_metric ON scout.kpis(metric_name);
CREATE INDEX idx_transactions_date ON scout.transactions(transaction_date DESC);
CREATE INDEX idx_transactions_type ON scout.transactions(type);

-- Materialized views
CREATE MATERIALIZED VIEW scout.daily_summary AS
SELECT 
  date,
  SUM(CASE WHEN type = 'revenue' THEN amount ELSE 0 END) as revenue,
  SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as expenses,
  COUNT(*) as transaction_count
FROM scout.transactions
GROUP BY date
WITH DATA;

-- Refresh strategy
CREATE OR REPLACE FUNCTION scout.refresh_materialized_views()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY scout.daily_summary;
END;
$$ LANGUAGE plpgsql;

-- Schedule refresh
SELECT cron.schedule('refresh-views', '0 * * * *', 'SELECT scout.refresh_materialized_views()');
```

## 8. Testing Strategy

### 8.1 Unit Tests

```typescript
// KpiTile.test.tsx
describe('KpiTile', () => {
  it('renders label and value', () => {
    render(<KpiTile label="Revenue" value="₱12.4M" />)
    expect(screen.getByText('Revenue')).toBeInTheDocument()
    expect(screen.getByText('₱12.4M')).toBeInTheDocument()
  })
  
  it('shows icon when provided', () => {
    const icon = <DollarSign data-testid="icon" />
    render(<KpiTile label="Revenue" value="₱12.4M" icon={icon} />)
    expect(screen.getByTestId('icon')).toBeInTheDocument()
  })
  
  it('displays hint text', () => {
    render(<KpiTile label="Revenue" value="₱12.4M" hint="+12%" />)
    expect(screen.getByText('+12%')).toBeInTheDocument()
  })
  
  it('handles click events', () => {
    const handleClick = jest.fn()
    render(<KpiTile label="Revenue" value="₱12.4M" onClick={handleClick} />)
    fireEvent.click(screen.getByRole('button'))
    expect(handleClick).toHaveBeenCalledTimes(1)
  })
})
```

### 8.2 Integration Tests

```typescript
// dashboard.test.ts
describe('Dashboard Integration', () => {
  beforeEach(() => {
    mockServer.listen()
  })
  
  afterEach(() => {
    mockServer.resetHandlers()
  })
  
  it('loads KPIs on mount', async () => {
    render(<Dashboard />)
    await waitFor(() => {
      expect(screen.getByText('₱24.6M')).toBeInTheDocument()
    })
  })
  
  it('updates data when filters change', async () => {
    render(<Dashboard />)
    const filterButton = screen.getByRole('button', { name: /30d/ })
    fireEvent.click(filterButton)
    
    await waitFor(() => {
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('timeRange=30d')
      )
    })
  })
})
```

### 8.3 E2E Tests

```typescript
// e2e/dashboard.spec.ts
import { test, expect } from '@playwright/test'

test.describe('Dashboard E2E', () => {
  test('complete user flow', async ({ page }) => {
    // Navigate to dashboard
    await page.goto('/dashboard')
    
    // Check KPIs loaded
    await expect(page.locator('[data-testid="kpi-revenue"]')).toBeVisible()
    
    // Change theme
    await page.selectOption('[data-testid="theme-selector"]', 'pbi')
    await expect(page.locator('html')).toHaveAttribute('data-face', 'pbi')
    
    // Apply filters
    await page.click('[data-testid="filter-button"]')
    await page.selectOption('[data-testid="timerange-select"]', '7d')
    await page.click('[data-testid="apply-filters"]')
    
    // Export data
    await page.click('[data-testid="export-button"]')
    const download = await page.waitForEvent('download')
    expect(download.suggestedFilename()).toContain('.csv')
  })
})
```

## 9. Deployment Configuration

### 9.1 Docker Configuration

```dockerfile
# Dockerfile
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV production
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
USER nextjs
EXPOSE 3000
ENV PORT 3000
CMD ["node", "server.js"]
```

### 9.2 CI/CD Pipeline

```yaml
# .github/workflows/deploy.yml
name: Deploy Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run tests
        run: |
          npm run lint
          npm run type-check
          npm run test:unit
          npm run test:integration
      
      - name: Build
        run: npm run build

  deploy:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Deploy to Vercel
        run: |
          npx vercel --prod --token=${{ secrets.VERCEL_TOKEN }}
      
      - name: Run E2E tests
        run: npm run test:e2e
      
      - name: Notify Slack
        if: always()
        run: |
          curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
            -H 'Content-Type: application/json' \
            -d '{"text":"Deployment ${{ job.status }}"}'
```

## 10. Monitoring & Observability

### 10.1 Application Monitoring

```typescript
// monitoring/config.ts
export const monitoring = {
  // Vercel Analytics
  analytics: {
    enabled: true,
    debug: process.env.NODE_ENV === 'development'
  },
  
  // Sentry Error Tracking
  sentry: {
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV,
    tracesSampleRate: 0.1,
    replaysSessionSampleRate: 0.1,
    replaysOnErrorSampleRate: 1.0
  },
  
  // Custom metrics
  metrics: {
    apiLatency: new Histogram({
      name: 'api_request_duration_seconds',
      help: 'API request latency',
      labelNames: ['method', 'route', 'status']
    }),
    
    activeUsers: new Gauge({
      name: 'active_users_count',
      help: 'Number of active users'
    }),
    
    kpiLoadTime: new Histogram({
      name: 'kpi_load_duration_seconds',
      help: 'KPI loading time'
    })
  }
}
```

### 10.2 Logging

```typescript
// logging/logger.ts
import winston from 'winston'

export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console({
      format: winston.format.simple()
    }),
    new winston.transports.File({
      filename: 'error.log',
      level: 'error'
    }),
    new winston.transports.File({
      filename: 'combined.log'
    })
  ]
})

// Usage
logger.info('KPI request', {
  userId: session.user.id,
  filters: req.query,
  timestamp: new Date().toISOString()
})
```

---

**Document Version:** 1.0.0  
**Last Updated:** 2024-05-15  
**Technical Lead:** Engineering Team  
**Status:** APPROVED ✅

---

*This technical specification aligns with the Product Requirements Document v1.0.0*