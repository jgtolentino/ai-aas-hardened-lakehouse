import type { Meta, StoryObj } from '@storybook/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { KpiRow } from './KpiRow';
import type { KpiMetric } from './KpiRow';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: false,
    },
  },
});

const meta = {
  title: 'Executive/KpiRow',
  component: KpiRow,
  decorators: [
    (Story) => (
      <QueryClientProvider client={queryClient}>
        <div className="p-6 bg-gray-50 min-h-screen">
          <Story />
        </div>
      </QueryClientProvider>
    ),
  ],
  parameters: {
    layout: 'fullscreen',
    docs: {
      description: {
        component: `
KpiRow displays a grid of key performance indicators with trend indicators, loading states, and accessibility features.

## Features
- Responsive grid layout (1-4 columns)
- Loading skeleton animations
- Trend indicators with icons
- Accessibility compliance (WCAG 2.1 AA)
- Multiple display variants
- Currency, number, and percentage formatting
        `,
      },
    },
  },
  argTypes: {
    variant: {
      control: { type: 'select' },
      options: ['default', 'compact', 'detailed'],
      description: 'Display variant affecting spacing and information density',
    },
    className: {
      control: 'text',
      description: 'Additional CSS classes for customization',
    },
  },
} satisfies Meta<typeof KpiRow>;

export default meta;
type Story = StoryObj<typeof meta>;

// Sample data for stories
const sampleMetrics: KpiMetric[] = [
  {
    id: 'total-revenue',
    title: 'Total Revenue',
    value: 1250000,
    previousValue: 1180000,
    trend: 'up',
    change: 5.9,
    changeType: 'percentage',
    format: 'currency',
    isLoading: false,
  },
  {
    id: 'active-customers',
    title: 'Active Customers',
    value: 8420,
    previousValue: 8150,
    trend: 'up',
    change: 3.3,
    changeType: 'percentage',
    format: 'number',
    isLoading: false,
  },
  {
    id: 'avg-order-value',
    title: 'Avg. Order Value',
    value: 148.5,
    previousValue: 144.8,
    trend: 'up',
    change: 2.6,
    changeType: 'percentage',
    format: 'currency',
    isLoading: false,
  },
  {
    id: 'conversion-rate',
    title: 'Conversion Rate',
    value: 3.4,
    previousValue: 3.1,
    trend: 'up',
    change: 9.7,
    changeType: 'percentage',
    format: 'percentage',
    isLoading: false,
  },
];

const loadingMetrics: KpiMetric[] = sampleMetrics.map(metric => ({
  ...metric,
  isLoading: true,
}));

const mixedTrendMetrics: KpiMetric[] = [
  {
    id: 'total-revenue',
    title: 'Total Revenue',
    value: 980000,
    previousValue: 1180000,
    trend: 'down',
    change: -17.0,
    changeType: 'percentage',
    format: 'currency',
    isLoading: false,
  },
  {
    id: 'active-customers',
    title: 'Active Customers',
    value: 8420,
    previousValue: 8400,
    trend: 'neutral',
    change: 0.2,
    changeType: 'percentage',
    format: 'number',
    isLoading: false,
  },
  {
    id: 'avg-order-value',
    title: 'Avg. Order Value',
    value: 165.3,
    previousValue: 144.8,
    trend: 'up',
    change: 14.1,
    changeType: 'percentage',
    format: 'currency',
    isLoading: false,
  },
  {
    id: 'conversion-rate',
    title: 'Conversion Rate',
    value: 2.8,
    previousValue: 3.1,
    trend: 'down',
    change: -9.7,
    changeType: 'percentage',
    format: 'percentage',
    isLoading: false,
  },
];

const twoMetrics: KpiMetric[] = [
  {
    id: 'total-sales',
    title: 'Total Sales',
    value: 45680,
    trend: 'up',
    change: 12.5,
    changeType: 'percentage',
    format: 'number',
    unit: ' orders',
    isLoading: false,
  },
  {
    id: 'market-share',
    title: 'Market Share',
    value: 23.7,
    previousValue: 21.2,
    trend: 'up',
    change: 11.8,
    changeType: 'percentage',
    format: 'percentage',
    isLoading: false,
  },
];

export const Default: Story = {
  args: {
    metrics: sampleMetrics,
  },
};

