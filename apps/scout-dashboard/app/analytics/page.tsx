'use client'
import { Grid, ChartCard, KpiCard, FilterPanel } from '../../../scout-ui/src/components'
import { TrendingUp, Users, DollarSign, Activity } from 'lucide-react'
import { useState } from 'react'

export default function AnalyticsPage() {
  const [filters, setFilters] = useState({
    period: 'month',
    category: 'all'
  })

  const performanceData = [
    { x: 'Jan', y: 85 },
    { x: 'Feb', y: 88 },
    { x: 'Mar', y: 92 },
    { x: 'Apr', y: 87 },
    { x: 'May', y: 95 },
    { x: 'Jun', y: 98 }
  ]

  const filterOptions = [
    {
      key: 'period',
      label: 'Time Period',
      type: 'select' as const,
      options: [
        { value: 'week', label: 'Last Week' },
        { value: 'month', label: 'Last Month' },
        { value: 'quarter', label: 'Last Quarter' },
        { value: 'year', label: 'Last Year' }
      ]
    },
    {
      key: 'category',
      label: 'Category',
      type: 'select' as const,
      options: [
        { value: 'all', label: 'All Categories' },
        { value: 'revenue', label: 'Revenue' },
        { value: 'users', label: 'Users' },
        { value: 'performance', label: 'Performance' }
      ]
    }
  ]

  return (
    <div className="min-h-screen bg-bg p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-text">Analytics Dashboard</h1>
        <p className="text-sm text-muted">Deep dive into your performance metrics</p>
      </div>

      <FilterPanel
        filters={filterOptions}
        values={filters}
        onFilterChange={(key, value) => setFilters(prev => ({ ...prev, [key]: value }))}
        onReset={() => setFilters({ period: 'month', category: 'all' })}
      />

      <Grid cols={12} className="mt-6 gap-6">
        <div className="col-span-12 md:col-span-6 lg:col-span-3">
          <KpiCard
            title="Total Revenue"
            value="₱ 3.2M"
            change={12.5}
            changeLabel="vs last period"
            icon={<DollarSign className="w-5 h-5 text-accent" />}
          />
        </div>
        <div className="col-span-12 md:col-span-6 lg:col-span-3">
          <KpiCard
            title="Active Users"
            value="8,432"
            change={8.3}
            changeLabel="vs last period"
            icon={<Users className="w-5 h-5 text-accent" />}
          />
        </div>
        <div className="col-span-12 md:col-span-6 lg:col-span-3">
          <KpiCard
            title="Conversion Rate"
            value="4.8%"
            change={-2.1}
            changeLabel="vs last period"
            icon={<TrendingUp className="w-5 h-5 text-accent" />}
          />
        </div>
        <div className="col-span-12 md:col-span-6 lg:col-span-3">
          <KpiCard
            title="Avg Session"
            value="5m 32s"
            change={15.7}
            changeLabel="vs last period"
            icon={<Activity className="w-5 h-5 text-accent" />}
          />
        </div>
      </Grid>

      <Grid cols={12} className="mt-6 gap-6">
        <div className="col-span-12 lg:col-span-8">
          <ChartCard
            title="Performance Trend"
            subtitle="Monthly performance score"
            data={performanceData}
          />
        </div>
        <div className="col-span-12 lg:col-span-4">
          <div className="bg-panel rounded-sk p-4 border border-white/10 h-full">
            <h3 className="text-lg font-semibold text-text mb-4">Top Performers</h3>
            <div className="space-y-3">
              {['Product A', 'Product B', 'Product C', 'Product D'].map((item, idx) => (
                <div key={idx} className="flex items-center justify-between p-3 bg-bg rounded-sk">
                  <span className="text-sm text-text">{item}</span>
                  <span className="text-sm font-semibold text-accent">{95 - idx * 5}%</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </Grid>
    </div>
  )
}