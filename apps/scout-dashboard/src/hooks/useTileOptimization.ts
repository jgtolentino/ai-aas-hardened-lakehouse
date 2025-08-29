import { useEffect, useRef, useState, useCallback } from 'react';
import mapboxgl from 'mapbox-gl';
import { 
  TileOptimizer, 
  TileOptimizationConfig, 
  TileLoadingState,
  createTileLoadingIndicator 
} from '@/lib/mapbox/tileOptimization';

interface UseTileOptimizationOptions extends TileOptimizationConfig {
  showLoadingIndicator?: boolean;
  enablePerformanceMonitoring?: boolean;
  autoOptimize?: boolean;
}

interface TileOptimizationHook {
  loadingState: TileLoadingState;
  performanceMetrics: {
    tilesLoaded: number;
    totalTiles: number;
    errorCount: number;
    cacheEfficiency: number;
  } | null;
  clearCache: () => void;
  isOptimized: boolean;
  errors: string[];
}

/**
 * React hook for managing map tile optimization
 */
export const useTileOptimization = (
  map: mapboxgl.Map | null,
  containerRef: React.RefObject<HTMLElement>,
  options: UseTileOptimizationOptions = {}
): TileOptimizationHook => {
  const [loadingState, setLoadingState] = useState<TileLoadingState>({
    loading: false,
    progress: 0,
    errors: [],
    tilesLoaded: 0,
    totalTiles: 0,
  });

  const [performanceMetrics, setPerformanceMetrics] = useState<{
    tilesLoaded: number;
    totalTiles: number;
    errorCount: number;
    cacheEfficiency: number;
  } | null>(null);

  const [isOptimized, setIsOptimized] = useState(false);
  const [errors, setErrors] = useState<string[]>([]);

  const optimizerRef = useRef<TileOptimizer | null>(null);
  const cleanupIndicatorRef = useRef<(() => void) | null>(null);

  const {
    showLoadingIndicator = true,
    enablePerformanceMonitoring = true,
    autoOptimize = true,
    ...optimizationConfig
  } = options;

  // Initialize tile optimization
  useEffect(() => {
    if (!map || !autoOptimize) return;

    try {
      // Create tile optimizer
      optimizerRef.current = new TileOptimizer(map, optimizationConfig);
      
      // Set up loading state monitoring
      const handleLoadingStateChange = (state: TileLoadingState) => {
        setLoadingState(state);
        setErrors(state.errors);
      };

      optimizerRef.current.onLoadingStateChange(handleLoadingStateChange);

      // Set up loading indicator
      if (showLoadingIndicator && containerRef.current) {
        cleanupIndicatorRef.current = createTileLoadingIndicator(
          containerRef.current,
          optimizerRef.current
        );
      }

      setIsOptimized(true);

      // Performance monitoring
      if (enablePerformanceMonitoring) {
        const updateMetrics = () => {
          if (optimizerRef.current) {
            setPerformanceMetrics(optimizerRef.current.getPerformanceMetrics());
          }
        };

        // Update metrics periodically
        const metricsInterval = setInterval(updateMetrics, 2000);
        updateMetrics(); // Initial update

        return () => {
          clearInterval(metricsInterval);
        };
      }
    } catch (error) {
      console.error('Failed to initialize tile optimization:', error);
      setErrors(prev => [...prev, `Initialization failed: ${error instanceof Error ? error.message : 'Unknown error'}`]);
      setIsOptimized(false);
    }

    return () => {
      // Cleanup
      if (optimizerRef.current) {
        optimizerRef.current.dispose();
        optimizerRef.current = null;
      }
      
      if (cleanupIndicatorRef.current) {
        cleanupIndicatorRef.current();
        cleanupIndicatorRef.current = null;
      }
      
      setIsOptimized(false);
    };
  }, [map, autoOptimize, showLoadingIndicator, enablePerformanceMonitoring, containerRef]);

  // Clear tile cache
  const clearCache = useCallback(() => {
    if (optimizerRef.current) {
      try {
        optimizerRef.current.clearTileCache();
        setErrors(prev => prev.filter(error => !error.includes('cache')));
      } catch (error) {
        console.error('Failed to clear tile cache:', error);
        setErrors(prev => [...prev, `Cache clear failed: ${error instanceof Error ? error.message : 'Unknown error'}`]);
      }
    }
  }, []);

  return {
    loadingState,
    performanceMetrics,
    clearCache,
    isOptimized,
    errors,
  };
};

/**
 * Hook for manual tile optimization control
 */
