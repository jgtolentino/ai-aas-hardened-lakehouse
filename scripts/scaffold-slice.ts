#!/usr/bin/env tsx
/**
 * Scout Dashboard Slice Scaffold Generator
 * 
 * Usage: pnpm scaffold:slice <slice-name>
 * Example: pnpm scaffold:slice revenue-by-channel
 * 
 * This will generate:
 * - SQL view template
 * - TypeScript types
 * - Service function
 * - React component
 * - Test file
 * - Documentation stub
 */

import { promises as fs } from 'fs';
import path from 'path';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

// ANSI color codes
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  red: '\x1b[31m'
};

// Helper functions
const log = {
  info: (msg: string) => console.log(`${colors.blue}ℹ${colors.reset} ${msg}`),
  success: (msg: string) => console.log(`${colors.green}✓${colors.reset} ${msg}`),
  warning: (msg: string) => console.log(`${colors.yellow}⚠${colors.reset} ${msg}`),
  error: (msg: string) => console.log(`${colors.red}✗${colors.reset} ${msg}`)
};

// Convert kebab-case to various formats
function toTitleCase(str: string): string {
  return str
    .split('-')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join('');
}

function toCamelCase(str: string): string {
  const titleCase = toTitleCase(str);
  return titleCase.charAt(0).toLowerCase() + titleCase.slice(1);
}

function toSnakeCase(str: string): string {
  return str.replace(/-/g, '_');
}

// Template generators
function generateSQLTemplate(name: string): string {
  const snakeName = toSnakeCase(name);
  return `-- ============================================================================
-- Scout Gold Layer View: ${name}
-- Generated: ${new Date().toISOString()}
-- ============================================================================

-- view: scout_gold_${snakeName} v1
CREATE OR REPLACE VIEW scout.gold_${snakeName} AS
WITH base_data AS (
  SELECT 
    date_key as date,
    region,
    brand,
    store_id,
    -- TODO: Add your specific metrics here
    COUNT(*) as transaction_count,
    SUM(peso_value) as peso_value,
    AVG(basket_size) as avg_basket_size
  FROM scout.silver_transactions_cleaned
  WHERE date_key >= CURRENT_DATE - INTERVAL '90 days'
  GROUP BY date_key, region, brand, store_id
)
SELECT 
  date,
  region,
  brand,
  -- TODO: Add your aggregations and calculations
  SUM(transaction_count) as transaction_count,
  SUM(peso_value) as peso_value,
  AVG(avg_basket_size) as avg_basket_size
FROM base_data
GROUP BY date, region, brand
ORDER BY date DESC, region, brand;

-- Grant permissions
GRANT SELECT ON scout.gold_${snakeName} TO authenticated;
GRANT SELECT ON scout.gold_${snakeName} TO anon;

-- Add RLS policy
ALTER TABLE scout.gold_${snakeName} ENABLE ROW LEVEL SECURITY;

CREATE POLICY "${snakeName}_rls_policy" ON scout.gold_${snakeName}
  FOR SELECT
  USING (
    region IN (
      SELECT region FROM auth.user_regions WHERE user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM auth.user_roles 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Add to documentation
COMMENT ON VIEW scout.gold_${snakeName} IS 'TODO: Add description of what this view provides';
`;
}

function generateTypeTemplate(name: string): string {
  const titleName = toTitleCase(name);
  const snakeName = toSnakeCase(name);
  
  return `import { z } from 'zod';

// ============================================================================
// ${titleName} Types
// Generated: ${new Date().toISOString()}
// ============================================================================

export const ${titleName}Schema = z.object({
  date: z.string(),
  region: z.string(),
  brand: z.string(),
  // TODO: Add your specific fields
  transaction_count: z.number(),
  peso_value: z.number(),
  avg_basket_size: z.number()
});

export type ${titleName} = z.infer<typeof ${titleName}Schema>;

export const ${titleName}FilterSchema = z.object({
  from: z.string(),
  to: z.string(),
  region: z.string().optional(),
  brand: z.string().optional(),
  // TODO: Add additional filters as needed
});

export type ${titleName}Filter = z.infer<typeof ${titleName}FilterSchema>;

// Response type for API
export type ${titleName}Response = {
  data: ${titleName}[];
  metadata?: {
    total: number;
    filtered: number;
    lastUpdated: string;
  };
};
`;
}

