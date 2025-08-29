import React, { createContext, useContext, useEffect, useState, useRef } from 'react';
import mapboxgl from 'mapbox-gl';
import { TileOptimizer, TileOptimizationConfig } from '@/lib/mapbox/tileOptimization';
import { useTileOptimization } from '@/hooks/useTileOptimization';

// Mapbox CSS import
import 'mapbox-gl/dist/mapbox-gl.css';

interface MapboxContextType {
  map: mapboxgl.Map | null;
  isLoading: boolean;
  error: string | null;
  initialCenter?: [number, number];
  initialZoom?: number;
  tileOptimizer: TileOptimizer | null;
  initializeMap: (container: HTMLDivElement, options?: Partial<mapboxgl.MapboxOptions & { tileOptimization?: TileOptimizationConfig }>) => void;
}

const MapboxContext = createContext<MapboxContextType | null>(null);

interface MapboxProviderProps {
  children: React.ReactNode;
  apiKey?: string;
  enableTileOptimization?: boolean;
  tileOptimizationConfig?: TileOptimizationConfig;
}

export const MapboxProvider: React.FC<MapboxProviderProps> = ({ 
  children, 
  apiKey = process.env.NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN,
  enableTileOptimization = true,
  tileOptimizationConfig = {}
}) => {
  const [map, setMap] = useState<mapboxgl.Map | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [initialCenter, setInitialCenter] = useState<[number, number]>();
  const [initialZoom, setInitialZoom] = useState<number>();
  const [tileOptimizer, setTileOptimizer] = useState<TileOptimizer | null>(null);
  const containerRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    // Set Mapbox access token
    if (apiKey) {
      mapboxgl.accessToken = apiKey;
    } else {
      setError('Mapbox API key not found. Please set NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN environment variable.');
    }
  }, [apiKey]);

  const initializeMap = (container: HTMLDivElement, options: Partial<mapboxgl.MapboxOptions & { tileOptimization?: TileOptimizationConfig }> = {}) => {
    if (!apiKey) {
      setError('Cannot initialize map: API key not available');
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      containerRef.current = container;
      
      // Extract tile optimization config from options
      const { tileOptimization, ...mapboxOptions } = options;
      const optimizationConfig = { ...tileOptimizationConfig, ...tileOptimization };

      // Apply tile optimization to style if enabled
      let optimizedStyle = 'mapbox://styles/mapbox/light-v11';
      if (enableTileOptimization && optimizationConfig.optimizeForMobile) {
        const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent) || window.innerWidth < 768;
        if (isMobile && optimizedStyle.includes('satellite')) {
          optimizedStyle = 'mapbox://styles/mapbox/light-v11';
        }
      }

      // Default map configuration optimized for Philippines
      const defaultOptions: mapboxgl.MapboxOptions = {
        container,
        style: mapboxOptions.style || optimizedStyle,
        center: [121.0244, 14.6507], // Manila, Philippines
        zoom: 6,
        minZoom: optimizationConfig.minZoom || 5,
        maxZoom: optimizationConfig.maxZoom || 18,
        attributionControl: true,
        logoPosition: 'bottom-right',
        renderWorldCopies: optimizationConfig.renderWorldCopies ?? false,
        ...mapboxOptions,
      };

      const newMap = new mapboxgl.Map(defaultOptions);

      // Store initial configuration for reset functionality
      setInitialCenter(defaultOptions.center as [number, number]);
      setInitialZoom(defaultOptions.zoom);

      // Initialize tile optimization
      if (enableTileOptimization) {
        const optimizer = new TileOptimizer(newMap, optimizationConfig);
        setTileOptimizer(optimizer);
      }

      // Map load event
      newMap.on('load', () => {
        setIsLoading(false);
        console.log('Mapbox map initialized successfully with tile optimization');
      });

      // Error handling
      newMap.on('error', (e) => {
        console.error('Mapbox error:', e);
        setError(`Map error: ${e.error.message}`);
        setIsLoading(false);
      });

      // Resize handling
      newMap.on('resize', () => {
        newMap.resize();
      });

      setMap(newMap);
    } catch (err) {
      console.error('Failed to initialize map:', err);
      setError(err instanceof Error ? err.message : 'Failed to initialize map');
      setIsLoading(false);
    }
  };

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (tileOptimizer) {
        tileOptimizer.dispose();
      }
      if (map) {
        map.remove();
      }
    };
  }, [map, tileOptimizer]);

  return (
    <MapboxContext.Provider value={{ map, isLoading, error, initialCenter, initialZoom, tileOptimizer, initializeMap }}>
      {children}
    </MapboxContext.Provider>
  );
};

export const useMapbox = (): MapboxContextType => {
  const context = useContext(MapboxContext);
  if (!context) {
    throw new Error('useMapbox must be used within a MapboxProvider');
  }
  return context;
};

export default MapboxProvider;