// Regional Sales Choropleth Map Component
// Real geographic visualization with Philippine territories

import React, { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';

// Install required packages:
// npm install leaflet react-leaflet
// npm install @types/leaflet

import { MapContainer, TileLayer, GeoJSON, Marker, Popup, Tooltip } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

interface RegionData {
  region_code: string;
  region_name: string;
  island_group: string;
  center_lat: number;
  center_lng: number;
  metric_value: number;
  metric_label: string;
  color_intensity: number;
  geometry: any;
}

interface StoreCluster {
  cluster_id: string;
  center_lat: number;
  center_lng: number;
  store_count: number;
  total_sales: number;
  dominant_type: string;
}

export const RegionalSalesChoroplethMap: React.FC = () => {
  const [regionData, setRegionData] = useState<RegionData[]>([]);
  const [storeClusters, setStoreClusters] = useState<StoreCluster[]>([]);
  const [selectedMetric, setSelectedMetric] = useState<string>('total_sales');
  const [loading, setLoading] = useState(true);
  const [selectedRegion, setSelectedRegion] = useState<RegionData | null>(null);

  // Philippine map bounds
  const phBounds: L.LatLngBoundsExpression = [
    [4.5, 116.0],  // Southwest corner
    [21.5, 127.0]  // Northeast corner
  ];

  useEffect(() => {
    loadMapData();
  }, [selectedMetric]);

  const loadMapData = async () => {
    setLoading(true);
    try {
      // Get choropleth data
      const { data: choroplethData, error: choroplethError } = await supabase
        .rpc('get_choropleth_data', {
          p_metric: selectedMetric,
          p_date: new Date().toISOString().split('T')[0]
        });

      if (choroplethError) throw choroplethError;
      setRegionData(choroplethData || []);

      // Get store clusters
      const { data: clusterData, error: clusterError } = await supabase
        .rpc('get_store_clusters', {
          p_zoom_level: 10
        });

      if (clusterError) throw clusterError;
      setStoreClusters(clusterData || []);

    } catch (error) {
      console.error('Error loading map data:', error);
    } finally {
      setLoading(false);
    }
  };

  // Get color based on intensity (0-1 scale)
  const getColor = (intensity: number): string => {
    const colors = [
      '#FFF5F0', // 0-10%
      '#FEE0D2', // 10-20%
      '#FCBBA1', // 20-30%
      '#FC9272', // 30-40%
      '#FB6A4A', // 40-50%
      '#EF3B2C', // 50-60%
      '#CB181D', // 60-70%
      '#A50F15', // 70-80%
      '#67000D', // 80-90%
      '#4A0000'  // 90-100%
    ];
    const index = Math.floor(intensity * 9);
    return colors[Math.min(index, colors.length - 1)];
  };

  // Style for each region
  const regionStyle = (feature: any) => {
    const region = regionData.find(r => r.region_code === feature.properties.region_code);
    const intensity = region?.color_intensity || 0;
    
    return {
      fillColor: getColor(intensity),
      weight: 2,
      opacity: 1,
      color: 'white',
      dashArray: '3',
      fillOpacity: 0.7
    };
  };

  // Create custom markers for regions
  const createRegionMarkers = () => {
    return regionData.map((region) => {
      const icon = L.divIcon({
        className: 'custom-region-marker',
        html: `
          <div style="
            background: ${getColor(region.color_intensity)};
            color: white;
            padding: 8px 12px;
            border-radius: 8px;
            font-weight: bold;
            font-size: 12px;
            box-shadow: 0 2px 6px rgba(0,0,0,0.3);
            text-align: center;
            min-width: 80px;
          ">
            <div>${region.region_code}</div>
            <div style="font-size: 10px; margin-top: 2px;">${region.metric_label}</div>
          </div>
        `,
        iconSize: [100, 40],
        iconAnchor: [50, 20]
      });

      return (
        <Marker
          key={region.region_code}
          position={[region.center_lat, region.center_lng]}
          icon={icon}
          eventHandlers={{
            click: () => setSelectedRegion(region)
          }}
        >
          <Tooltip>
            <div>
              <strong>{region.region_name}</strong>
              <br />
              Island Group: {region.island_group}
              <br />
              {selectedMetric}: {region.metric_label}
            </div>
          </Tooltip>
        </Marker>
      );
    });
  };

  // Create store cluster markers
  const createStoreMarkers = () => {
    return storeClusters.map((cluster) => {
      const icon = L.divIcon({
        className: 'custom-cluster-marker',
        html: `
          <div style="
            background: #3B82F6;
            color: white;
            border-radius: 50%;
            width: ${20 + Math.log(cluster.store_count) * 10}px;
            height: ${20 + Math.log(cluster.store_count) * 10}px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
            font-size: 12px;
            box-shadow: 0 2px 6px rgba(0,0,0,0.3);
          ">
            ${cluster.store_count}
          </div>
        `,
        iconSize: [30, 30],
        iconAnchor: [15, 15]
      });

      return (
        <Marker
          key={cluster.cluster_id}
          position={[cluster.center_lat, cluster.center_lng]}
          icon={icon}
        >
          <Popup>
            <div>
              <strong>Store Cluster</strong>
              <br />
              Stores: {cluster.store_count}
              <br />
              Type: {cluster.dominant_type}
              <br />
              Sales: ₱{cluster.total_sales.toLocaleString()}
            </div>
          </Popup>
        </Marker>
      );
    });
  };

  // Legend component
  const Legend = () => (
    <div className="absolute bottom-4 right-4 bg-white p-4 rounded-lg shadow-lg z-[1000]">
      <h4 className="font-bold mb-2">Sales Intensity</h4>
      <div className="space-y-1">
        {[100, 90, 80, 70, 60, 50, 40, 30, 20, 10].map((percent) => (
          <div key={percent} className="flex items-center gap-2">
            <div
              className="w-6 h-4 border border-gray-300"
              style={{ backgroundColor: getColor(percent / 100) }}
            />
            <span className="text-xs">{percent}%</span>
          </div>
        ))}
      </div>
    </div>
  );

  // Metric selector
  const MetricSelector = () => (
    <div className="absolute top-4 right-4 bg-white p-4 rounded-lg shadow-lg z-[1000]">
      <h4 className="font-bold mb-2">Select Metric</h4>
      <select
        value={selectedMetric}
        onChange={(e) => setSelectedMetric(e.target.value)}
        className="w-full px-3 py-2 border rounded-md"
      >
        <option value="total_sales">Total Sales</option>
        <option value="transaction_count">Transaction Count</option>
        <option value="sales_density">Sales Density</option>
        <option value="market_penetration">Market Penetration</option>
      </select>
    </div>
  );

  // Region details panel
  const RegionDetails = () => {
    if (!selectedRegion) return null;

    return (
      <div className="absolute top-4 left-4 bg-white p-4 rounded-lg shadow-lg z-[1000] max-w-sm">
        <div className="flex justify-between items-start mb-2">
          <h3 className="font-bold text-lg">{selectedRegion.region_name}</h3>
          <button
            onClick={() => setSelectedRegion(null)}
            className="text-gray-500 hover:text-gray-700"
          >
            ✕
          </button>
        </div>
        <div className="space-y-1 text-sm">
          <div>Region Code: {selectedRegion.region_code}</div>
          <div>Island Group: {selectedRegion.island_group}</div>
          <div className="pt-2 border-t">
            <div className="font-semibold">Performance Metrics:</div>
            <div>{selectedMetric}: {selectedRegion.metric_label}</div>
            <div>Intensity: {(selectedRegion.color_intensity * 100).toFixed(1)}%</div>
          </div>
        </div>
      </div>
    );
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-[600px]">
        <div className="text-lg">Loading map data...</div>
      </div>
    );
  }

  return (
    <div className="relative w-full h-[600px] rounded-lg overflow-hidden">
      <MapContainer
        center={[12.8797, 121.7740]} // Center of Philippines
        zoom={6}
        bounds={phBounds}
        className="w-full h-full"
        scrollWheelZoom={true}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        
        {/* Region markers with sales data */}
        {createRegionMarkers()}
        
        {/* Store cluster markers */}
        {createStoreMarkers()}
      </MapContainer>

      {/* UI Components */}
      <Legend />
      <MetricSelector />
      <RegionDetails />
      
      {/* Summary Statistics */}
      <div className="absolute bottom-4 left-4 bg-white p-3 rounded-lg shadow-lg z-[1000]">
        <div className="text-xs space-y-1">
          <div>Total Regions: {regionData.length}</div>
          <div>Store Clusters: {storeClusters.length}</div>
          <div>
            Total Sales: ₱
            {regionData
              .reduce((sum, r) => sum + (r.metric_value || 0), 0)
              .toLocaleString()}
          </div>
        </div>
      </div>
    </div>
  );
};

export default RegionalSalesChoroplethMap;