function generateServiceTemplate(name: string): string {
  const titleName = toTitleCase(name);
  const camelName = toCamelCase(name);
  const snakeName = toSnakeCase(name);
  
  return `import { supabase } from '@scout/integrations/supabase';
import type { ${titleName}, ${titleName}Filter } from '@scout/types';

// ============================================================================
// ${titleName} Service
// Generated: ${new Date().toISOString()}
// ============================================================================

/**
 * Fetch ${name} data from the gold layer
 */
export async function get${titleName}(params: ${titleName}Filter): Promise<${titleName}[]> {
  let query = supabase
    .from('scout_gold_${snakeName}')
    .select(\`
      date,
      region,
      brand,
      transaction_count,
      peso_value,
      avg_basket_size
    \`)
    .gte('date', params.from)
    .lte('date', params.to)
    .order('date', { ascending: false });

  // Apply optional filters
  if (params.region) {
    query = query.eq('region', params.region);
  }
  
  if (params.brand) {
    query = query.eq('brand', params.brand);
  }

  const { data, error } = await query;
  
  if (error) {
    console.error('Error fetching ${camelName}:', error);
    throw new Error(\`Failed to fetch ${name} data: \${error.message}\`);
  }

  return data || [];
}

/**
 * Get aggregated summary for ${name}
 */
export async function get${titleName}Summary(params: ${titleName}Filter) {
  const data = await get${titleName}(params);
  
  // TODO: Customize summary calculation
  const summary = {
    totalTransactions: data.reduce((sum, d) => sum + d.transaction_count, 0),
    totalRevenue: data.reduce((sum, d) => sum + d.peso_value, 0),
    avgBasketSize: data.length > 0
      ? data.reduce((sum, d) => sum + d.avg_basket_size, 0) / data.length
      : 0,
    periodStart: params.from,
    periodEnd: params.to
  };

  return summary;
}

/**
 * Transform data for chart display
 */
export function transform${titleName}ForChart(data: ${titleName}[]) {
  // TODO: Customize transformation based on your chart needs
  return data.map(item => ({
    x: item.date,
    y: item.peso_value,
    series: item.brand,
    ...item
  }));
}
`;
}

function generateComponentTemplate(name: string): string {
  const titleName = toTitleCase(name);
  const camelName = toCamelCase(name);
  
  return `import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { get${titleName}, transform${titleName}ForChart } from '@scout/services';
import type { ${titleName}Filter } from '@scout/types';

// ============================================================================
// ${titleName} Component
// Generated: ${new Date().toISOString()}
// ============================================================================

interface ${titleName}Props extends ${titleName}Filter {
  className?: string;
  title?: string;
  height?: number;
}

export function ${titleName}({
  from,
  to,
  region,
  brand,
  className,
  title = "${titleName.replace(/([A-Z])/g, ' $1').trim()}",
  height = 300
}: ${titleName}Props) {
  const { data, isLoading, error } = useQuery({
    queryKey: ['${camelName}', from, to, region, brand],
    queryFn: () => get${titleName}({ from, to, region, brand }),
    staleTime: 5 * 60 * 1000, // 5 minutes
    cacheTime: 10 * 60 * 1000, // 10 minutes
    retry: 2
  });

  if (isLoading) {
    return (
      <Card className={className}>
        <CardHeader>
          <Skeleton className="h-6 w-48" />
        </CardHeader>
        <CardContent>
          <Skeleton className="w-full" style={{ height }} />
        </CardContent>
      </Card>
    );
  }

  if (error) {
    return (
      <Card className={className}>
        <CardHeader>
          <CardTitle>{title}</CardTitle>
        </CardHeader>
        <CardContent>
          <Alert variant="destructive">
            <AlertDescription>
              Failed to load data. Please try refreshing the page.
            </AlertDescription>
          </Alert>
        </CardContent>
      </Card>
    );
  }

  if (!data || data.length === 0) {
    return (
      <Card className={className}>
        <CardHeader>
          <CardTitle>{title}</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex items-center justify-center" style={{ height }}>
            <p className="text-muted-foreground">No data available for selected filters</p>
          </div>
        </CardContent>
      </Card>
    );
  }

  const chartData = transform${titleName}ForChart(data);

  return (
    <Card className={className}>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={height}>
          <BarChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="x" />
            <YAxis />
            <Tooltip />
            <Bar dataKey="y" fill="#8884d8" />
          </BarChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}

// Summary card variant
export function ${titleName}Summary(props: ${titleName}Props) {
  const { data, isLoading } = useQuery({
    queryKey: ['${camelName}-summary', props.from, props.to, props.region, props.brand],
    queryFn: async () => {
      const { get${titleName}Summary } = await import('@scout/services');
      return get${titleName}Summary(props);
    }
  });

  if (isLoading) return <Skeleton className="h-24 w-full" />;

  return (
    <div className="grid grid-cols-3 gap-4">
      <Card>
        <CardContent className="pt-6">
          <div className="text-2xl font-bold">
            {data?.totalTransactions.toLocaleString() || '0'}
          </div>
          <p className="text-xs text-muted-foreground">Total Transactions</p>
        </CardContent>
      </Card>
      <Card>
        <CardContent className="pt-6">
          <div className="text-2xl font-bold">
            ₱{data?.totalRevenue.toLocaleString() || '0'}
          </div>
          <p className="text-xs text-muted-foreground">Total Revenue</p>
        </CardContent>
      </Card>
      <Card>
        <CardContent className="pt-6">
          <div className="text-2xl font-bold">
            {data?.avgBasketSize.toFixed(1) || '0'}
          </div>
          <p className="text-xs text-muted-foreground">Avg Basket Size</p>
        </CardContent>
      </Card>
    </div>
  );
}
`;
}

