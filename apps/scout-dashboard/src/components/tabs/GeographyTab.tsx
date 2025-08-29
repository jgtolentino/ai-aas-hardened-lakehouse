import React, { useState, useEffect } from 'react';
import { ChartContainer, BarChart, LineChart, HeatmapChart } from '../charts/ChartWrappers';
import { useFiltersStore, useGlobalFilters } from '../../store/filters';
import { useAIInsights } from '../../services/ai-integration';
import dashboardConfig from '../../config/dashboard-config.json';

export interface GeographyTabProps {
  persona: string;
  className?: string;
}

// Mock data generators for geographic analysis
const generateRegionalPerformanceData = () => [
  { 
    region: 'Metro Manila', 
    revenue: 18500000, 
    stores: 85, 
    avgBasketSize: 485, 
    footTraffic: 145000, 
    growth: 12.3,
    marketShare: 24.5,
    coordinates: { lat: 14.6042, lng: 121.0887 }
  },
  { 
    region: 'Cebu', 
    revenue: 8900000, 
    stores: 32, 
    avgBasketSize: 420, 
    footTraffic: 68000, 
    growth: 15.7,
    marketShare: 18.2,
    coordinates: { lat: 10.3157, lng: 123.8854 }
  },
  { 
    region: 'Davao', 
    revenue: 6200000, 
    stores: 22, 
    avgBasketSize: 395, 
    footTraffic: 47000, 
    growth: 8.4,
    marketShare: 16.8,
    coordinates: { lat: 7.1907, lng: 125.4553 }
  },
  { 
    region: 'Iloilo', 
    revenue: 4100000, 
    stores: 16, 
    avgBasketSize: 375, 
    footTraffic: 31000, 
    growth: 18.9,
    marketShare: 22.1,
    coordinates: { lat: 10.7202, lng: 122.5621 }
  },
  { 
    region: 'Cagayan de Oro', 
    revenue: 3400000, 
    stores: 12, 
    avgBasketSize: 365, 
    footTraffic: 24000, 
    growth: 11.2,
    marketShare: 19.3,
    coordinates: { lat: 8.4542, lng: 124.6319 }
  }
];

const generateStoreLocationsData = () => [
  // Metro Manila stores
  { id: 'MM001', name: 'Makati Central', region: 'Metro Manila', format: 'Hypermarket', revenue: 2100000, lat: 14.5547, lng: 121.0244 },
  { id: 'MM002', name: 'Ortigas Hub', region: 'Metro Manila', format: 'Supermarket', revenue: 1850000, lat: 14.5868, lng: 121.0561 },
  { id: 'MM003', name: 'BGC Plaza', region: 'Metro Manila', format: 'Supermarket', revenue: 1950000, lat: 14.5515, lng: 121.0461 },
  { id: 'MM004', name: 'Quezon Ave', region: 'Metro Manila', format: 'Convenience', revenue: 980000, lat: 14.6417, lng: 121.0377 },
  
  // Cebu stores
  { id: 'CB001', name: 'Ayala Cebu', region: 'Cebu', format: 'Hypermarket', revenue: 1450000, lat: 10.3181, lng: 123.9061 },
  { id: 'CB002', name: 'IT Park', region: 'Cebu', format: 'Supermarket', revenue: 1200000, lat: 10.3265, lng: 123.9056 },
  { id: 'CB003', name: 'Colon Street', region: 'Cebu', format: 'Convenience', revenue: 750000, lat: 10.2958, lng: 123.9003 },
  
  // Davao stores
  { id: 'DV001', name: 'Davao Central', region: 'Davao', format: 'Hypermarket', revenue: 1100000, lat: 7.0731, lng: 125.6128 },
  { id: 'DV002', name: 'Lanang Gulf', region: 'Davao', format: 'Supermarket', revenue: 890000, lat: 7.1018, lng: 125.6295 },
  
  // Other regions
  { id: 'IL001', name: 'Iloilo Business Park', region: 'Iloilo', format: 'Hypermarket', revenue: 950000, lat: 10.7035, lng: 122.5466 },
  { id: 'CD001', name: 'Centrio Mall', region: 'Cagayan de Oro', format: 'Supermarket', revenue: 820000, lat: 8.4826, lng: 124.6513 }
];

