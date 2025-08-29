import { useState, useCallback, useMemo } from 'react';
import { useQuery, UseQueryResult } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';

export type GeographicLevel = 'region' | 'province' | 'municipality' | 'barangay';

export interface GeographicHierarchy {
  region: string;
  province?: string;
  municipality?: string;
  barangay?: string;
}

export interface DrilldownNode {
  id: string;
  name: string;
  code: string;
  level: GeographicLevel;
  parent_id?: string;
  parent_name?: string;
  children_count: number;
  has_data: boolean;
  coordinates?: [number, number];
  bounds?: [[number, number], [number, number]];
  metadata: {
    population?: number;
    area_sqkm?: number;
    total_stores?: number;
    total_sales?: number;
    total_customers?: number;
    last_updated?: string;
  };
}

export interface DrilldownState {
  level: GeographicLevel;
  hierarchy: GeographicHierarchy;
  breadcrumb: Array<{
    level: GeographicLevel;
    name: string;
    hierarchy: GeographicHierarchy;
  }>;
  currentNodes: DrilldownNode[];
  selectedNode?: DrilldownNode;
  canDrillDown: boolean;
  canDrillUp: boolean;
}

interface DrilldownOptions {
  dateRange?: {
    start: string;
    end: string;
  };
  metric?: 'sales' | 'customers' | 'visits' | 'revenue';
  minThreshold?: number;
  enabled?: boolean;
}

interface DrilldownFilters {
  search?: string;
  sortBy?: 'name' | 'value' | 'population';
  sortOrder?: 'asc' | 'desc';
  hasDataOnly?: boolean;
}

/**
 * Fetch geographic drilldown data for a specific level and parent
 */
const fetchDrilldownData = async (
  level: GeographicLevel,
  hierarchy: GeographicHierarchy,
  options: DrilldownOptions = {},
  filters: DrilldownFilters = {}
): Promise<DrilldownNode[]> => {
  try {
    const { data, error } = await supabase.rpc('get_geographic_drilldown', {
      target_level: level,
      region_filter: hierarchy.region || null,
      province_filter: hierarchy.province || null,
      municipality_filter: hierarchy.municipality || null,
      start_date: options.dateRange?.start || null,
      end_date: options.dateRange?.end || null,
      metric_type: options.metric || 'sales',
      min_threshold: options.minThreshold || 0,
      search_term: filters.search || null,
      sort_by: filters.sortBy || 'name',
      sort_order: filters.sortOrder || 'asc',
      has_data_only: filters.hasDataOnly || false,
    });

    if (error) {
      console.error('Geographic drilldown RPC error:', error);
      throw new Error(`Failed to fetch ${level} data: ${error.message}`);
    }

    return (data || []).map((item: any) => ({
      id: item.id,
      name: item.name,
      code: item.code,
      level: level,
      parent_id: item.parent_id,
      parent_name: item.parent_name,
      children_count: item.children_count || 0,
      has_data: item.has_data || false,
      coordinates: item.latitude && item.longitude ? [item.longitude, item.latitude] : undefined,
      bounds: item.bounds ? JSON.parse(item.bounds) : undefined,
      metadata: {
        population: item.population,
        area_sqkm: item.area_sqkm,
        total_stores: item.total_stores,
        total_sales: item.total_sales,
        total_customers: item.total_customers,
        last_updated: item.last_updated,
      },
    }));
  } catch (error) {
    console.error('Error in fetchDrilldownData:', error);
    throw error;
  }
};

/**
 * Determine the next drilldown level
 */
const getNextLevel = (currentLevel: GeographicLevel): GeographicLevel | null => {
  const levelOrder: GeographicLevel[] = ['region', 'province', 'municipality', 'barangay'];
  const currentIndex = levelOrder.indexOf(currentLevel);
  return currentIndex < levelOrder.length - 1 ? levelOrder[currentIndex + 1] : null;
};

/**
 * Determine the previous drilldown level
 */