export const useManualTileOptimization = (
  map: mapboxgl.Map | null
): {
  createOptimizer: (config?: TileOptimizationConfig) => TileOptimizer | null;
  destroyOptimizer: (optimizer: TileOptimizer) => void;
  optimizeStyle: (styleUrl: string, config?: TileOptimizationConfig) => string;
} => {
  const createOptimizer = useCallback((config: TileOptimizationConfig = {}) => {
    if (!map) {
      console.warn('Cannot create tile optimizer: map not available');
      return null;
    }

    try {
      return new TileOptimizer(map, config);
    } catch (error) {
      console.error('Failed to create tile optimizer:', error);
      return null;
    }
  }, [map]);

  const destroyOptimizer = useCallback((optimizer: TileOptimizer) => {
    try {
      optimizer.dispose();
    } catch (error) {
      console.error('Failed to destroy tile optimizer:', error);
    }
  }, []);

  const optimizeStyle = useCallback((styleUrl: string, config: TileOptimizationConfig = {}) => {
    if (!map) return styleUrl;

    try {
      const tempOptimizer = new TileOptimizer(map, config);
      const optimizedUrl = tempOptimizer.optimizeMapStyle(styleUrl);
      tempOptimizer.dispose();
      return optimizedUrl;
    } catch (error) {
      console.error('Failed to optimize map style:', error);
      return styleUrl;
    }
  }, [map]);

  return {
    createOptimizer,
    destroyOptimizer,
    optimizeStyle,
  };
};

/**
 * Hook for monitoring tile loading performance across multiple maps
 */
export const useTilePerformanceMonitor = (maps: mapboxgl.Map[]): {
  aggregateMetrics: {
    totalTilesLoaded: number;
    totalErrors: number;
    averageCacheEfficiency: number;
    overallHealthScore: number;
  };
  individualMetrics: Array<{
    mapId: string;
    tilesLoaded: number;
    errorCount: number;
    cacheEfficiency: number;
    healthScore: number;
  }>;
} => {
  const [aggregateMetrics, setAggregateMetrics] = useState({
    totalTilesLoaded: 0,
    totalErrors: 0,
    averageCacheEfficiency: 0,
    overallHealthScore: 100,
  });

  const [individualMetrics, setIndividualMetrics] = useState<Array<{
    mapId: string;
    tilesLoaded: number;
    errorCount: number;
    cacheEfficiency: number;
    healthScore: number;
  }>>([]);

  const optimizersRef = useRef<Map<string, TileOptimizer>>(new Map());

  useEffect(() => {
    // Clean up existing optimizers
    optimizersRef.current.forEach(optimizer => optimizer.dispose());
    optimizersRef.current.clear();

    // Create optimizers for each map
    maps.forEach((map, index) => {
      const mapId = `map-${index}`;
      const optimizer = new TileOptimizer(map, { enablePerformanceMonitoring: true });
      optimizersRef.current.set(mapId, optimizer);
    });

    // Update metrics periodically
    const updateMetrics = () => {
      const metrics: Array<{
        mapId: string;
        tilesLoaded: number;
        errorCount: number;
        cacheEfficiency: number;
        healthScore: number;
      }> = [];

      let totalTilesLoaded = 0;
      let totalErrors = 0;
      let totalCacheEfficiency = 0;

      optimizersRef.current.forEach((optimizer, mapId) => {
        const perfMetrics = optimizer.getPerformanceMetrics();
        const healthScore = Math.max(0, 100 - (perfMetrics.errorCount * 10));

        metrics.push({
          mapId,
          tilesLoaded: perfMetrics.tilesLoaded,
          errorCount: perfMetrics.errorCount,
          cacheEfficiency: perfMetrics.cacheEfficiency,
          healthScore,
        });

        totalTilesLoaded += perfMetrics.tilesLoaded;
        totalErrors += perfMetrics.errorCount;
        totalCacheEfficiency += perfMetrics.cacheEfficiency;
      });

      const mapCount = optimizersRef.current.size;
      const averageCacheEfficiency = mapCount > 0 ? totalCacheEfficiency / mapCount : 0;
      const overallHealthScore = Math.max(0, 100 - (totalErrors * 5));

      setIndividualMetrics(metrics);
      setAggregateMetrics({
        totalTilesLoaded,
        totalErrors,
        averageCacheEfficiency,
        overallHealthScore,
      });
    };

    // Update immediately and then every 3 seconds
    updateMetrics();
    const interval = setInterval(updateMetrics, 3000);

    return () => {
      clearInterval(interval);
      optimizersRef.current.forEach(optimizer => optimizer.dispose());
      optimizersRef.current.clear();
    };
  }, [maps]);

  return {
    aggregateMetrics,
    individualMetrics,
  };
};