const generateTerritoryAnalysisData = () => {
  const territories = ['North Metro', 'South Metro', 'Central Luzon', 'North Luzon', 'Visayas', 'Mindanao'];
  return territories.map(territory => ({
    territory,
    penetration: Math.random() * 40 + 30, // 30-70%
    opportunity: Math.random() * 50 + 25, // 25-75%
    competition: Math.random() * 60 + 20, // 20-80%
    accessibility: Math.random() * 30 + 60, // 60-90%
    demographics: {
      population: Math.floor(Math.random() * 2000000 + 500000),
      urbanization: Math.random() * 40 + 40, // 40-80%
      avgIncome: Math.floor(Math.random() * 20000 + 25000)
    }
  }));
};

const generatePerformanceHeatmapData = (days: number = 30) => {
  const regions = ['Metro Manila', 'Cebu', 'Davao', 'Iloilo', 'Cagayan de Oro'];
  const data = [];
  
  for (let i = days; i >= 0; i--) {
    const date = new Date();
    date.setDate(date.getDate() - i);
    
    regions.forEach(region => {
      const basePerformance = Math.random() * 40 + 60; // 60-100%
      const seasonalFactor = 1 + 0.1 * Math.sin((date.getDay() / 7) * Math.PI);
      const performance = basePerformance * seasonalFactor;
      
      data.push({
        date: date.toISOString().split('T')[0],
        region,
        performance: Math.round(performance),
        sales: Math.floor(Math.random() * 500000 + 200000),
        footTraffic: Math.floor(Math.random() * 10000 + 5000)
      });
    });
  }
  
  return data;
};

