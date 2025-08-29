/**
 * Scout Analytics Dashboard v6.0 - API Contracts
 * Frontend ↔ Supabase RPC type definitions
 */

// Filter types
export interface ScoutFilters {
  dateRange: string[];
  region: string[];
  barangay: string[];
  category: string[];
  brand: string[];
  channel: string[];
}

// KPI types
export interface KpiSet {
  revenue: number;
  transactions: number;
  basket_size: number;
  unique_shoppers: number;
}

// Chart data types
export interface TrendPoint {
  x: string;
  y: number;
}

export interface ParetoItem {
  sku: string;
  value: number;
  pctCume: number;
}

export interface SankeyLink {
  source: string;
  target: string;
  value: number;
}

export interface ShareTime {
  brand: string;
  x: string;
  share: number;
}

export interface Positioning {
  brand: string;
  price: number;
  share: number;
}

export interface GeoRow {
  geo_id: string;
  region?: string;
  barangay?: string;
  value: number;
  latitude?: number;
  longitude?: number;
}

export interface FunnelRow {
  stage: string;
  value: number;
  conversion_rate?: number;
}

export interface DemographicRow {
  group: string;
  metric: number;
  gender?: string;
  age_group?: string;
}

export interface HourWeekday {
  hour: number;
  weekday: string;
  value: number;
}

export interface BoxplotData {
  min: number;
  q1: number;
  median: number;
  q3: number;
  max: number;
  outliers?: number[];
}

// RPC function signatures
export interface ScoutRPCs {
  // Overview
  scout_get_kpis: (filters: ScoutFilters) => Promise<KpiSet>;
  scout_get_revenue_trend: (filters: ScoutFilters) => Promise<TrendPoint[]>;
  scout_get_hour_weekday: (filters: ScoutFilters) => Promise<HourWeekday[]>;
  scout_get_basket_boxplot: (filters: ScoutFilters) => Promise<BoxplotData>;
  
  // Mix
  scout_get_pareto_skus: (filters: ScoutFilters) => Promise<ParetoItem[]>;
  scout_get_substitution: (filters: ScoutFilters, windowDays: number) => Promise<SankeyLink[]>;
  scout_get_category_mix: (filters: ScoutFilters) => Promise<{ category: string; share: number }[]>;
  scout_list_skus: (filters: ScoutFilters, paging: { limit: number; offset: number }) => Promise<any[]>;
  
  // Competitive
  scout_get_share_time: (filters: ScoutFilters, brandSet: string[]) => Promise<ShareTime[]>;
  scout_get_positioning: (filters: ScoutFilters, brandSet: string[]) => Promise<Positioning[]>;
  scout_get_cannibalization: (filters: ScoutFilters, brandSet: string[]) => Promise<{ source: string; target: string; pct: number }[]>;
  
  // Geography
  scout_geo_summary: (filters: ScoutFilters, metric: string) => Promise<GeoRow[]>;
  scout_geo_drill: (filters: ScoutFilters) => Promise<any[]>;
  
  // Consumers
  scout_request_to_purchase: (filters: ScoutFilters) => Promise<FunnelRow[]>;
  scout_demographic_mix: (filters: ScoutFilters) => Promise<DemographicRow[]>;
}

// Export status types
export type ExportFormat = 'png' | 'svg' | 'pdf';

export interface ExportOptions {
  format: ExportFormat;
  includeFilters?: boolean;
  includeTimestamp?: boolean;
  aiOverlay?: boolean;
}

// Card state types
export type CardState = 'loading' | 'empty' | 'error' | 'no-perm' | 'ready';

export interface CardError {
  code: string;
  message: string;
  retryable: boolean;
}

// Feature flags
export interface FeatureFlags {
  aiOverlay: boolean;
  aiChat: boolean;
  geoHexbin: boolean;
  vendorEmbeds: {
    pbi: boolean;
    tableau: boolean;
    superset: boolean;
  };
  face: 'default' | 'pbi' | 'tableau' | 'superset';
}

// Telemetry events
export interface TelemetryEvent {
  name: 'filter.change' | 'rpc.ok' | 'rpc.err' | 'card.export' | 'ai.overlay.shown' | 'ai.chat.ask';
  tab?: string;
  module?: string;
  rpc?: string;
  duration_ms?: number;
  rows?: number;
  err_code?: string;
  metadata?: Record<string, any>;
}
