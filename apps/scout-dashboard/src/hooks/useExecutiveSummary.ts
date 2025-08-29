import { useQuery, UseQueryResult } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';

export interface ExecutiveSummaryData {
  totalRevenue: {
    current: number;
    previous: number;
    change: number;
    changePercent: number;
    trend: 'up' | 'down' | 'neutral';
  };
  activeCustomers: {
    current: number;
    previous: number;
    change: number;
    changePercent: number;
    trend: 'up' | 'down' | 'neutral';
  };
  averageOrderValue: {
    current: number;
    previous: number;
    change: number;
    changePercent: number;
    trend: 'up' | 'down' | 'neutral';
  };
  conversionRate: {
    current: number;
    previous: number;
    change: number;
    changePercent: number;
    trend: 'up' | 'down' | 'neutral';
  };
  topBrands: Array<{
    brand: string;
    revenue: number;
    changePercent: number;
    trend: 'up' | 'down' | 'neutral';
  }>;
  regionalPerformance: Array<{
    region: string;
    revenue: number;
    customers: number;
    changePercent: number;
    trend: 'up' | 'down' | 'neutral';
  }>;
  lastUpdated: string;
}

interface ExecutiveSummaryQueryOptions {
  dateRange?: {
    start: string;
    end: string;
  };
  region?: string;
  brand?: string;
  enabled?: boolean;
  refetchInterval?: number;
}

const fetchExecutiveSummary = async (
  options: ExecutiveSummaryQueryOptions = {}
): Promise<ExecutiveSummaryData> => {
  try {
    // Call the Supabase RPC function for executive summary
    const { data, error } = await supabase.rpc('get_executive_summary', {
      start_date: options.dateRange?.start || null,
      end_date: options.dateRange?.end || null,
      region_filter: options.region || null,
      brand_filter: options.brand || null,
    });

    if (error) {
      console.error('Executive summary RPC error:', error);
      throw new Error(`Failed to fetch executive summary: ${error.message}`);
    }

    if (!data || data.length === 0) {
      throw new Error('No executive summary data available');
    }

    const summary = data[0];

    // Transform the data to match our interface
    return {
      totalRevenue: {
        current: summary.total_revenue_current || 0,
        previous: summary.total_revenue_previous || 0,
        change: summary.revenue_change || 0,
        changePercent: summary.revenue_change_percent || 0,
        trend: determineTrend(summary.revenue_change_percent),
      },
      activeCustomers: {
        current: summary.active_customers_current || 0,
        previous: summary.active_customers_previous || 0,
        change: summary.customers_change || 0,
        changePercent: summary.customers_change_percent || 0,
        trend: determineTrend(summary.customers_change_percent),
      },
      averageOrderValue: {
        current: summary.avg_order_value_current || 0,
        previous: summary.avg_order_value_previous || 0,
        change: summary.aov_change || 0,
        changePercent: summary.aov_change_percent || 0,
        trend: determineTrend(summary.aov_change_percent),
      },
      conversionRate: {
        current: summary.conversion_rate_current || 0,
        previous: summary.conversion_rate_previous || 0,
        change: summary.conversion_change || 0,
        changePercent: summary.conversion_change_percent || 0,
        trend: determineTrend(summary.conversion_change_percent),
      },
      topBrands: (summary.top_brands || []).map((brand: any) => ({
        brand: brand.brand_name,
        revenue: brand.revenue,
        changePercent: brand.change_percent,
        trend: determineTrend(brand.change_percent),
      })),
      regionalPerformance: (summary.regional_performance || []).map((region: any) => ({
        region: region.region_name,
        revenue: region.revenue,
        customers: region.customers,
        changePercent: region.change_percent,
        trend: determineTrend(region.change_percent),
      })),
      lastUpdated: summary.last_updated || new Date().toISOString(),
    };
  } catch (error) {
    console.error('Error in fetchExecutiveSummary:', error);
    throw error;
  }
};

const determineTrend = (changePercent: number): 'up' | 'down' | 'neutral' => {
  if (changePercent > 0.5) return 'up';
  if (changePercent < -0.5) return 'down';
  return 'neutral';
};

/**
 * Hook to fetch executive summary data with caching and error handling
 * 
 * @param options Query options including date range, filters, and cache settings
 * @returns UseQueryResult with executive summary data
 */
export const useExecutiveSummary = (
  options: ExecutiveSummaryQueryOptions = {}
): UseQueryResult<ExecutiveSummaryData, Error> => {
  const {
    dateRange,
    region,
    brand,
    enabled = true,
    refetchInterval = 5 * 60 * 1000, // 5 minutes
  } = options;

  return useQuery<ExecutiveSummaryData, Error>({
    queryKey: [
      'executive-summary',
      dateRange?.start,
      dateRange?.end,
      region,
      brand,
    ],
    queryFn: () => fetchExecutiveSummary(options),
    enabled,
    refetchInterval,
    staleTime: 2 * 60 * 1000, // 2 minutes
    gcTime: 10 * 60 * 1000, // 10 minutes (formerly cacheTime)
    retry: (failureCount, error) => {
      // Don't retry on authentication errors
      if (error.message.includes('JWT') || error.message.includes('auth')) {
        return false;
      }
      // Retry up to 3 times for other errors
      return failureCount < 3;
    },
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
  });
};

/**
 * Hook to get just the KPI metrics for the KpiRow component
 */
export const useExecutiveKpis = (options: ExecutiveSummaryQueryOptions = {}) => {
  const query = useExecutiveSummary(options);

  const kpiMetrics = query.data ? [
    {
      id: 'total-revenue',
      title: 'Total Revenue',
      value: query.data.totalRevenue.current,
      previousValue: query.data.totalRevenue.previous,
      trend: query.data.totalRevenue.trend,
      change: query.data.totalRevenue.changePercent,
      changeType: 'percentage' as const,
      format: 'currency' as const,
      isLoading: query.isLoading,
    },
    {
      id: 'active-customers',
      title: 'Active Customers',
      value: query.data.activeCustomers.current,
      previousValue: query.data.activeCustomers.previous,
      trend: query.data.activeCustomers.trend,
      change: query.data.activeCustomers.changePercent,
      changeType: 'percentage' as const,
      format: 'number' as const,
      isLoading: query.isLoading,
    },
    {
      id: 'avg-order-value',
      title: 'Avg. Order Value',
      value: query.data.averageOrderValue.current,
      previousValue: query.data.averageOrderValue.previous,
      trend: query.data.averageOrderValue.trend,
      change: query.data.averageOrderValue.changePercent,
      changeType: 'percentage' as const,
      format: 'currency' as const,
      isLoading: query.isLoading,
    },
    {
      id: 'conversion-rate',
      title: 'Conversion Rate',
      value: query.data.conversionRate.current,
      previousValue: query.data.conversionRate.previous,
      trend: query.data.conversionRate.trend,
      change: query.data.conversionRate.changePercent,
      changeType: 'percentage' as const,
      format: 'percentage' as const,
      isLoading: query.isLoading,
    },
  ] : [];

  return {
    ...query,
    kpiMetrics,
  };
};

export default useExecutiveSummary;