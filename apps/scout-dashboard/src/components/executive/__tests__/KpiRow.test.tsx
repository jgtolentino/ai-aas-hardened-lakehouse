import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { rest } from 'msw';
import { setupServer } from 'msw/node';
import { KpiRow } from '../KpiRow';
import { useExecutiveKpis } from '@/hooks/useExecutiveSummary';
import type { KpiMetric } from '../KpiRow';

// Mock the Supabase client
jest.mock('@/lib/supabase', () => ({
  supabase: {
    rpc: jest.fn(),
  },
}));

// Mock hook data
const mockKpiMetrics: KpiMetric[] = [
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
    unit: 'PHP',
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

const mockLoadingMetrics: KpiMetric[] = mockKpiMetrics.map(metric => ({
  ...metric,
  isLoading: true,
}));

// MSW Server Setup
const mockExecutiveSummaryData = {
  total_revenue_current: 1250000,
  total_revenue_previous: 1180000,
  revenue_change: 70000,
  revenue_change_percent: 5.9,
  active_customers_current: 8420,
  active_customers_previous: 8150,
  customers_change: 270,
  customers_change_percent: 3.3,
  avg_order_value_current: 148.5,
  avg_order_value_previous: 144.8,
  aov_change: 3.7,
  aov_change_percent: 2.6,
  conversion_rate_current: 3.4,
  conversion_rate_previous: 3.1,
  conversion_change: 0.3,
  conversion_change_percent: 9.7,
  top_brands: [],
  regional_performance: [],
  last_updated: new Date().toISOString(),
};

const server = setupServer(
  rest.post('/rest/v1/rpc/get_executive_summary', (req, res, ctx) => {
    return res(ctx.json([mockExecutiveSummaryData]));
  })
);

// Test utilities
const createQueryClient = () =>
  new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
        gcTime: 0,
      },
    },
  });

const renderWithQueryClient = (component: React.ReactElement) => {
  const queryClient = createQueryClient();
  return render(
    <QueryClientProvider client={queryClient}>
      {component}
    </QueryClientProvider>
  );
};

