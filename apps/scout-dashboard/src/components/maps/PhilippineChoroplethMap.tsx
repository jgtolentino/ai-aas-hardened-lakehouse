// Simple SVG Choropleth Map for Philippine Regions
// Works without external dependencies

import React, { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';

interface RegionData {
  region_code: string;
  region_name: string;
  island_group: string;
  total_sales: number;
  transaction_count: number;
  sales_density: number;
  market_penetration: number;
  store_count: number;
  color_intensity: number;
}

export const PhilippineChoroplethMap: React.FC = () => {
  const [regions, setRegions] = useState<RegionData[]>([]);
  const [selectedRegion, setSelectedRegion] = useState<RegionData | null>(null);
  const [metric, setMetric] = useState<'sales' | 'density' | 'penetration'>('sales');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadRegionalData();
  }, []);

  const loadRegionalData = async () => {
    try {
      const { data, error } = await supabase
        .from('choropleth_dashboard')
        .select('*');

      if (error) throw error;

      // Calculate color intensity based on selected metric
      const maxValue = Math.max(...data.map(r => r.total_sales || 0));
      const processedData = data.map(r => ({
        ...r,
        color_intensity: (r.total_sales || 0) / maxValue
      }));

      setRegions(processedData);
    } catch (error) {
      console.error('Error loading regional data:', error);
    } finally {
      setLoading(false);
    }
  };

  const getColor = (intensity: number): string => {
    // Green to Red gradient
    const hue = (1 - intensity) * 120; // 120 = green, 0 = red
    return `hsl(${hue}, 70%, 50%)`;
  };

  // Simplified Philippine regions SVG paths
  const regionPaths: Record<string, string> = {
    'NCR': 'M 250,280 L 260,280 L 260,290 L 250,290 Z', // Metro Manila
    'CAR': 'M 240,200 L 260,200 L 260,220 L 240,220 Z', // Cordillera
    'I': 'M 220,210 L 240,210 L 240,230 L 220,230 Z', // Ilocos
    'II': 'M 260,190 L 280,190 L 280,210 L 260,210 Z', // Cagayan Valley
    'III': 'M 240,250 L 260,250 L 260,270 L 240,270 Z', // Central Luzon
    'IV-A': 'M 250,300 L 270,300 L 270,320 L 250,320 Z', // CALABARZON
    'IV-B': 'M 230,330 L 250,330 L 250,350 L 230,350 Z', // MIMAROPA
    'V': 'M 270,320 L 290,320 L 290,340 L 270,340 Z', // Bicol
    'VI': 'M 280,380 L 300,380 L 300,400 L 280,400 Z', // Western Visayas
    'VII': 'M 320,380 L 340,380 L 340,400 L 320,400 Z', // Central Visayas
    'VIII': 'M 340,370 L 360,370 L 360,390 L 340,390 Z', // Eastern Visayas
    'IX': 'M 280,450 L 300,450 L 300,470 L 280,470 Z', // Zamboanga
    'X': 'M 320,440 L 340,440 L 340,460 L 320,460 Z', // Northern Mindanao
    'XI': 'M 340,460 L 360,460 L 360,480 L 340,480 Z', // Davao
    'XII': 'M 310,470 L 330,470 L 330,490 L 310,490 Z', // SOCCSKSARGEN
    'XIII': 'M 350,440 L 370,440 L 370,460 L 350,460 Z', // Caraga
    'BARMM': 'M 290,480 L 310,480 L 310,500 L 290,500 Z', // Bangsamoro
  };

  const formatCurrency = (value: number): string => {
    return '₱' + (value / 1000000).toFixed(2) + 'M';
  };

  const formatPercent = (value: number): string => {
    return value.toFixed(1) + '%';
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-[600px] bg-gray-50 rounded-lg">
        <div className="text-lg text-gray-600">Loading regional data...</div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg shadow-lg p-6">
      {/* Header */}
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-bold text-gray-800">
          Regional Sales Choropleth Map - Philippines
        </h2>
        <div className="flex gap-2">
          <button
            onClick={() => setMetric('sales')}
            className={`px-4 py-2 rounded ${
              metric === 'sales' ? 'bg-blue-500 text-white' : 'bg-gray-200'
            }`}
          >
            Total Sales
          </button>
          <button
            onClick={() => setMetric('density')}
            className={`px-4 py-2 rounded ${
              metric === 'density' ? 'bg-blue-500 text-white' : 'bg-gray-200'
            }`}
          >
            Sales Density
          </button>
          <button
            onClick={() => setMetric('penetration')}
            className={`px-4 py-2 rounded ${
              metric === 'penetration' ? 'bg-blue-500 text-white' : 'bg-gray-200'
            }`}
          >
            Market Penetration
          </button>
        </div>
      </div>

      <div className="flex gap-6">
        {/* Map */}
        <div className="flex-1">
          <svg viewBox="0 0 600 600" className="w-full border rounded-lg">
            {/* Philippine outline */}
            <rect x="0" y="0" width="600" height="600" fill="#E6F3FF" />
            
            {/* Island group labels */}
            <text x="250" y="160" className="text-lg font-bold fill-gray-700">LUZON</text>
            <text x="310" y="360" className="text-lg font-bold fill-gray-700">VISAYAS</text>
            <text x="310" y="430" className="text-lg font-bold fill-gray-700">MINDANAO</text>

            {/* Regions */}
            {regions.map((region) => {
              const path = regionPaths[region.region_code];
              if (!path) return null;

              return (
                <g key={region.region_code}>
                  <path
                    d={path}
                    fill={getColor(region.color_intensity)}
                    stroke="#333"
                    strokeWidth="1"
                    opacity="0.8"
                    className="cursor-pointer hover:opacity-100 transition-opacity"
                    onClick={() => setSelectedRegion(region)}
                  />
                  <text
                    x={parseInt(path.split(' ')[1].split(',')[0]) + 10}
                    y={parseInt(path.split(' ')[1].split(',')[1]) + 10}
                    className="text-xs font-semibold fill-white pointer-events-none"
                  >
                    {region.region_code}
                  </text>
                </g>
              );
            })}
          </svg>

          {/* Legend */}
          <div className="mt-4 flex items-center justify-center gap-4">
            <span className="text-sm text-gray-600">Low</span>
            <div className="flex h-6 w-48 rounded overflow-hidden">
              {Array.from({ length: 10 }).map((_, i) => (
                <div
                  key={i}
                  className="flex-1"
                  style={{ backgroundColor: getColor(i / 10) }}
                />
              ))}
            </div>
            <span className="text-sm text-gray-600">High</span>
          </div>
        </div>

        {/* Region Details Panel */}
        <div className="w-80">
          {selectedRegion ? (
            <div className="bg-gray-50 rounded-lg p-4">
              <h3 className="text-xl font-bold mb-4">{selectedRegion.region_name}</h3>
              <div className="space-y-3">
                <div>
                  <span className="text-gray-600">Region Code:</span>
                  <span className="ml-2 font-semibold">{selectedRegion.region_code}</span>
                </div>
                <div>
                  <span className="text-gray-600">Island Group:</span>
                  <span className="ml-2 font-semibold">{selectedRegion.island_group}</span>
                </div>
                <div className="border-t pt-3">
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <div className="text-gray-600 text-sm">Total Sales</div>
                      <div className="font-bold text-lg">
                        {formatCurrency(selectedRegion.total_sales)}
                      </div>
                    </div>
                    <div>
                      <div className="text-gray-600 text-sm">Transactions</div>
                      <div className="font-bold text-lg">
                        {selectedRegion.transaction_count?.toLocaleString()}
                      </div>
                    </div>
                    <div>
                      <div className="text-gray-600 text-sm">Sales Density</div>
                      <div className="font-bold text-lg">
                        ₱{selectedRegion.sales_density?.toFixed(0)}/km²
                      </div>
                    </div>
                    <div>
                      <div className="text-gray-600 text-sm">Market Share</div>
                      <div className="font-bold text-lg">
                        {formatPercent(selectedRegion.market_penetration || 0)}
                      </div>
                    </div>
                    <div>
                      <div className="text-gray-600 text-sm">Store Count</div>
                      <div className="font-bold text-lg">
                        {selectedRegion.store_count}
                      </div>
                    </div>
                    <div>
                      <div className="text-gray-600 text-sm">Per Capita</div>
                      <div className="font-bold text-lg">
                        ₱{((selectedRegion.total_sales / selectedRegion.population) * 1000).toFixed(0)}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          ) : (
            <div className="bg-gray-50 rounded-lg p-4 text-center text-gray-500">
              Click on a region to view details
            </div>
          )}

          {/* Top Regions */}
          <div className="mt-6">
            <h4 className="font-bold mb-3">Top Performing Regions</h4>
            <div className="space-y-2">
              {regions
                .sort((a, b) => b.total_sales - a.total_sales)
                .slice(0, 5)
                .map((region, index) => (
                  <div
                    key={region.region_code}
                    className="flex justify-between items-center p-2 bg-gray-50 rounded cursor-pointer hover:bg-gray-100"
                    onClick={() => setSelectedRegion(region)}
                  >
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-bold text-gray-500">#{index + 1}</span>
                      <span className="font-medium">{region.region_name}</span>
                    </div>
                    <span className="font-bold text-green-600">
                      {formatCurrency(region.total_sales)}
                    </span>
                  </div>
                ))}
            </div>
          </div>
        </div>
      </div>

      {/* Summary Stats */}
      <div className="mt-6 grid grid-cols-4 gap-4">
        <div className="bg-blue-50 rounded-lg p-4">
          <div className="text-blue-600 text-sm">Total Sales</div>
          <div className="text-2xl font-bold text-blue-900">
            {formatCurrency(regions.reduce((sum, r) => sum + r.total_sales, 0))}
          </div>
        </div>
        <div className="bg-green-50 rounded-lg p-4">
          <div className="text-green-600 text-sm">Total Transactions</div>
          <div className="text-2xl font-bold text-green-900">
            {regions.reduce((sum, r) => sum + r.transaction_count, 0).toLocaleString()}
          </div>
        </div>
        <div className="bg-purple-50 rounded-lg p-4">
          <div className="text-purple-600 text-sm">Active Regions</div>
          <div className="text-2xl font-bold text-purple-900">
            {regions.length} / 17
          </div>
        </div>
        <div className="bg-orange-50 rounded-lg p-4">
          <div className="text-orange-600 text-sm">Avg Market Penetration</div>
          <div className="text-2xl font-bold text-orange-900">
            {formatPercent(
              regions.reduce((sum, r) => sum + (r.market_penetration || 0), 0) / regions.length
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default PhilippineChoroplethMap;