export const GeographyTab: React.FC<GeographyTabProps> = ({
  persona,
  className = ''
}) => {
  const filters = useGlobalFilters();
  const { insights, loading: insightsLoading, refreshInsights } = useAIInsights('geography');
  
  const [regionalData, setRegionalData] = useState(generateRegionalPerformanceData());
  const [storeLocations, setStoreLocations] = useState(generateStoreLocationsData());
  const [territoryData, setTerritoryData] = useState(generateTerritoryAnalysisData());
  const [heatmapData, setHeatmapData] = useState(generatePerformanceHeatmapData());
  const [loading, setLoading] = useState(false);
  const [selectedRegion, setSelectedRegion] = useState<string | null>(null);
  const [mapView, setMapView] = useState<'performance' | 'stores' | 'heatmap'>('performance');

  // Simulate data refresh when filters change
  useEffect(() => {
    setLoading(true);
    const timer = setTimeout(() => {
      setRegionalData(generateRegionalPerformanceData());
      setStoreLocations(generateStoreLocationsData());
      setTerritoryData(generateTerritoryAnalysisData());
      setHeatmapData(generatePerformanceHeatmapData());
      setLoading(false);
    }, 800);

    return () => clearTimeout(timer);
  }, [filters]);

  const RegionalPerformanceOverview = () => (
    <ChartContainer
      title="Regional Performance Overview"
      subtitle="Revenue and growth metrics by region"
      loading={loading}
    >
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Revenue Chart */}
        <div>
          <BarChart
            data={regionalData.map(d => ({ name: d.region, value: d.revenue / 1000000 }))}
            height={300}
            color="#3b82f6"
            title="Revenue by Region (₱M)"
            loading={loading}
          />
        </div>
        
        {/* Regional Metrics */}
        <div className="space-y-3">
          {regionalData.map(region => (
            <div 
              key={region.region} 
              className={`p-4 rounded-lg border cursor-pointer transition-colors ${
                selectedRegion === region.region 
                  ? 'border-blue-500 bg-blue-50' 
                  : 'border-gray-200 hover:border-gray-300'
              }`}
              onClick={() => setSelectedRegion(selectedRegion === region.region ? null : region.region)}
            >
              <div className="flex items-center justify-between mb-2">
                <h4 className="font-medium text-gray-900">{region.region}</h4>
                <span className={`text-sm font-medium ${
                  region.growth > 0 ? 'text-green-600' : 'text-red-600'
                }`}>
                  {region.growth > 0 ? '+' : ''}{region.growth}%
                </span>
              </div>
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <span className="text-gray-500">Revenue:</span>
                  <div className="font-medium">₱{(region.revenue / 1000000).toFixed(1)}M</div>
                </div>
                <div>
                  <span className="text-gray-500">Stores:</span>
                  <div className="font-medium">{region.stores}</div>
                </div>
                <div>
                  <span className="text-gray-500">Basket Size:</span>
                  <div className="font-medium">₱{region.avgBasketSize}</div>
                </div>
                <div>
                  <span className="text-gray-500">Market Share:</span>
                  <div className="font-medium">{region.marketShare}%</div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </ChartContainer>
  );

  const GeographicMap = () => (
    <ChartContainer
      title="Geographic Distribution"
      subtitle="Store locations and performance across the Philippines"
      loading={loading}
    >
      <div className="space-y-4">
        {/* Map View Controls */}
        <div className="flex items-center space-x-4">
          <span className="text-sm font-medium text-gray-700">View:</span>
          <div className="flex space-x-2">
            {[
              { key: 'performance', label: 'Performance' },
              { key: 'stores', label: 'Store Locations' },
              { key: 'heatmap', label: 'Sales Heatmap' }
            ].map(view => (
              <button
                key={view.key}
                onClick={() => setMapView(view.key as any)}
                className={`px-3 py-1 text-sm rounded-lg border transition-colors ${
                  mapView === view.key
                    ? 'bg-blue-600 text-white border-blue-600'
                    : 'bg-white text-gray-700 border-gray-300 hover:border-gray-400'
                }`}
              >
                {view.label}
              </button>
            ))}
          </div>
        </div>

        {/* Simplified Map Visualization */}
        <div className="bg-gray-50 rounded-lg p-6 h-96 relative overflow-hidden">
          <div className="absolute inset-0 flex items-center justify-center">
            <svg width="400" height="300" viewBox="0 0 400 300" className="opacity-20">
              {/* Simplified Philippines outline */}
              <path
                d="M100 50 Q120 40 140 55 L160 45 Q180 50 200 65 L220 60 Q240 70 250 90 L270 85 Q290 95 300 120 L320 115 Q330 130 325 150 L340 145 Q350 160 345 180 L365 175 Q370 190 360 210 L380 205 Q385 220 375 240 L395 235 Q400 250 390 270 L370 265 Q360 275 340 270 L320 275 Q300 285 280 280 L260 285 Q240 290 220 285 L200 290 Q180 295 160 290 L140 295 Q120 300 100 295 L80 300 Q60 295 50 285 L40 290 Q30 285 25 270 L15 275 Q10 260 20 245 L5 250 Q0 235 10 220 L25 225 Q35 215 45 200 L30 205 Q20 190 30 175 L45 180 Q55 170 65 155 L50 160 Q40 145 50 130 L65 135 Q75 125 85 110 L70 115 Q60 100 70 85 L85 90 Q95 80 100 65 Z"
                fill="#e5e7eb"
                stroke="#9ca3af"
                strokeWidth="2"
              />
            </svg>
          </div>
          
          {/* Region Performance Indicators */}
          {regionalData.map((region, index) => (
            <div
              key={region.region}
              className={`absolute transform -translate-x-1/2 -translate-y-1/2 ${
                mapView === 'performance' ? 'block' : 'hidden'
              }`}
              style={{
                left: `${20 + (index * 70)}%`,
                top: `${30 + (index % 2) * 40}%`
              }}
            >
              <div
                className={`w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold ${
                  region.growth > 15 ? 'bg-green-500' :
                  region.growth > 10 ? 'bg-yellow-500' : 'bg-red-500'
                }`}
                title={`${region.region}: ${region.growth}% growth`}
              >
                {region.growth.toFixed(0)}
              </div>
              <div className="text-xs text-center mt-1 font-medium text-gray-700">
                {region.region}
              </div>
            </div>
          ))}

          {/* Store Location Indicators */}
          {storeLocations.map((store, index) => (
            <div
              key={store.id}
              className={`absolute transform -translate-x-1/2 -translate-y-1/2 ${
                mapView === 'stores' ? 'block' : 'hidden'
              }`}
              style={{
                left: `${15 + (index % 6) * 70 / 6}%`,
                top: `${25 + Math.floor(index / 6) * 50}%`
              }}
            >
              <div
                className={`w-6 h-6 rounded-full ${
                  store.format === 'Hypermarket' ? 'bg-blue-600' :
                  store.format === 'Supermarket' ? 'bg-green-600' : 'bg-orange-600'
                }`}
                title={`${store.name} (${store.format}): ₱${(store.revenue / 1000000).toFixed(1)}M`}
              />
            </div>
          ))}
        </div>

        {/* Legend */}
        <div className="flex items-center justify-center space-x-6 text-sm">
          {mapView === 'performance' && (
            <>
              <div className="flex items-center space-x-2">
                <div className="w-4 h-4 bg-green-500 rounded-full"></div>
                <span>High Growth (>15%)</span>
              </div>
              <div className="flex items-center space-x-2">
                <div className="w-4 h-4 bg-yellow-500 rounded-full"></div>
                <span>Medium Growth (10-15%)</span>
              </div>
              <div className="flex items-center space-x-2">
                <div className="w-4 h-4 bg-red-500 rounded-full"></div>
                <span>Low Growth (<10%)</span>
              </div>
            </>
          )}
          {mapView === 'stores' && (
            <>
              <div className="flex items-center space-x-2">
                <div className="w-4 h-4 bg-blue-600 rounded-full"></div>
                <span>Hypermarket</span>
              </div>
              <div className="flex items-center space-x-2">
                <div className="w-4 h-4 bg-green-600 rounded-full"></div>
                <span>Supermarket</span>
              </div>
              <div className="flex items-center space-x-2">
                <div className="w-4 h-4 bg-orange-600 rounded-full"></div>
                <span>Convenience</span>
              </div>
            </>
          )}
        </div>
      </div>
    </ChartContainer>
  );

  const TerritoryAnalysis = () => (
    <ChartContainer
      title="Territory Analysis"
      subtitle="Market penetration and expansion opportunities"
      loading={loading}
    >
      <div className="overflow-x-auto">
        <table className="w-full border-collapse">
          <thead>
            <tr className="bg-gray-50">
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-700 border-b">Territory</th>
              <th className="px-4 py-3 text-center text-sm font-medium text-gray-700 border-b">Penetration</th>
              <th className="px-4 py-3 text-center text-sm font-medium text-gray-700 border-b">Opportunity</th>
              <th className="px-4 py-3 text-center text-sm font-medium text-gray-700 border-b">Competition</th>
              <th className="px-4 py-3 text-right text-sm font-medium text-gray-700 border-b">Population</th>
              <th className="px-4 py-3 text-right text-sm font-medium text-gray-700 border-b">Avg Income</th>
            </tr>
          </thead>
          <tbody>
            {territoryData.map((territory, index) => (
              <tr key={territory.territory} className="border-b hover:bg-gray-50">
                <td className="px-4 py-3 text-sm font-medium text-gray-900">
                  {territory.territory}
                </td>
                <td className="px-4 py-3 text-center">
                  <div className="flex items-center justify-center space-x-2">
                    <div className="w-16 bg-gray-200 rounded-full h-2">
                      <div
                        className="h-2 bg-blue-500 rounded-full"
                        style={{ width: `${territory.penetration}%` }}
                      />
                    </div>
                    <span className="text-xs text-gray-600 w-8">
                      {territory.penetration.toFixed(0)}%
                    </span>
                  </div>
                </td>
                <td className="px-4 py-3 text-center">
                  <div className="flex items-center justify-center space-x-2">
                    <div className="w-16 bg-gray-200 rounded-full h-2">
                      <div
                        className="h-2 bg-green-500 rounded-full"
                        style={{ width: `${territory.opportunity}%` }}
                      />
                    </div>
                    <span className="text-xs text-gray-600 w-8">
                      {territory.opportunity.toFixed(0)}%
                    </span>
                  </div>
                </td>
                <td className="px-4 py-3 text-center">
                  <div className="flex items-center justify-center space-x-2">
                    <div className="w-16 bg-gray-200 rounded-full h-2">
                      <div
                        className="h-2 bg-red-500 rounded-full"
                        style={{ width: `${territory.competition}%` }}
                      />
                    </div>
                    <span className="text-xs text-gray-600 w-8">
                      {territory.competition.toFixed(0)}%
                    </span>
                  </div>
                </td>
                <td className="px-4 py-3 text-sm text-gray-900 text-right">
                  {(territory.demographics.population / 1000000).toFixed(1)}M
                </td>
                <td className="px-4 py-3 text-sm text-gray-900 text-right">
                  ₱{territory.demographics.avgIncome.toLocaleString()}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </ChartContainer>
  );

  const StorePerformanceTable = () => {
    const filteredStores = selectedRegion 
      ? storeLocations.filter(store => store.region === selectedRegion)
      : storeLocations;

    return (
      <ChartContainer
        title={`Store Performance ${selectedRegion ? `- ${selectedRegion}` : ''}`}
        subtitle="Individual store metrics and rankings"
        loading={loading}
      >
        <div className="overflow-x-auto">
          <table className="w-full border-collapse">
            <thead>
              <tr className="bg-gray-50">
                <th className="px-4 py-3 text-left text-sm font-medium text-gray-700 border-b">Store</th>
                <th className="px-4 py-3 text-left text-sm font-medium text-gray-700 border-b">Region</th>
                <th className="px-4 py-3 text-left text-sm font-medium text-gray-700 border-b">Format</th>
                <th className="px-4 py-3 text-right text-sm font-medium text-gray-700 border-b">Revenue</th>
                <th className="px-4 py-3 text-center text-sm font-medium text-gray-700 border-b">Performance</th>
              </tr>
            </thead>
            <tbody>
              {filteredStores
                .sort((a, b) => b.revenue - a.revenue)
                .map((store, index) => (
                <tr key={store.id} className="border-b hover:bg-gray-50">
                  <td className="px-4 py-3 text-sm font-medium text-gray-900">
                    {store.name}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-600">
                    {store.region}
                  </td>
                  <td className="px-4 py-3 text-sm">
                    <span className={`inline-block px-2 py-1 text-xs font-medium rounded-full ${
                      store.format === 'Hypermarket' ? 'bg-blue-100 text-blue-800' :
                      store.format === 'Supermarket' ? 'bg-green-100 text-green-800' :
                      'bg-orange-100 text-orange-800'
                    }`}>
                      {store.format}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-900 text-right">
                    ₱{(store.revenue / 1000000).toFixed(1)}M
                  </td>
                  <td className="px-4 py-3 text-center">
                    <span className={`inline-block px-2 py-1 text-xs font-medium rounded-full ${
                      index < 2 ? 'bg-green-100 text-green-800' :
                      index < 5 ? 'bg-yellow-100 text-yellow-800' :
                      'bg-red-100 text-red-800'
                    }`}>
                      #{index + 1}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </ChartContainer>
    );
  };

  return (
    <div className={`space-y-6 p-6 ${className}`}>
      {/* Regional Performance Overview */}
      <RegionalPerformanceOverview />
      
      {/* Geographic Map */}
      <GeographicMap />
      
      {/* Territory Analysis */}
      <TerritoryAnalysis />
      
      {/* Store Performance Table */}
      <StorePerformanceTable />
    </div>
  );
};

export default GeographyTab;