export const Loading: Story = {
  args: {
    metrics: loadingMetrics,
  },
  parameters: {
    docs: {
      description: {
        story: 'Loading state with skeleton animations for all KPI tiles.',
      },
    },
  },
};

export const Compact: Story = {
  args: {
    metrics: sampleMetrics,
    variant: 'compact',
  },
  parameters: {
    docs: {
      description: {
        story: 'Compact variant with reduced spacing and smaller text, ideal for dense dashboards.',
      },
    },
  },
};

export const Detailed: Story = {
  args: {
    metrics: sampleMetrics,
    variant: 'detailed',
  },
  parameters: {
    docs: {
      description: {
        story: 'Detailed variant showing previous values and using a 3-column grid on larger screens.',
      },
    },
  },
};

export const MixedTrends: Story = {
  args: {
    metrics: mixedTrendMetrics,
  },
  parameters: {
    docs: {
      description: {
        story: 'KPI tiles showing different trends: up (green), down (red), and neutral (gray).',
      },
    },
  },
};

export const TwoMetrics: Story = {
  args: {
    metrics: twoMetrics,
  },
  parameters: {
    docs: {
      description: {
        story: 'Layout with only two metrics, demonstrating responsive behavior.',
      },
    },
  },
};

export const WithCustomUnit: Story = {
  args: {
    metrics: [
      {
        id: 'website-visits',
        title: 'Website Visits',
        value: 125000,
        previousValue: 98000,
        trend: 'up',
        change: 27.6,
        changeType: 'percentage',
        format: 'number',
        unit: ' visits',
        isLoading: false,
      },
      {
        id: 'bounce-rate',
        title: 'Bounce Rate',
        value: 34.2,
        previousValue: 41.7,
        trend: 'down', // Lower bounce rate is good
        change: -18.0,
        changeType: 'percentage',
        format: 'percentage',
        isLoading: false,
      },
      {
        id: 'session-duration',
        title: 'Avg. Session Duration',
        value: '4:32',
        previousValue: '3:45',
        trend: 'up',
        change: 20.9,
        changeType: 'percentage',
        isLoading: false,
      },
    ],
  },
  parameters: {
    docs: {
      description: {
        story: 'KPIs with custom units and string values for duration display.',
      },
    },
  },
};

export const NoChangeData: Story = {
  args: {
    metrics: sampleMetrics.map(metric => ({
      ...metric,
      change: undefined,
      trend: undefined,
      previousValue: undefined,
    })),
  },
  parameters: {
    docs: {
      description: {
        story: 'KPI tiles without trend or change data, showing only current values.',
      },
    },
  },
};

export const LargeNumbers: Story = {
  args: {
    metrics: [
      {
        id: 'enterprise-revenue',
        title: 'Enterprise Revenue',
        value: 123456789,
        previousValue: 98765432,
        trend: 'up',
        change: 25.0,
        changeType: 'percentage',
        format: 'currency',
        isLoading: false,
      },
      {
        id: 'global-users',
        title: 'Global Users',
        value: 2500000,
        previousValue: 2100000,
        trend: 'up',
        change: 19.0,
        changeType: 'percentage',
        format: 'number',
        isLoading: false,
      },
    ],
  },
  parameters: {
    docs: {
      description: {
        story: 'KPIs with very large numbers to test number formatting.',
      },
    },
  },
};

export const MobileView: Story = {
  args: {
    metrics: sampleMetrics,
  },
  parameters: {
    viewport: {
      defaultViewport: 'mobile1',
    },
    docs: {
      description: {
        story: 'Mobile view showing single-column layout on small screens.',
      },
    },
  },
};

export const TabletView: Story = {
  args: {
    metrics: sampleMetrics,
  },
  parameters: {
    viewport: {
      defaultViewport: 'tablet',
    },
    docs: {
      description: {
        story: 'Tablet view showing two-column layout on medium screens.',
      },
    },
  },
};

export const WithCustomClassName: Story = {
  args: {
    metrics: sampleMetrics.slice(0, 2),
    className: 'bg-blue-50 p-4 rounded-lg border-2 border-blue-200',
  },
  parameters: {
    docs: {
      description: {
        story: 'KPI row with custom styling applied via className prop.',
      },
    },
  },
};

// Interactive story for testing different states
export const Interactive: Story = {
  args: {
    metrics: sampleMetrics,
    variant: 'default',
  },
  parameters: {
    docs: {
      description: {
        story: 'Interactive story for testing different variants and configurations.',
      },
    },
  },
};