function generateTestTemplate(name: string): string {
  const titleName = toTitleCase(name);
  const camelName = toCamelCase(name);
  
  return `import { render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ${titleName} } from './${titleName}';
import { get${titleName} } from '@scout/services';

// ============================================================================
// ${titleName} Tests
// Generated: ${new Date().toISOString()}
// ============================================================================

jest.mock('@scout/services', () => ({
  get${titleName}: jest.fn()
}));

const mockData = [
  {
    date: '2024-01-01',
    region: 'NCR',
    brand: 'Brand A',
    transaction_count: 100,
    peso_value: 50000,
    avg_basket_size: 500
  },
  {
    date: '2024-01-02',
    region: 'NCR',
    brand: 'Brand A',
    transaction_count: 120,
    peso_value: 60000,
    avg_basket_size: 500
  }
];

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { retry: false }
  }
});

const wrapper = ({ children }: { children: React.ReactNode }) => (
  <QueryClientProvider client={queryClient}>
    {children}
  </QueryClientProvider>
);

describe('${titleName}', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('renders loading state initially', () => {
    (get${titleName} as jest.Mock).mockImplementation(() => 
      new Promise(() => {}) // Never resolves
    );

    render(
      <${titleName} from="2024-01-01" to="2024-01-31" />,
      { wrapper }
    );

    expect(screen.getByTestId('skeleton')).toBeInTheDocument();
  });

  it('renders data when loaded', async () => {
    (get${titleName} as jest.Mock).mockResolvedValue(mockData);

    render(
      <${titleName} from="2024-01-01" to="2024-01-31" />,
      { wrapper }
    );

    await waitFor(() => {
      expect(screen.getByText('${titleName.replace(/([A-Z])/g, ' $1').trim()}')).toBeInTheDocument();
    });
  });

  it('renders error state on failure', async () => {
    (get${titleName} as jest.Mock).mockRejectedValue(new Error('API Error'));

    render(
      <${titleName} from="2024-01-01" to="2024-01-31" />,
      { wrapper }
    );

    await waitFor(() => {
      expect(screen.getByText(/Failed to load data/)).toBeInTheDocument();
    });
  });

  it('renders empty state when no data', async () => {
    (get${titleName} as jest.Mock).mockResolvedValue([]);

    render(
      <${titleName} from="2024-01-01" to="2024-01-31" />,
      { wrapper }
    );

    await waitFor(() => {
      expect(screen.getByText(/No data available/)).toBeInTheDocument();
    });
  });

  it('passes filters correctly', async () => {
    (get${titleName} as jest.Mock).mockResolvedValue(mockData);

    render(
      <${titleName} 
        from="2024-01-01" 
        to="2024-01-31"
        region="NCR"
        brand="Brand A"
      />,
      { wrapper }
    );

    await waitFor(() => {
      expect(get${titleName}).toHaveBeenCalledWith({
        from: '2024-01-01',
        to: '2024-01-31',
        region: 'NCR',
        brand: 'Brand A'
      });
    });
  });
});
`;
}

function generateDocTemplate(name: string): string {
  const snakeName = toSnakeCase(name);
  const titleName = toTitleCase(name);
  
  return `
## gold_${snakeName}

### Purpose
TODO: Describe what this view provides

### Source Tables
- \`scout.silver_transactions_cleaned\`
- TODO: Add other source tables

### Columns
| Column | Type | Description |
|--------|------|-------------|
| date | date | Transaction date |
| region | text | Geographic region |
| brand | text | Brand identifier |
| transaction_count | integer | Number of transactions |
| peso_value | numeric | Total peso value |
| avg_basket_size | numeric | Average basket size |

### Refresh Schedule
- Type: Real-time view
- Dependencies: Updates when silver layer updates

### RLS Policy
- Users can only see data for their assigned regions
- Admins have full access

### Sample Query
\`\`\`sql
SELECT * FROM scout.gold_${snakeName}
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
  AND region = 'NCR'
ORDER BY date DESC;
\`\`\`

### Related Components
- Service: \`get${titleName}()\`
- Component: \`<${titleName} />\`
- Test: \`${titleName}.test.tsx\`
`;
}

