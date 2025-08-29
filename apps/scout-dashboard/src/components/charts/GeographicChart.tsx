'use client'

interface GeographicChartProps {
  region: string
  viewType: 'heatmap' | 'density' | 'performance'
}

export function GeographicChart({ region, viewType }: GeographicChartProps) {
  return (
    <div className="w-full h-full flex items-center justify-center bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
      <div className="text-center">
        <svg className="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7" />
        </svg>
        <h3 className="mt-2 text-sm font-medium text-gray-900">Philippines {viewType} Map</h3>
        <p className="mt-1 text-sm text-gray-500">Showing data for: {region === 'all' ? 'All Regions' : region.toUpperCase()}</p>
        <p className="mt-1 text-xs text-gray-400">Interactive map component placeholder</p>
      </div>
    </div>
  )
}