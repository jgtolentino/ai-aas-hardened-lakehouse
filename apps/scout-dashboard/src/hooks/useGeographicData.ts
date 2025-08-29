import { useQuery, UseQueryResult } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';

export interface GeographicDataPoint {
  id: string;
  latitude: number;
  longitude: number;
  barangay: string;
  municipality: string;
  province: string;
  region: string;
  value: number;
  metadata?: Record<string, any>;
}

export interface BarangayBoundary {
  id: string;
  barangay_code: string;
  barangay_name: string;
  municipality: string;
  province: string;
  region: string;
  geometry: GeoJSON.Polygon | GeoJSON.MultiPolygon;
  properties: Record<string, any>;
}

export interface GeographicCluster {
  id: string;
  center: [number, number];
  bounds: [[number, number], [number, number]];
  point_count: number;
  total_value: number;
  average_value: number;
  points: GeographicDataPoint[];
}

interface GeographicDataOptions {
  region?: string;
  province?: string;
  municipality?: string;
  dateRange?: {
    start: string;
    end: string;
  };
  metric?: 'sales' | 'customers' | 'visits' | 'revenue';
  clustered?: boolean;
  zoomLevel?: number;
  enabled?: boolean;
}

interface RLSContext {
  user_id: string;
  user_role: string;
  accessible_regions?: string[];
  accessible_provinces?: string[];
  data_classification: 'public' | 'internal' | 'confidential';
}

/**
 * Inject RLS token with geographic access context
 */
const injectRLSToken = async (options: GeographicDataOptions): Promise<RLSContext> => {
  try {
    // Get current user session
    const { data: { session }, error: sessionError } = await supabase.auth.getSession();
    
    if (sessionError || !session) {
      throw new Error('Authentication required for geographic data access');
    }

    // Extract user context from JWT
    const userMetadata = session.user.user_metadata || {};
    const userRole = session.user.role || 'viewer';

    // Determine geographic access permissions based on user role and region
    const rlsContext: RLSContext = {
      user_id: session.user.id,
      user_role: userRole,
      data_classification: determineDataClassification(userRole),
    };

    // Set role-based geographic access
    if (userRole === 'admin' || userRole === 'executive') {
      // Full access to all regions
      rlsContext.accessible_regions = undefined; // undefined means all
    } else if (userRole === 'regional_manager') {
      // Access to specific region(s)
      rlsContext.accessible_regions = userMetadata.assigned_regions || [];
    } else if (userRole === 'provincial_manager') {
      // Access to specific province(s)
      rlsContext.accessible_provinces = userMetadata.assigned_provinces || [];
    }

    // Apply RLS context to current session
    const { error: rlsError } = await supabase.rpc('set_geographic_rls_context', {
      context: rlsContext,
      requested_region: options.region,
      requested_province: options.province,
      requested_metric: options.metric,
    });

    if (rlsError) {
      console.error('RLS context setting failed:', rlsError);
      throw new Error(`Geographic access denied: ${rlsError.message}`);
    }

    return rlsContext;
  } catch (error) {
    console.error('RLS token injection failed:', error);
    throw error;
  }
};

/**
 * Determine data classification based on user role
 */
const determineDataClassification = (role: string): 'public' | 'internal' | 'confidential' => {
  switch (role) {
    case 'admin':
    case 'executive':
      return 'confidential';
    case 'regional_manager':
    case 'provincial_manager':
    case 'analyst':
      return 'internal';
    default:
      return 'public';
  }
};

/**
 * Fetch geographic data points with RLS token injection
 */
