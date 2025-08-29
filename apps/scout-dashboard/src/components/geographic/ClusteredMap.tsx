import React, { useEffect, useRef, useState } from 'react';
import mapboxgl from 'mapbox-gl';
import { useMapbox } from './MapboxProvider';
import { useGeographicData } from '@/hooks/useGeographicData';
import { useTileOptimization } from '@/hooks/useTileOptimization';
import { MAPBOX_CONFIG, LAYER_STYLES, COLOR_SCHEMES, mapUtils } from '@/lib/mapbox';
import { TileOptimizationConfig } from '@/lib/mapbox/tileOptimization';
import { cn } from '@/lib/utils';

interface ClusteredMapProps {
  className?: string;
  region?: string;
  province?: string;
  municipality?: string;
  metric?: 'sales' | 'customers' | 'visits' | 'revenue';
  dateRange?: {
    start: string;
    end: string;
  };
  onClusterClick?: (clusterId: string, pointCount: number) => void;
  onPointClick?: (pointId: string, data: any) => void;
  enableTileOptimization?: boolean;
  tileOptimizationConfig?: TileOptimizationConfig;
}

interface ClusterPopupProps {
  cluster: any;
  onClose: () => void;
}

const ClusterPopup: React.FC<ClusterPopupProps> = ({ cluster, onClose }) => (
  <div className="bg-white rounded-lg shadow-lg border p-4 min-w-64">
    <div className="flex justify-between items-start mb-3">
      <h3 className="font-semibold text-gray-900">Cluster Details</h3>
      <button
        onClick={onClose}
        className="text-gray-400 hover:text-gray-600"
        aria-label="Close popup"
      >
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
    
    <div className="space-y-2 text-sm">
      <div className="flex justify-between">
        <span className="text-gray-600">Data Points:</span>
        <span className="font-medium">{cluster.point_count?.toLocaleString() || 0}</span>
      </div>
      <div className="flex justify-between">
        <span className="text-gray-600">Total Value:</span>
        <span className="font-medium">{cluster.total_value?.toLocaleString() || 0}</span>
      </div>
      <div className="flex justify-between">
        <span className="text-gray-600">Average:</span>
        <span className="font-medium">{cluster.average_value?.toFixed(2) || 0}</span>
      </div>
      <div className="flex justify-between">
        <span className="text-gray-600">Coverage:</span>
        <span className="font-medium">{cluster.coverage || 'Regional'}</span>
      </div>
    </div>
    
    <button
      onClick={() => onClose()}
      className="mt-4 w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 transition-colors"
    >
      Zoom to Cluster
    </button>
  </div>
);

