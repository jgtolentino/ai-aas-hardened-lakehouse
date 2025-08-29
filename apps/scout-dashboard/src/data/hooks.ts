import { useQuery, UseQueryOptions } from '@tanstack/react-query';
import { supabase } from './supabase';
import type {
  ScoutFilters,
  KpiSet,
  TrendPoint,
  ParetoItem,
  SankeyLink,
  ShareTime,
  Positioning,
  GeoRow,
  FunnelRow,
  DemographicRow,
  HourWeekday,
  BoxplotData,
} from '@/../../packages/contracts/src/scout';

// Generic RPC caller
async function callRPC<T>(functionName: string, args: any): Promise<T> {
  const { data, error } = await supabase.rpc(functionName, args);
  
  if (error) {
    console.error(`RPC ${functionName} failed:`, error);
    throw new Error(error.message);
  }
  
  return data as T;
}

// Overview hooks
export function useScoutKpis(filters: ScoutFilters, options?: UseQueryOptions<KpiSet>) {
  return useQuery({
    queryKey: ['scout_kpis', filters],
    queryFn: () => callRPC<KpiSet>('scout_get_kpis', { filters }),
    staleTime: 60000, // 1 minute
    ...options,
  });
}

export function useRevenueTrend(filters: ScoutFilters, options?: UseQueryOptions<TrendPoint[]>) {
  return useQuery({
    queryKey: ['revenue_trend', filters],
    queryFn: () => callRPC<TrendPoint[]>('scout_get_revenue_trend', { filters }),
    staleTime: 60000,
    ...options,
  });
}

export function useHourWeekday(filters: ScoutFilters, options?: UseQueryOptions<HourWeekday[]>) {
  return useQuery({
    queryKey: ['hour_weekday', filters],
    queryFn: () => callRPC<HourWeekday[]>('scout_get_hour_weekday', { filters }),
    staleTime: 300000, // 5 minutes
    ...options,
  });
}

export function useBasketBoxplot(filters: ScoutFilters, options?: UseQueryOptions<BoxplotData>) {
  return useQuery({
    queryKey: ['basket_boxplot', filters],
    queryFn: () => callRPC<BoxplotData>('scout_get_basket_boxplot', { filters }),
    staleTime: 300000,
    ...options,
  });
}

// Mix hooks
export function useParetoSkus(filters: ScoutFilters, options?: UseQueryOptions<ParetoItem[]>) {
  return useQuery({
    queryKey: ['pareto_skus', filters],
    queryFn: () => callRPC<ParetoItem[]>('scout_get_pareto_skus', { filters }),
    staleTime: 60000,
    ...options,
  });
}

export function useSubstitution(
  filters: ScoutFilters,
  windowDays: number = 7,
  options?: UseQueryOptions<SankeyLink[]>
) {
  return useQuery({
    queryKey: ['substitution', filters, windowDays],
    queryFn: () => callRPC<SankeyLink[]>('scout_get_substitution', { filters, window_days: windowDays }),
    staleTime: 300000,
    ...options,
  });
}

// Competitive hooks
export function useShareTime(
  filters: ScoutFilters,
  brandSet?: string[],
  options?: UseQueryOptions<ShareTime[]>
) {
  return useQuery({
    queryKey: ['share_time', filters, brandSet],
    queryFn: () => callRPC<ShareTime[]>('scout_get_share_time', { filters, brand_set: brandSet }),
    staleTime: 60000,
    ...options,
  });
}

export function usePositioning(
  filters: ScoutFilters,
  brandSet?: string[],
  options?: UseQueryOptions<Positioning[]>
) {
  return useQuery({
    queryKey: ['positioning', filters, brandSet],
    queryFn: () => callRPC<Positioning[]>('scout_get_positioning', { filters, brand_set: brandSet }),
    staleTime: 300000,
    ...options,
  });
}

// Geography hooks
export function useGeoSummary(
  filters: ScoutFilters,
  metric: string = 'revenue',
  options?: UseQueryOptions<GeoRow[]>
) {
  return useQuery({
    queryKey: ['geo_summary', filters, metric],
    queryFn: () => callRPC<GeoRow[]>('scout_geo_summary', { filters, metric }),
    staleTime: 60000,
    ...options,
  });
}

// Consumer hooks
export function useRequestToPurchase(filters: ScoutFilters, options?: UseQueryOptions<FunnelRow[]>) {
  return useQuery({
    queryKey: ['request_to_purchase', filters],
    queryFn: () => callRPC<FunnelRow[]>('scout_request_to_purchase', { filters }),
    staleTime: 60000,
    ...options,
  });
}

export function useDemographicMix(filters: ScoutFilters, options?: UseQueryOptions<DemographicRow[]>) {
  return useQuery({
    queryKey: ['demographic_mix', filters],
    queryFn: () => callRPC<DemographicRow[]>('scout_demographic_mix', { filters }),
    staleTime: 300000,
    ...options,
  });
}

// Export helper
export async function exportCard(
  element: HTMLElement,
  format: 'png' | 'svg' | 'pdf',
  filename: string
) {
  // Implementation would use html2canvas or similar
  console.log(`Exporting ${filename} as ${format}`);
  // Placeholder for actual export logic
}
