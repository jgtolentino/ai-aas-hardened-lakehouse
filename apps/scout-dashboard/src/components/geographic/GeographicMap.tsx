import React, { useRef, useEffect, useState } from 'react';
import { useMapbox } from './MapboxProvider';
import { MapControls } from './MapControls';
import { MapLegend, LegendType } from './MapLegend';
import { useTileOptimization } from '@/hooks/useTileOptimization';
import { TileOptimizationConfig } from '@/lib/mapbox/tileOptimization';
import { cn } from '@/lib/utils';

interface GeographicMapProps {
  className?: string;
  onMapClick?: (coordinates: [number, number]) => void;
  onMapLoad?: () => void;
  initialCenter?: [number, number];
  initialZoom?: number;
  style?: string;
  showControls?: boolean;
  showLegend?: boolean;
  legendType?: LegendType;
  metric?: 'sales' | 'customers' | 'visits' | 'revenue';
  controlsPosition?: 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right';
  legendPosition?: 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right';
  enableTileOptimization?: boolean;
  tileOptimizationConfig?: TileOptimizationConfig;
  showTileLoadingIndicator?: boolean;
  onTileLoadingStateChange?: (loading: boolean, progress: number) => void;
}

interface MapLoadingSkeletonProps {
  className?: string;
}

const MapLoadingSkeleton: React.FC<MapLoadingSkeletonProps> = ({ className }) => (
  <div className={cn("relative bg-gray-100 rounded-lg overflow-hidden", className)}>
    <div className="animate-pulse bg-gray-200 w-full h-full"></div>
    <div className="absolute inset-0 flex items-center justify-center">
      <div className="bg-white rounded-lg p-4 shadow-lg">
        <div className="flex items-center space-x-2">
          <div className="w-4 h-4 bg-blue-600 rounded-full animate-pulse"></div>
          <span className="text-sm font-medium text-gray-700">Loading map...</span>
        </div>
      </div>
    </div>
  </div>
);

const MapErrorDisplay: React.FC<{ error: string; className?: string }> = ({ error, className }) => (
  <div className={cn("relative bg-red-50 border border-red-200 rounded-lg", className)}>
    <div className="flex items-center justify-center h-full">
      <div className="text-center p-6">
        <div className="w-12 h-12 mx-auto mb-4 text-red-400">
          <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </div>
        <h3 className="text-lg font-medium text-red-800 mb-2">Map Loading Error</h3>
        <p className="text-sm text-red-600 mb-4">{error}</p>
        <button 
          onClick={() => window.location.reload()} 
          className="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 transition-colors"
        >
          Reload Map
        </button>
      </div>
    </div>
  </div>
);