export const ClusteredMap: React.FC<ClusteredMapProps> = ({
  className,
  region,
  province,
  municipality,
  metric = 'sales',
  dateRange,
  onClusterClick,
  onPointClick,
  enableTileOptimization = true,
  tileOptimizationConfig = {},
}) => {
  const { map } = useMapbox();
  const popupRef = useRef<mapboxgl.Popup | null>(null);
  const [selectedCluster, setSelectedCluster] = useState<any>(null);
  const mapContainerRef = useRef<HTMLDivElement>(null);

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
      autoOptimize: enableTileOptimization,
      showLoadingIndicator: true,
      optimizeForMobile: true, // Clustering is more intensive, so optimize for mobile
    }
  );

  // Fetch geographic data with clustering enabled
  const { data: geographicData, isLoading, error } = useGeographicData({
    region,
    province,
    municipality,
    dateRange,
    metric,
    clustered: true,
    enabled: !!map,
  });

  // Setup clustering layers
  useEffect(() => {
    if (!map || !geographicData || geographicData.length === 0) return;

    const sourceId = 'clustered-points';
    const clusterLayerId = 'clusters';
    const clusterCountLayerId = 'cluster-count';
    const unclusteredPointLayerId = 'unclustered-point';

    // Remove existing layers and source
    const cleanup = () => {
      if (map.getLayer(clusterCountLayerId)) map.removeLayer(clusterCountLayerId);
      if (map.getLayer(clusterLayerId)) map.removeLayer(clusterLayerId);
      if (map.getLayer(unclusteredPointLayerId)) map.removeLayer(unclusteredPointLayerId);
      if (map.getSource(sourceId)) map.removeSource(sourceId);
    };

    cleanup();

    // Create GeoJSON from data
    const geojsonData: GeoJSON.FeatureCollection = {
      type: 'FeatureCollection',
      features: geographicData.map(point => ({
        type: 'Feature',
        properties: {
          id: point.id,
          barangay: point.barangay,
          municipality: point.municipality,
          province: point.province,
          region: point.region,
          value: point.value,
          metadata: point.metadata,
        },
        geometry: {
          type: 'Point',
          coordinates: [point.longitude, point.latitude],
        },
      })),
    };

    // Add source with clustering
    map.addSource(sourceId, {
      type: 'geojson',
      data: geojsonData,
      cluster: true,
      clusterMaxZoom: 14,
      clusterRadius: 50,
      clusterProperties: {
        total_value: ['+', ['get', 'value']],
        max_value: ['max', ['get', 'value']],
        min_value: ['min', ['get', 'value']],
      },
    });

    // Add cluster circles
    map.addLayer({
      id: clusterLayerId,
      type: 'circle',
      source: sourceId,
      filter: ['has', 'point_count'],
      paint: {
        'circle-color': [
          'step',
          ['get', 'point_count'],
          COLOR_SCHEMES.SALES_HEATMAP[2], // Blue for small clusters
          100,
          COLOR_SCHEMES.SALES_HEATMAP[4], // Orange for medium clusters
          750,
          COLOR_SCHEMES.SALES_HEATMAP[6], // Red for large clusters
        ],
        'circle-radius': [
          'step',
          ['get', 'point_count'],
          20, // Small clusters
          100,
          30, // Medium clusters
          750,
          40, // Large clusters
        ],
        'circle-stroke-width': 2,
        'circle-stroke-color': '#ffffff',
        'circle-opacity': 0.8,
      },
    });

    // Add cluster count labels
    map.addLayer({
      id: clusterCountLayerId,
      type: 'symbol',
      source: sourceId,
      filter: ['has', 'point_count'],
      layout: {
        'text-field': '{point_count_abbreviated}',
        'text-font': ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'],
        'text-size': 12,
      },
      paint: {
        'text-color': '#ffffff',
        'text-halo-color': 'rgba(0,0,0,0.5)',
        'text-halo-width': 1,
      },
    });

    // Add unclustered points
    map.addLayer({
      id: unclusteredPointLayerId,
      type: 'circle',
      source: sourceId,
      filter: ['!', ['has', 'point_count']],
      paint: {
        'circle-color': [
          'interpolate',
          ['linear'],
          ['get', 'value'],
          0, COLOR_SCHEMES.SALES_HEATMAP[0],
          1000, COLOR_SCHEMES.SALES_HEATMAP[7],
        ],
        'circle-radius': [
          'interpolate',
          ['linear'],
          ['zoom'],
          6, 6,
          14, 12
        ],
        'circle-stroke-color': '#ffffff',
        'circle-stroke-width': 1,
        'circle-opacity': 0.8,
      },
    });

    // Cluster click handler
    const handleClusterClick = (e: mapboxgl.MapMouseEvent) => {
      const features = map.queryRenderedFeatures(e.point, {
        layers: [clusterLayerId],
      });

      if (!features.length) return;

      const clusterId = features[0].properties!.cluster_id;
      const pointCount = features[0].properties!.point_count;
      const clusterSource = map.getSource(sourceId) as mapboxgl.GeoJSONSource;

      // Get cluster expansion zoom
      clusterSource.getClusterExpansionZoom(clusterId, (err, zoom) => {
        if (err) return;

        map.easeTo({
          center: (features[0].geometry as GeoJSON.Point).coordinates as [number, number],
          zoom: zoom,
          duration: 500,
        });
      });

      // Show cluster popup
      if (popupRef.current) {
        popupRef.current.remove();
      }

      const coordinates = (features[0].geometry as GeoJSON.Point).coordinates as [number, number];
      const clusterData = {
        point_count: pointCount,
        total_value: features[0].properties!.total_value,
        average_value: features[0].properties!.total_value / pointCount,
        coverage: 'Regional',
      };

      setSelectedCluster(clusterData);

      popupRef.current = new mapboxgl.Popup({ offset: 25 })
        .setLngLat(coordinates)
        .setHTML('<div id="cluster-popup-container"></div>')
        .addTo(map);

      onClusterClick?.(clusterId, pointCount);
    };

    // Point click handler
    const handlePointClick = (e: mapboxgl.MapMouseEvent) => {
      const features = map.queryRenderedFeatures(e.point, {
        layers: [unclusteredPointLayerId],
      });

      if (!features.length) return;

      const point = features[0];
      const coordinates = (point.geometry as GeoJSON.Point).coordinates as [number, number];
      const properties = point.properties!;

      // Show point popup
      if (popupRef.current) {
        popupRef.current.remove();
      }

      const popupContent = `
        <div class="p-2">
          <h4 class="font-semibold text-sm mb-2">${properties.barangay}</h4>
          <div class="text-xs space-y-1">
            <div><span class="text-gray-600">Municipality:</span> ${properties.municipality}</div>
            <div><span class="text-gray-600">Province:</span> ${properties.province}</div>
            <div><span class="text-gray-600">Value:</span> ${properties.value.toLocaleString()}</div>
          </div>
        </div>
      `;

      popupRef.current = new mapboxgl.Popup({ offset: 25 })
        .setLngLat(coordinates)
        .setHTML(popupContent)
        .addTo(map);

      onPointClick?.(properties.id, properties);
    };

    // Mouse cursor changes
    const handleMouseEnter = () => {
      map.getCanvas().style.cursor = 'pointer';
    };

    const handleMouseLeave = () => {
      map.getCanvas().style.cursor = '';
    };

    // Add event listeners
    map.on('click', clusterLayerId, handleClusterClick);
    map.on('click', unclusteredPointLayerId, handlePointClick);
    map.on('mouseenter', clusterLayerId, handleMouseEnter);
    map.on('mouseleave', clusterLayerId, handleMouseLeave);
    map.on('mouseenter', unclusteredPointLayerId, handleMouseEnter);
    map.on('mouseleave', unclusteredPointLayerId, handleMouseLeave);

    // Cleanup function
    return () => {
      map.off('click', clusterLayerId, handleClusterClick);
      map.off('click', unclusteredPointLayerId, handlePointClick);
      map.off('mouseenter', clusterLayerId, handleMouseEnter);
      map.off('mouseleave', clusterLayerId, handleMouseLeave);
      map.off('mouseenter', unclusteredPointLayerId, handleMouseEnter);
      map.off('mouseleave', unclusteredPointLayerId, handleMouseLeave);
      
      if (popupRef.current) {
        popupRef.current.remove();
        popupRef.current = null;
      }
      
      cleanup();
    };
  }, [map, geographicData, onClusterClick, onPointClick]);

  // Auto-fit to data bounds
  useEffect(() => {
    if (!map || !geographicData || geographicData.length === 0) return;

    const coordinates = geographicData.map(point => [point.longitude, point.latitude] as [number, number]);
    const bounds = mapUtils.createBounds(coordinates);

    map.fitBounds(bounds, {
      padding: 50,
      maxZoom: 12,
      duration: 1000,
    });
  }, [map, geographicData]);

  if (error) {
    return (
      <div className={cn("flex items-center justify-center bg-red-50 border border-red-200 rounded-lg", className)}>
        <div className="text-center p-6">
          <div className="w-12 h-12 mx-auto mb-4 text-red-400">
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <h3 className="text-lg font-medium text-red-800 mb-2">Map Data Error</h3>
          <p className="text-sm text-red-600">{error.message}</p>
        </div>
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className={cn("relative bg-gray-100 rounded-lg overflow-hidden", className)}>
        <div className="animate-pulse bg-gray-200 w-full h-full"></div>
        <div className="absolute inset-0 flex items-center justify-center">
          <div className="bg-white rounded-lg p-4 shadow-lg">
            <div className="flex items-center space-x-2">
              <div className="w-4 h-4 bg-blue-600 rounded-full animate-pulse"></div>
              <span className="text-sm font-medium text-gray-700">Loading geographic data...</span>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div ref={mapContainerRef} className={cn("relative", className)}>
      {/* Map container will be rendered by GeographicMap */}
      <div className="w-full h-full" />
      
      {/* Legend */}
      <div className="absolute top-4 left-4 bg-white bg-opacity-90 rounded-lg shadow-lg p-3">
        <h4 className="font-semibold text-sm mb-2">Data Clusters</h4>
        <div className="space-y-1 text-xs">
          <div className="flex items-center space-x-2">
            <div className="w-3 h-3 rounded-full" style={{ backgroundColor: COLOR_SCHEMES.SALES_HEATMAP[2] }}></div>
            <span>1-99 points</span>
          </div>
          <div className="flex items-center space-x-2">
            <div className="w-3 h-3 rounded-full" style={{ backgroundColor: COLOR_SCHEMES.SALES_HEATMAP[4] }}></div>
            <span>100-749 points</span>
          </div>
          <div className="flex items-center space-x-2">
            <div className="w-3 h-3 rounded-full" style={{ backgroundColor: COLOR_SCHEMES.SALES_HEATMAP[6] }}></div>
            <span>750+ points</span>
          </div>
        </div>
      </div>

      {/* Data summary with tile optimization status */}
      <div className="absolute bottom-4 left-4 bg-white bg-opacity-90 rounded-lg shadow-lg p-3">
        <div className="text-xs text-gray-600">
          <div>Total Data Points: {geographicData?.length.toLocaleString() || 0}</div>
          <div>Metric: {metric.charAt(0).toUpperCase() + metric.slice(1)}</div>
          {region && <div>Region: {region}</div>}
          {province && <div>Province: {province}</div>}
          
          {/* Tile optimization status */}
          {enableTileOptimization && isOptimized && (
            <div className="flex items-center space-x-1 mt-2 pt-2 border-t border-gray-200">
              <div className="w-2 h-2 bg-green-500 rounded-full"></div>
              <span className="text-green-600">Tiles Optimized</span>
              {performanceMetrics && (
                <span className="text-gray-500">
                  ({performanceMetrics.cacheEfficiency.toFixed(0)}% efficiency)
                </span>
              )}
            </div>
          )}
          
          {tileLoadingState.loading && (
            <div className="flex items-center space-x-1 mt-2 pt-2 border-t border-gray-200">
              <div className="w-2 h-2 bg-blue-500 rounded-full animate-pulse"></div>
              <span className="text-blue-600">Loading tiles... {Math.round(tileLoadingState.progress)}%</span>
            </div>
          )}
          
          {tileErrors.length > 0 && (
            <div className="flex items-center space-x-1 mt-2 pt-2 border-t border-gray-200 text-orange-600">
              <div className="w-2 h-2 bg-orange-500 rounded-full"></div>
              <span>{tileErrors.length} tile error{tileErrors.length !== 1 ? 's' : ''}</span>
            </div>
          )}
        </div>
      </div>

      {/* Performance controls (development only) */}
      {process.env.NODE_ENV === 'development' && performanceMetrics && (
        <div className="absolute bottom-4 right-4 bg-black bg-opacity-75 text-white text-xs p-2 rounded">
          <div>Cache Performance: {performanceMetrics.cacheEfficiency.toFixed(1)}%</div>
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

export default ClusteredMap;