// Main scaffold function
async function scaffoldSlice(name: string) {
  log.info(`Scaffolding new slice: ${name}`);

  const paths = {
    sql: path.join(process.cwd(), `scripts/migrations/add_${toSnakeCase(name)}_view.sql`),
    types: path.join(process.cwd(), `packages/types/src/${toCamelCase(name)}.ts`),
    service: path.join(process.cwd(), `packages/services/src/${toCamelCase(name)}Service.ts`),
    component: path.join(process.cwd(), `apps/web/src/components/slices/${toTitleCase(name)}.tsx`),
    test: path.join(process.cwd(), `apps/web/src/components/slices/${toTitleCase(name)}.test.tsx`),
    docs: path.join(process.cwd(), `docs/database/${toSnakeCase(name)}.md`)
  };

  const files = [
    { path: paths.sql, content: generateSQLTemplate(name) },
    { path: paths.types, content: generateTypeTemplate(name) },
    { path: paths.service, content: generateServiceTemplate(name) },
    { path: paths.component, content: generateComponentTemplate(name) },
    { path: paths.test, content: generateTestTemplate(name) },
    { path: paths.docs, content: generateDocTemplate(name) }
  ];

  // Create directories if they don't exist
  for (const file of files) {
    const dir = path.dirname(file.path);
    await fs.mkdir(dir, { recursive: true });
  }

  // Write files
  for (const file of files) {
    await fs.writeFile(file.path, file.content, 'utf-8');
    log.success(`Created: ${path.relative(process.cwd(), file.path)}`);
  }

  // Update barrel exports
  log.info('Updating barrel exports...');
  
  // Update types index
  const typesIndexPath = path.join(process.cwd(), 'packages/types/src/index.ts');
  const typesExport = `export * from './${toCamelCase(name)}';\n`;
  await appendToFile(typesIndexPath, typesExport);

  // Update services index
  const servicesIndexPath = path.join(process.cwd(), 'packages/services/src/index.ts');
  const servicesExport = `export * from './${toCamelCase(name)}Service';\n`;
  await appendToFile(servicesIndexPath, servicesExport);

  // Print next steps
  console.log('\n' + colors.green + '✨ Scaffold complete!' + colors.reset);
  console.log('\nNext steps:');
  console.log('1. Review and customize the generated SQL view');
  console.log('2. Run the migration: ' + colors.yellow + `supabase db push` + colors.reset);
  console.log('3. Customize the component for your specific visualization needs');
  console.log('4. Add the component to your dashboard page');
  console.log('5. Run tests: ' + colors.yellow + `pnpm test ${toTitleCase(name)}` + colors.reset);
  console.log('\nExample usage in dashboard:');
  console.log(colors.blue + `
import { ${toTitleCase(name)} } from '@/components/slices/${toTitleCase(name)}';

// In your dashboard
<${toTitleCase(name)}
  from={dateRange.from}
  to={dateRange.to}
  region={selectedRegion}
  brand={selectedBrand}
/>
` + colors.reset);
}

// Helper to append to file if it exists
async function appendToFile(filePath: string, content: string) {
  try {
    const existing = await fs.readFile(filePath, 'utf-8');
    if (!existing.includes(content.trim())) {
      await fs.appendFile(filePath, content);
    }
  } catch (error) {
    // File doesn't exist, create it
    await fs.writeFile(filePath, content, 'utf-8');
  }
}

// Main execution
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    log.error('Please provide a slice name');
    console.log('Usage: pnpm scaffold:slice <slice-name>');
    console.log('Example: pnpm scaffold:slice revenue-by-channel');
    process.exit(1);
  }

  const sliceName = args[0];
  
  // Validate name
  if (!/^[a-z]+(-[a-z]+)*$/.test(sliceName)) {
    log.error('Slice name must be kebab-case (e.g., revenue-by-channel)');
    process.exit(1);
  }

  try {
    await scaffoldSlice(sliceName);
  } catch (error) {
    log.error(`Failed to scaffold: ${error}`);
    process.exit(1);
  }
}

// Run the script
main().catch(console.error);