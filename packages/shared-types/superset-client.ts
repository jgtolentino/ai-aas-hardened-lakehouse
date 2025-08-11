/**
 * Superset Client for Lovable App Integration
 * 
 * TypeScript client for interacting with the Superset JWT proxy
 * from the Lovable React application.
 */

export interface SupersetDashboard {
  id: number;
  dashboard_title: string;
  url: string;
  position_json?: string;
  css?: string;
  slug?: string;
  owners?: Array<{
    id: number;
    username: string;
    first_name: string;
    last_name: string;
  }>;
  created_on: string;
  changed_on: string;
}

export interface EmbedDashboardResponse {
  embed_url: string;
  expires_in: number;
  dashboard_id: string;
  filters: Record<string, any>;
}

export interface SupersetFilter {
  [key: string]: string | number | boolean | string[];
}

export interface SupersetClientConfig {
  proxyUrl: string;
  lovableToken: string;
  defaultFilters?: SupersetFilter;
}

export class SupersetClient {
  private config: SupersetClientConfig;
  private headers: Headers;

  constructor(config: SupersetClientConfig) {
    this.config = config;
    this.headers = new Headers({
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${config.lovableToken}`,
    });
  }

  /**
   * Get an embedded dashboard URL with optional filters
   */
  async getEmbeddedDashboard(
    dashboardId: string,
    filters: SupersetFilter = {}
  ): Promise<EmbedDashboardResponse> {
    const params = new URLSearchParams({
      dashboard_id: dashboardId,
    });

    // Add filters as query parameters
    Object.entries({ ...this.config.defaultFilters, ...filters }).forEach(([key, value]) => {
      if (Array.isArray(value)) {
        value.forEach(v => params.append(`filter_${key}`, v.toString()));
      } else {
        params.append(`filter_${key}`, value.toString());
      }
    });

    const response = await fetch(`${this.config.proxyUrl}/embed-dashboard?${params}`, {
      method: 'GET',
      headers: this.headers,
    });

    if (!response.ok) {
      throw new Error(`Failed to get embedded dashboard: ${response.statusText}`);
    }

    return response.json();
  }

  /**
   * List all available dashboards
   */
  async listDashboards(): Promise<SupersetDashboard[]> {
    const response = await fetch(`${this.config.proxyUrl}/dashboards`, {
      method: 'GET',
      headers: this.headers,
    });

    if (!response.ok) {
      throw new Error(`Failed to list dashboards: ${response.statusText}`);
    }

    const data = await response.json();
    return data.result || [];
  }

  /**
   * Get dashboard metadata
   */
  async getDashboard(dashboardId: string): Promise<SupersetDashboard> {
    const response = await fetch(`${this.config.proxyUrl}/dashboard/${dashboardId}`, {
      method: 'GET',
      headers: this.headers,
    });

    if (!response.ok) {
      throw new Error(`Failed to get dashboard: ${response.statusText}`);
    }

    const data = await response.json();
    return data.result;
  }

  /**
   * Check if the Superset proxy is healthy
   */
  async checkHealth(): Promise<{ status: string; superset_url: string; timestamp: string }> {
    const response = await fetch(`${this.config.proxyUrl}/health`, {
      method: 'GET',
      headers: this.headers,
    });

    if (!response.ok) {
      throw new Error(`Health check failed: ${response.statusText}`);
    }

    return response.json();
  }

  /**
   * Make a direct API call to Superset through the proxy
   */
  async apiCall(endpoint: string, options: RequestInit = {}): Promise<any> {
    const response = await fetch(`${this.config.proxyUrl}/api${endpoint}`, {
      ...options,
      headers: {
        ...this.headers,
        ...(options.headers || {}),
      },
    });

    if (!response.ok) {
      throw new Error(`API call failed: ${response.statusText}`);
    }

    return response.json();
  }

  /**
   * Update client configuration
   */
  updateConfig(newConfig: Partial<SupersetClientConfig>): void {
    this.config = { ...this.config, ...newConfig };
    
    if (newConfig.lovableToken) {
      this.headers.set('Authorization', `Bearer ${newConfig.lovableToken}`);
    }
  }
}

/**
 * React Hook for Superset integration
 */
export interface UseSuperset {
  client: SupersetClient;
  embedDashboard: (dashboardId: string, filters?: SupersetFilter) => Promise<EmbedDashboardResponse>;
  dashboards: SupersetDashboard[] | null;
  loading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
}

// Export factory function for React hook (to be implemented in Lovable)
export const createSupersetHook = (config: SupersetClientConfig) => {
  return (initialDashboardId?: string): UseSuperset => {
    // This would be implemented in the Lovable app using React hooks
    throw new Error('useSuperset hook should be implemented in the Lovable app');
  };
};

// Configuration helpers
export const SupersetConfig = {
  // Scout Analytics specific dashboard IDs
  SCOUT_OVERVIEW: 'scout-overview',
  REVENUE_ANALYTICS: 'revenue-analytics',
  STORE_PERFORMANCE: 'store-performance',
  ML_PREDICTIONS: 'ml-predictions',
  
  // Common filter presets
  FILTERS: {
    LAST_7_DAYS: {
      date_range: '7 days ago : now',
    },
    LAST_30_DAYS: {
      date_range: '30 days ago : now',
    },
    CURRENT_MONTH: {
      date_range: 'this month',
    },
    TOP_STORES: {
      store_tier: 'Top 10',
    },
  },
  
  // Environment-specific proxy URLs
  PROXY_URLS: {
    development: 'http://localhost:54321/functions/v1/superset-jwt-proxy',
    staging: 'https://cxzllzyxwpyptfretryc.supabase.co/functions/v1/superset-jwt-proxy',
    production: 'https://cxzllzyxwpyptfretryc.supabase.co/functions/v1/superset-jwt-proxy',
  },
};

// Export default client factory
export const createSupersetClient = (
  environment: 'development' | 'staging' | 'production' = 'production',
  lovableToken: string,
  defaultFilters: SupersetFilter = {}
): SupersetClient => {
  return new SupersetClient({
    proxyUrl: SupersetConfig.PROXY_URLS[environment],
    lovableToken,
    defaultFilters: { ...SupersetConfig.FILTERS.LAST_7_DAYS, ...defaultFilters },
  });
};