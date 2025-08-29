'use client'

import { KPISection } from '@/components/executive/KPISection'
import { RevenueTrendChart } from '@/components/executive/RevenueTrendChart'
import { TopBrandsChart } from '@/components/executive/TopBrandsChart'

export default function ExecutivePage() {
  return (
    <div className="space-y-8">
      <div className="sm:flex sm:items-center">
        <div className="sm:flex-auto">
          <h1 className="text-2xl font-semibold leading-6 text-gray-900">Executive Dashboard</h1>
          <p className="mt-2 text-sm text-gray-700">
            Key performance indicators and business metrics overview with live Supabase data
          </p>
        </div>
      </div>

      {/* Live KPI Cards */}
      <KPISection />

      {/* Live Charts Grid */}
      <div className="grid grid-cols-1 gap-8 lg:grid-cols-2">
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Revenue Trend (14 Days)</h3>
          <RevenueTrendChart />
        </div>
        
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Top 5 Brands</h3>
          <TopBrandsChart />
        </div>
      </div>

      {/* Performance Summary */}
      <div className="bg-white rounded-lg shadow">
        <div className="px-6 py-4 border-b border-gray-200">
          <h3 className="text-lg font-medium text-gray-900">Performance Summary</h3>
          <p className="mt-1 text-sm text-gray-500">
            Real-time data from Supabase gold layer views with automatic fallback to RPCs
          </p>
        </div>
        <div className="p-6">
          <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
            <div className="text-center">
              <div className="text-2xl font-semibold text-brand-600">Live Data</div>
              <div className="text-sm text-gray-500">Connected to Supabase</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-semibold text-green-600">Role-Based</div>
              <div className="text-sm text-gray-500">Navigation by user role</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-semibold text-blue-600">Real-Time</div>
              <div className="text-sm text-gray-500">Auto-refresh with React Query</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}