export const GeographicMap: React.FC<GeographicMapProps> = ({
  className,
  onMapClick,
  onMapLoad,
  initialCenter = [121.0244, 14.6507], // Manila, Philippines
  initialZoom = 6,
  style = 'mapbox://styles/mapbox/light-v11',
  showControls = true,
  showLegend = false,
  legendType = 'heatmap',
  metric = 'sales',
  controlsPosition = 'top-right',
  legendPosition = 'bottom-left',
  enableTileOptimization = true,
  tileOptimizationConfig = {},
  showTileLoadingIndicator = true,
  onTileLoadingStateChange,
}) => {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const { map, isLoading, error, initializeMap } = useMapbox();
  const [isMapReady, setIsMapReady] = useState(false);

  // Use tile optimization hook
  const {
    loadingState: tileLoadingState,
    performanceMetrics,
    clearCache,
    isOptimized,
    errors: tileErrors,
  } = useTileOptimization(
    map,
    mapContainerRef,
    {
      ...tileOptimizationConfig,
      showLoadingIndicator: showTileLoadingIndicator,
      autoOptimize: enableTileOptimization,
    }
  );

  useEffect(() => {
    if (mapContainerRef.current && !map) {
      initializeMap(mapContainerRef.current, {
        center: initialCenter,
        zoom: initialZoom,
        style,
        tileOptimization: enableTileOptimization ? tileOptimizationConfig : undefined,
      });
    }
  }, [map, initializeMap, initialCenter, initialZoom, style, enableTileOptimization, tileOptimizationConfig]);

  // Notify parent component of tile loading state changes
  useEffect(() => {
    if (onTileLoadingStateChange) {
      onTileLoadingStateChange(tileLoadingState.loading, tileLoadingState.progress);
    }
  }, [tileLoadingState.loading, tileLoadingState.progress, onTileLoadingStateChange]);

  useEffect(() => {
    if (map) {
      const handleLoad = () => {
        setIsMapReady(true);
        onMapLoad?.();
      };

      const handleClick = (e: mapboxgl.MapMouseEvent) => {
        if (onMapClick) {
          const { lng, lat } = e.lngLat;
          onMapClick([lng, lat]);
        }
      };

      if (map.isStyleLoaded()) {
        handleLoad();
      } else {
        map.on('load', handleLoad);
      }

      map.on('click', handleClick);

      return () => {
        map.off('load', handleLoad);
        map.off('click', handleClick);
      };
    }
  }, [map, onMapClick, onMapLoad]);

  // Show error state
  if (error) {
    return <MapErrorDisplay error={error} className={className} />;
  }

  // Show loading state
  if (isLoading || !isMapReady) {
    return <MapLoadingSkeleton className={className} />;
  }

  return (
    <div className={cn("relative mapbox-container", className)}>
      <div
        ref={mapContainerRef}
        className="w-full h-full rounded-lg overflow-hidden"
        role="application"
        aria-label="Interactive geographic map"
        tabIndex={0}
      />
      
      {/* Map Controls */}
      {showControls && map && (
        <MapControls 
          position={controlsPosition}
          showFullscreen={true}
          showResetView={true}
        />
      )}
      
      {/* Map Legend */}
      {showLegend && map && (
        <MapLegend
          type={legendType}
          metric={metric}
          position={legendPosition}
          collapsible={true}
          showDataInfo={true}
        />
      )}
      
      {/* Map attribution and status */}
      <div className="absolute bottom-2 left-2 bg-white bg-opacity-90 rounded px-2 py-1 text-xs text-gray-600">
        <div>Scout Geographic Intelligence</div>
        {enableTileOptimization && isOptimized && (
          <div className="flex items-center space-x-1 mt-1">
            <div className="w-2 h-2 bg-green-500 rounded-full"></div>
            <span>Optimized</span>
            {performanceMetrics && (
              <span className="text-gray-500">
                ({performanceMetrics.cacheEfficiency.toFixed(1)}% cache efficiency)
              </span>
            )}
          </div>
        )}
        {tileErrors.length > 0 && (
          <div className="flex items-center space-x-1 mt-1 text-orange-600">
            <div className="w-2 h-2 bg-orange-500 rounded-full"></div>
            <span>{tileErrors.length} tile error{tileErrors.length !== 1 ? 's' : ''}</span>
          </div>
        )}
      </div>

      {/* Performance debug panel (only in development) */}
      {process.env.NODE_ENV === 'development' && performanceMetrics && (
        <div className="absolute top-2 left-2 bg-black bg-opacity-75 text-white text-xs p-2 rounded">
          <div>Tiles Loaded: {performanceMetrics.tilesLoaded}</div>
          <div>Cache Efficiency: {performanceMetrics.cacheEfficiency.toFixed(1)}%</div>
          <div>Errors: {performanceMetrics.errorCount}</div>
          <button
            onClick={clearCache}
            className="mt-1 px-2 py-1 bg-blue-600 text-white rounded text-xs hover:bg-blue-700"
          >
            Clear Cache
          </button>
        </div>
      )}
    </div>
  );
};

export default GeographicMap;