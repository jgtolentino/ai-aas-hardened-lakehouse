'use client'

import { useState } from 'react'
import { GeographicChart } from '@/components/charts/GeographicChart'
import { RegionChart } from '@/components/charts/RegionChart'
import { CityChart } from '@/components/charts/CityChart'

export default function GeographicPage() {
  const [selectedRegion, setSelectedRegion] = useState('all')
  const [mapView, setMapView] = useState<'heatmap' | 'density' | 'performance'>('heatmap')

  return (
    <div className="space-y-8">
      <div className="sm:flex sm:items-center sm:justify-between">
        <div className="sm:flex-auto">
          <h1 className="text-2xl font-semibold leading-6 text-gray-900">Geographic Analytics</h1>
          <p className="mt-2 text-sm text-gray-700">
            Regional performance and location-based insights across the Philippines
          </p>
        </div>
        <div className="mt-4 sm:ml-16 sm:mt-0 sm:flex-none flex gap-3">
          <select
            value={selectedRegion}
            onChange={(e) => setSelectedRegion(e.target.value)}
            className="block rounded-md border-0 py-1.5 pl-3 pr-10 text-gray-900 ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-brand-600 sm:text-sm sm:leading-6"
          >
            <option value="all">All Regions</option>
            <option value="ncr">National Capital Region</option>
            <option value="car">Cordillera Administrative Region</option>
            <option value="region1">Ilocos Region</option>
            <option value="region2">Cagayan Valley</option>
            <option value="region3">Central Luzon</option>
            <option value="region4a">CALABARZON</option>
            <option value="region4b">MIMAROPA</option>
            <option value="region5">Bicol Region</option>
            <option value="region6">Western Visayas</option>
            <option value="region7">Central Visayas</option>
            <option value="region8">Eastern Visayas</option>
            <option value="region9">Zamboanga Peninsula</option>
            <option value="region10">Northern Mindanao</option>
            <option value="region11">Davao Region</option>
            <option value="region12">SOCCSKSARGEN</option>
            <option value="region13">Caraga</option>
            <option value="barmm">BARMM</option>
          </select>
          <select
            value={mapView}
            onChange={(e) => setMapView(e.target.value as any)}
            className="block rounded-md border-0 py-1.5 pl-3 pr-10 text-gray-900 ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-brand-600 sm:text-sm sm:leading-6"
          >
            <option value="heatmap">Heat Map</option>
            <option value="density">Population Density</option>
            <option value="performance">Performance Map</option>
          </select>
        </div>
      </div>

      {/* Geographic Map */}
      <div className="bg-white rounded-lg shadow">
        <div className="px-6 py-4 border-b border-gray-200">
          <h3 className="text-lg font-medium text-gray-900">Philippines Coverage Map</h3>
          <p className="text-sm text-gray-500">Interactive map showing {mapView} data</p>
        </div>
        <div className="p-6" style={{ minHeight: '500px' }}>
          <GeographicChart region={selectedRegion} viewType={mapView} />
        </div>
      </div>

      {/* Regional Performance */}
      <div className="grid grid-cols-1 gap-8 lg:grid-cols-2">
        <div className="bg-white rounded-lg shadow">
          <div className="px-6 py-4 border-b border-gray-200">
            <h3 className="text-lg font-medium text-gray-900">Regional Performance</h3>
          </div>
          <div className="p-6">
            <RegionChart selectedRegion={selectedRegion} />
          </div>
        </div>

        <div className="bg-white rounded-lg shadow">
          <div className="px-6 py-4 border-b border-gray-200">
            <h3 className="text-lg font-medium text-gray-900">Top Cities</h3>
          </div>
          <div className="p-6">
            <CityChart region={selectedRegion} />
          </div>
        </div>
      </div>

      {/* Regional Statistics */}
      <div className="bg-white rounded-lg shadow overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200">
          <h3 className="text-lg font-medium text-gray-900">Regional Statistics</h3>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Region
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Revenue
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Active Campaigns
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Conversion Rate
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Market Share
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Growth
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {[
                { region: 'National Capital Region (NCR)', revenue: '₱1.2M', campaigns: 12, conversion: '4.2%', share: '35%', growth: '+18%' },
                { region: 'CALABARZON (Region IV-A)', revenue: '₱380K', campaigns: 8, conversion: '3.8%', share: '18%', growth: '+22%' },
                { region: 'Central Luzon (Region III)', revenue: '₱290K', campaigns: 6, conversion: '3.5%', share: '12%', growth: '+15%' },
                { region: 'Central Visayas (Region VII)', revenue: '₱245K', campaigns: 5, conversion: '3.2%', share: '10%', growth: '+8%' },
                { region: 'Western Visayas (Region VI)', revenue: '₱180K', campaigns: 4, conversion: '2.9%', share: '8%', growth: '+12%' },
                { region: 'Northern Mindanao (Region X)', revenue: '₱165K', campaigns: 3, conversion: '3.1%', share: '7%', growth: '+25%' },
              ].map((region) => (
                <tr key={region.region}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    {region.region}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {region.revenue}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {region.campaigns}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {region.conversion}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {region.share}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-green-600 font-medium">
                    {region.growth}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}