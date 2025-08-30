'use client'
import React from 'react'
import { Grid } from '../Layout/Grid'
import { KpiTile } from '../Kpi/KpiTile'
import { Timeseries } from '../Chart/Timeseries'
import { Button } from '../Button/Button'
import { 
  TrendingUp, 
  TrendingDown, 
  DollarSign, 
  CreditCard, 
  Users, 
  Activity,
  Calendar,
  Filter,
  Download,
  Settings,
  Bell,
  Search
} from 'lucide-react'

export function ScoutDashboard() {
  const kpis = [
    { label: 'Revenue', value: '₱ 12.4M', icon: <DollarSign className="w-5 h-5" />, hint: '+12.5% vs last period' },
    { label: 'Transactions', value: '482k', icon: <TrendingUp className="w-5 h-5" />, hint: '+8.2% growth' },
    { label: 'Basket Size', value: '₱ 257', icon: <CreditCard className="w-5 h-5" />, hint: '-3.8% change' },
    { label: 'Active Users', value: '72k', icon: <Users className="w-5 h-5" />, hint: '+25.4% increase' }
  ]

  const revenueData = [
    { x: 'W1', y: 2150 },
    { x: 'W2', y: 2350 },
    { x: 'W3', y: 2680 },
    { x: 'W4', y: 2420 }
  ]

  return (
    <div className="min-h-screen bg-bg">
      <div className="p-6">
        <Grid cols={12} className="mb-6">
          {kpis.map((kpi, idx) => (
            <div key={idx} className="col-span-12 md:col-span-6 lg:col-span-3">
              <KpiTile {...kpi} />
            </div>
          ))}
        </Grid>
        
        <Grid cols={12}>
          <div className="col-span-12 lg:col-span-8">
            <Timeseries data={revenueData} />
          </div>
          <div className="col-span-12 lg:col-span-4">
            <div className="h-72 bg-panel rounded-sk p-4 border border-white/10">
              <h3 className="text-sm font-medium text-muted mb-3">Quick Actions</h3>
              <div className="space-y-2">
                <Button tone="primary" className="w-full justify-start">
                  <Filter className="w-4 h-4 mr-2" /> Apply Filters
                </Button>
                <Button tone="neutral" className="w-full justify-start">
                  <Download className="w-4 h-4 mr-2" /> Export Data
                </Button>
                <Button tone="neutral" className="w-full justify-start">
                  <Settings className="w-4 h-4 mr-2" /> Settings
                </Button>
              </div>
            </div>
          </div>
        </Grid>
      </div>
    </div>
  )
}