'use client'

import { KPICard } from '@/components/charts/KPICard'
import { useExecutiveKPIs } from '@/data/hooks'

function KPISkeleton() {
  return (
    <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
      {[...Array(4)].map((_, i) => (
        <div key={i} className="bg-white rounded-lg shadow p-6 animate-pulse">
          <div className="flex items-center">
            <div className="w-8 h-8 bg-gray-200 rounded-full"></div>
            <div className="ml-4 flex-1 space-y-2">
              <div className="h-4 bg-gray-200 rounded w-2/3"></div>
              <div className="h-6 bg-gray-200 rounded w-1/3"></div>
              <div className="h-3 bg-gray-200 rounded w-1/4"></div>
            </div>
          </div>
        </div>
      ))}
    </div>
  )
}

function KPIError({ message }: { message: string }) {
  return (
    <div className="bg-red-50 border border-red-200 rounded-lg p-6">
      <div className="text-sm text-red-600">{message}</div>
    </div>
  )
}

function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('en-PH', {
    style: 'currency',
    currency: 'PHP',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount)
}

export function KPISection() {
  const { data, isLoading, isError } = useExecutiveKPIs()

  if (isLoading) return <KPISkeleton />
  if (isError || !data) return <KPIError message="Failed to load KPI data" />

  const { revenue, transactions, market_share, stores } = data

  return (
    <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
      <KPICard
        title="Total Revenue"
        value={formatCurrency(revenue)}
        change="Last 14 days"
        trend="up"
        color="blue"
      />
      <KPICard
        title="Total Transactions"
        value={new Intl.NumberFormat().format(transactions)}
        change="Last 14 days"
        trend="up"
        color="green"
      />
      <KPICard
        title="Market Share"
        value={`${market_share.toFixed(1)}%`}
        change="Period share"
        trend="up"
        color="purple"
      />
      <KPICard
        title="Active Stores"
        value={String(stores)}
        change="Online"
        trend="up"
        color="orange"
      />
    </div>
  )
}