const getPreviousLevel = (currentLevel: GeographicLevel): GeographicLevel | null => {
  const levelOrder: GeographicLevel[] = ['region', 'province', 'municipality', 'barangay'];
  const currentIndex = levelOrder.indexOf(currentLevel);
  return currentIndex > 0 ? levelOrder[currentIndex - 1] : null;
};

/**
 * Build breadcrumb navigation from hierarchy
 */
const buildBreadcrumb = (
  level: GeographicLevel,
  hierarchy: GeographicHierarchy
): Array<{ level: GeographicLevel; name: string; hierarchy: GeographicHierarchy }> => {
  const breadcrumb = [];

  if (hierarchy.region) {
    breadcrumb.push({
      level: 'region' as GeographicLevel,
      name: hierarchy.region,
      hierarchy: { region: hierarchy.region },
    });
  }

  if (hierarchy.province && level !== 'region') {
    breadcrumb.push({
      level: 'province' as GeographicLevel,
      name: hierarchy.province,
      hierarchy: { region: hierarchy.region, province: hierarchy.province },
    });
  }

  if (hierarchy.municipality && ['municipality', 'barangay'].includes(level)) {
    breadcrumb.push({
      level: 'municipality' as GeographicLevel,
      name: hierarchy.municipality,
      hierarchy: {
        region: hierarchy.region,
        province: hierarchy.province,
        municipality: hierarchy.municipality,
      },
    });
  }

  if (hierarchy.barangay && level === 'barangay') {
    breadcrumb.push({
      level: 'barangay' as GeographicLevel,
      name: hierarchy.barangay,
      hierarchy: hierarchy,
    });
  }

  return breadcrumb;
};

/**
 * Hook for geographic drilldown functionality
 */