describe('KpiRow Component', () => {
  beforeAll(() => server.listen());
  afterEach(() => {
    server.resetHandlers();
    jest.clearAllMocks();
  });
  afterAll(() => server.close());

  describe('Rendering', () => {
    it('renders KPI metrics correctly', () => {
      render(<KpiRow metrics={mockKpiMetrics} />);

      // Check if all KPI titles are rendered
      expect(screen.getByText('Total Revenue')).toBeInTheDocument();
      expect(screen.getByText('Active Customers')).toBeInTheDocument();
      expect(screen.getByText('Avg. Order Value')).toBeInTheDocument();
      expect(screen.getByText('Conversion Rate')).toBeInTheDocument();
    });

    it('displays formatted values correctly', () => {
      render(<KpiRow metrics={mockKpiMetrics} />);

      // Check currency formatting for Total Revenue
      expect(screen.getByText('₱1,250,000')).toBeInTheDocument();
      
      // Check number formatting for Active Customers
      expect(screen.getByText('8,420')).toBeInTheDocument();
      
      // Check percentage formatting for Conversion Rate
      expect(screen.getByText('3.4%')).toBeInTheDocument();
    });

    it('displays trend indicators correctly', () => {
      render(<KpiRow metrics={mockKpiMetrics} />);

      // All mock metrics have 'up' trend, so we should see up arrow icons
      const upArrows = screen.getAllByRole('img', { hidden: true });
      expect(upArrows).toHaveLength(4); // One for each metric
    });

    it('displays change percentages correctly', () => {
      render(<KpiRow metrics={mockKpiMetrics} />);

      expect(screen.getByText('+5.9%')).toBeInTheDocument();
      expect(screen.getByText('+3.3%')).toBeInTheDocument();
      expect(screen.getByText('+2.6%')).toBeInTheDocument();
      expect(screen.getByText('+9.7%')).toBeInTheDocument();
    });
  });

  describe('Loading States', () => {
    it('renders loading skeletons when isLoading is true', () => {
      render(<KpiRow metrics={mockLoadingMetrics} />);

      // Check for loading skeletons (animate-pulse class)
      const loadingElements = document.querySelectorAll('.animate-pulse');
      expect(loadingElements).toHaveLength(4); // One for each metric
    });

    it('does not render actual content when loading', () => {
      render(<KpiRow metrics={mockLoadingMetrics} />);

      // Titles should not be visible during loading
      expect(screen.queryByText('Total Revenue')).not.toBeInTheDocument();
      expect(screen.queryByText('Active Customers')).not.toBeInTheDocument();
    });
  });

  describe('Variants', () => {
    it('applies compact styling correctly', () => {
      const { container } = render(
        <KpiRow metrics={mockKpiMetrics} variant="compact" />
      );

      // Check for gap-3 class (compact spacing)
      const kpiRowElement = container.firstChild;
      expect(kpiRowElement).toHaveClass('gap-3');
    });

    it('applies detailed styling correctly', () => {
      const { container } = render(
        <KpiRow metrics={mockKpiMetrics} variant="detailed" />
      );

      // Check for gap-6 class (detailed spacing) and lg:grid-cols-3
      const kpiRowElement = container.firstChild;
      expect(kpiRowElement).toHaveClass('gap-6', 'lg:grid-cols-3');
    });

    it('shows previous values in detailed variant', () => {
      render(<KpiRow metrics={mockKpiMetrics} variant="detailed" />);

      // In detailed variant, previous values should be shown
      expect(screen.getByText(/Previous:/)).toBeInTheDocument();
      expect(screen.getByText('₱1,180,000')).toBeInTheDocument();
    });
  });

  describe('Accessibility', () => {
    it('has proper ARIA labels', () => {
      render(<KpiRow metrics={mockKpiMetrics} />);

      // Check for region role on main container
      expect(screen.getByRole('region')).toBeInTheDocument();
      expect(screen.getByLabelText('Key Performance Indicators')).toBeInTheDocument();

      // Check for article roles on individual KPI tiles
      const articles = screen.getAllByRole('article');
      expect(articles).toHaveLength(4);
    });

    it('has proper aria-live regions for values', () => {
      render(<KpiRow metrics={mockKpiMetrics} />);

      // Check for aria-live="polite" on value elements
      const liveRegions = screen.getAllByLabelText(/₱1,250,000|8,420|₱149|3.4%/);
      liveRegions.forEach(element => {
        expect(element).toHaveAttribute('aria-live', 'polite');
      });
    });

    it('provides descriptive change labels', () => {
      render(<KpiRow metrics={mockKpiMetrics} />);

      // Check for descriptive aria-labels on change indicators
      expect(screen.getByLabelText('Change from previous period: 5.9%')).toBeInTheDocument();
      expect(screen.getByLabelText('Change from previous period: 3.3%')).toBeInTheDocument();
    });
  });

  describe('Error Handling', () => {
    it('handles missing trend gracefully', () => {
      const metricsWithoutTrend = mockKpiMetrics.map(metric => ({
        ...metric,
        trend: undefined,
      }));

      render(<KpiRow metrics={metricsWithoutTrend} />);

      // Should still render values without errors
      expect(screen.getByText('Total Revenue')).toBeInTheDocument();
      expect(screen.getByText('₱1,250,000')).toBeInTheDocument();
    });

    it('handles missing change values gracefully', () => {
      const metricsWithoutChange = mockKpiMetrics.map(metric => ({
        ...metric,
        change: undefined,
        trend: undefined,
      }));

      render(<KpiRow metrics={metricsWithoutChange} />);

      // Should still render titles and values
      expect(screen.getByText('Total Revenue')).toBeInTheDocument();
      expect(screen.getByText('₱1,250,000')).toBeInTheDocument();
      
      // Should not show change indicators
      expect(screen.queryByText('%')).not.toBeInTheDocument();
    });
  });

  describe('Custom className', () => {
    it('applies custom className correctly', () => {
      const { container } = render(
        <KpiRow metrics={mockKpiMetrics} className="custom-class" />
      );

      const kpiRowElement = container.firstChild;
      expect(kpiRowElement).toHaveClass('custom-class');
    });
  });

  describe('Empty state', () => {
    it('renders empty grid when no metrics provided', () => {
      const { container } = render(<KpiRow metrics={[]} />);

      // Should still render the grid container
      const kpiRowElement = container.firstChild;
      expect(kpiRowElement).toHaveClass('grid');
      
      // But no articles should be present
      expect(screen.queryAllByRole('article')).toHaveLength(0);
    });
  });
});

describe('KpiRow Integration with useExecutiveKpis', () => {
  beforeAll(() => server.listen());
  afterEach(() => {
    server.resetHandlers();
    jest.clearAllMocks();
  });
  afterAll(() => server.close());

  it('integrates correctly with useExecutiveKpis hook', async () => {
    const TestComponent = () => {
      const { kpiMetrics, isLoading } = useExecutiveKpis();
      
      if (isLoading) {
        return <div data-testid="loading">Loading...</div>;
      }
      
      return <KpiRow metrics={kpiMetrics} data-testid="kpi-row" />;
    };

    renderWithQueryClient(<TestComponent />);

    // Should show loading initially
    expect(screen.getByTestId('loading')).toBeInTheDocument();

    // Wait for data to load
    await waitFor(() => {
      expect(screen.getByText('Total Revenue')).toBeInTheDocument();
    });

    // Should render KPI metrics
    expect(screen.getByText('₱1,250,000')).toBeInTheDocument();
    expect(screen.getByText('8,420')).toBeInTheDocument();
  });
});