const fetchGeographicData = async (options: GeographicDataOptions = {}): Promise<GeographicDataPoint[]> => {
  try {
    // Inject RLS token first
    const rlsContext = await injectRLSToken(options);
    
    // Build query parameters
    const queryParams = {
      region_filter: options.region || null,
      province_filter: options.province || null,
      municipality_filter: options.municipality || null,
      start_date: options.dateRange?.start || null,
      end_date: options.dateRange?.end || null,
      metric_type: options.metric || 'sales',
      zoom_level: options.zoomLevel || 8,
      is_clustered: options.clustered || false,
    };

    // Call RPC function with RLS context
    const { data, error } = await supabase.rpc('get_geographic_data', queryParams);

    if (error) {
      console.error('Geographic data RPC error:', error);
      throw new Error(`Failed to fetch geographic data: ${error.message}`);
    }

    if (!data) {
      return [];
    }

    // Transform and validate data
    return data.map((item: any) => ({
      id: item.id,
      latitude: parseFloat(item.latitude),
      longitude: parseFloat(item.longitude),
      barangay: item.barangay,
      municipality: item.municipality,
      province: item.province,
      region: item.region,
      value: parseFloat(item.value || 0),
      metadata: item.metadata || {},
    }));
  } catch (error) {
    console.error('Error in fetchGeographicData:', error);
    throw error;
  }
};

/**
 * Fetch barangay boundaries with RLS protection
 */
const fetchBarangayBoundaries = async (options: GeographicDataOptions = {}): Promise<BarangayBoundary[]> => {
  try {
    // Inject RLS token
    const rlsContext = await injectRLSToken(options);
    
    const { data, error } = await supabase.rpc('get_barangay_boundaries', {
      region_filter: options.region || null,
      province_filter: options.province || null,
      municipality_filter: options.municipality || null,
    });

    if (error) {
      console.error('Barangay boundaries RPC error:', error);
      throw new Error(`Failed to fetch barangay boundaries: ${error.message}`);
    }

    return data || [];
  } catch (error) {
    console.error('Error in fetchBarangayBoundaries:', error);
    throw error;
  }
};

/**
 * Hook to fetch geographic data with RLS token injection
 */
export const useGeographicData = (
  options: GeographicDataOptions = {}
): UseQueryResult<GeographicDataPoint[], Error> => {
  const {
    region,
    province,
    municipality,
    dateRange,
    metric = 'sales',
    clustered = false,
    zoomLevel = 8,
    enabled = true,
  } = options;

  return useQuery<GeographicDataPoint[], Error>({
    queryKey: [
      'geographic-data',
      region,
      province,
      municipality,
      dateRange?.start,
      dateRange?.end,
      metric,
      clustered,
      zoomLevel,
    ],
    queryFn: () => fetchGeographicData(options),
    enabled,
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 15 * 60 * 1000, // 15 minutes
    retry: (failureCount, error) => {
      // Don't retry on authentication or authorization errors
      if (error.message.includes('Authentication') || 
          error.message.includes('access denied')) {
        return false;
      }
      return failureCount < 2;
    },
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 10000),
  });
};

/**
 * Hook to fetch barangay boundaries with RLS protection
 */
export const useBarangayBoundaries = (
  options: GeographicDataOptions = {}
): UseQueryResult<BarangayBoundary[], Error> => {
  const { region, province, municipality, enabled = true } = options;

  return useQuery<BarangayBoundary[], Error>({
    queryKey: ['barangay-boundaries', region, province, municipality],
    queryFn: () => fetchBarangayBoundaries(options),
    enabled,
    staleTime: 30 * 60 * 1000, // 30 minutes (boundaries don't change often)
    gcTime: 60 * 60 * 1000, // 60 minutes
    retry: (failureCount, error) => {
      if (error.message.includes('Authentication') || 
          error.message.includes('access denied')) {
        return false;
      }
      return failureCount < 2;
    },
  });
};

/**
 * Hook to get current user's geographic access permissions
 */
export const useGeographicPermissions = () => {
  return useQuery<RLSContext, Error>({
    queryKey: ['geographic-permissions'],
    queryFn: async () => {
      // Get current session and determine permissions
      const { data: { session }, error } = await supabase.auth.getSession();
      
      if (error || !session) {
        throw new Error('Authentication required');
      }

      return await injectRLSToken({});
    },
    staleTime: 15 * 60 * 1000, // 15 minutes
    gcTime: 30 * 60 * 1000, // 30 minutes
  });
};

export default {
  useGeographicData,
  useBarangayBoundaries,
  useGeographicPermissions,
};