export const useGeoDrilldown = (
  initialLevel: GeographicLevel = 'region',
  initialHierarchy: GeographicHierarchy = { region: '' },
  options: DrilldownOptions = {}
) => {
  const [state, setState] = useState<{
    level: GeographicLevel;
    hierarchy: GeographicHierarchy;
    filters: DrilldownFilters;
  }>({
    level: initialLevel,
    hierarchy: initialHierarchy,
    filters: {},
  });

  // Query for current level data
  const {
    data: currentNodes = [],
    isLoading,
    error,
    refetch,
  } = useQuery<DrilldownNode[], Error>({
    queryKey: [
      'geo-drilldown',
      state.level,
      state.hierarchy,
      options.dateRange?.start,
      options.dateRange?.end,
      options.metric,
      options.minThreshold,
      state.filters,
    ],
    queryFn: () => fetchDrilldownData(state.level, state.hierarchy, options, state.filters),
    enabled: options.enabled !== false,
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 15 * 60 * 1000, // 15 minutes
  });

  // Build current state
  const drilldownState: DrilldownState = useMemo(() => {
    const breadcrumb = buildBreadcrumb(state.level, state.hierarchy);
    const nextLevel = getNextLevel(state.level);
    const canDrillDown = nextLevel !== null && currentNodes.some(node => node.children_count > 0);
    const canDrillUp = breadcrumb.length > 0;

    return {
      level: state.level,
      hierarchy: state.hierarchy,
      breadcrumb,
      currentNodes,
      selectedNode: undefined,
      canDrillDown,
      canDrillUp,
    };
  }, [state.level, state.hierarchy, currentNodes]);

  /**
   * Drill down to a specific node
   */
  const drillDown = useCallback(
    (node: DrilldownNode) => {
      const nextLevel = getNextLevel(state.level);
      if (!nextLevel || node.children_count === 0) return;

      const newHierarchy: GeographicHierarchy = { ...state.hierarchy };

      // Update hierarchy based on the selected node
      switch (nextLevel) {
        case 'province':
          newHierarchy.province = node.name;
          break;
        case 'municipality':
          newHierarchy.municipality = node.name;
          break;
        case 'barangay':
          newHierarchy.barangay = node.name;
          break;
      }

      setState(prev => ({
        ...prev,
        level: nextLevel,
        hierarchy: newHierarchy,
        filters: { ...prev.filters }, // Reset some filters if needed
      }));
    },
    [state.level, state.hierarchy]
  );

  /**
   * Drill up to parent level
   */
  const drillUp = useCallback(() => {
    const previousLevel = getPreviousLevel(state.level);
    if (!previousLevel) return;

    const newHierarchy: GeographicHierarchy = { ...state.hierarchy };

    // Remove the current level from hierarchy
    switch (state.level) {
      case 'barangay':
        delete newHierarchy.barangay;
        break;
      case 'municipality':
        delete newHierarchy.municipality;
        break;
      case 'province':
        delete newHierarchy.province;
        break;
    }

    setState(prev => ({
      ...prev,
      level: previousLevel,
      hierarchy: newHierarchy,
    }));
  }, [state.level, state.hierarchy]);

  /**
   * Navigate to a specific breadcrumb level
   */
  const navigateToLevel = useCallback((targetHierarchy: GeographicHierarchy, level: GeographicLevel) => {
    setState(prev => ({
      ...prev,
      level,
      hierarchy: targetHierarchy,
    }));
  }, []);

  /**
   * Reset to initial state
   */
  const reset = useCallback(() => {
    setState({
      level: initialLevel,
      hierarchy: initialHierarchy,
      filters: {},
    });
  }, [initialLevel, initialHierarchy]);

  /**
   * Update filters
   */
  const updateFilters = useCallback((newFilters: Partial<DrilldownFilters>) => {
    setState(prev => ({
      ...prev,
      filters: { ...prev.filters, ...newFilters },
    }));
  }, []);

  /**
   * Get node statistics
   */
  const getStatistics = useCallback(() => {
    const totalNodes = currentNodes.length;
    const nodesWithData = currentNodes.filter(node => node.has_data).length;
    const totalPopulation = currentNodes.reduce((sum, node) => sum + (node.metadata.population || 0), 0);
    const totalStores = currentNodes.reduce((sum, node) => sum + (node.metadata.total_stores || 0), 0);
    const totalSales = currentNodes.reduce((sum, node) => sum + (node.metadata.total_sales || 0), 0);

    return {
      totalNodes,
      nodesWithData,
      dataPercentage: totalNodes > 0 ? (nodesWithData / totalNodes) * 100 : 0,
      totalPopulation,
      totalStores,
      totalSales,
      averageStoresPerNode: totalNodes > 0 ? totalStores / totalNodes : 0,
      averageSalesPerNode: totalNodes > 0 ? totalSales / totalNodes : 0,
    };
  }, [currentNodes]);

  return {
    // State
    ...drilldownState,
    isLoading,
    error,

    // Actions
    drillDown,
    drillUp,
    navigateToLevel,
    reset,
    updateFilters,
    refetch,

    // Computed values
    statistics: getStatistics(),
    filters: state.filters,

    // Utilities
    getNextLevel: () => getNextLevel(state.level),
    getPreviousLevel: () => getPreviousLevel(state.level),
    canNavigateToLevel: (level: GeographicLevel) => {
      const levelOrder: GeographicLevel[] = ['region', 'province', 'municipality', 'barangay'];
      const currentIndex = levelOrder.indexOf(state.level);
      const targetIndex = levelOrder.indexOf(level);
      return targetIndex >= 0 && targetIndex <= currentIndex;
    },
  };
};

/**
 * Hook to get available regions for initial selection
 */
export const useAvailableRegions = (options: Partial<DrilldownOptions> = {}) => {
  return useQuery<DrilldownNode[], Error>({
    queryKey: ['available-regions', options.metric, options.minThreshold],
    queryFn: () => fetchDrilldownData('region', { region: '' }, options),
    staleTime: 30 * 60 * 1000, // 30 minutes (regions don't change often)
    gcTime: 60 * 60 * 1000, // 60 minutes
  });
};

export default useGeoDrilldown;