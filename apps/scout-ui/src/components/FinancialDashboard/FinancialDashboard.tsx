'use client'
import React, { useState, useEffect } from 'react'
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

export interface FinancialMetrics {
  totalBalance: number
  monthlyIncome: number
  monthlyExpenses: number
  savingsRate: number
  trends: {
    balance: number
    income: number
    expenses: number
    savings: number
  }
}

export function FinebankDashboard() {
  const [metrics, setMetrics] = useState<FinancialMetrics>({
    totalBalance: 24650,
    monthlyIncome: 8900,
    monthlyExpenses: 3900,
    savingsRate: 56.2,
    trends: {
      balance: 12.5,
      income: 8.2,
      expenses: -3.8,
      savings: 25.4
    }
  })

  const [timeRange, setTimeRange] = useState<'week' | 'month' | 'year'>('month')
  const [theme, setTheme] = useState<'tableau' | 'pbi' | 'superset'>('tableau')

  // Mock data for charts
  const revenueData = [
    { x: 'Jan', y: 2150 },
    { x: 'Feb', y: 2350 },
    { x: 'Mar', y: 2680 },
    { x: 'Apr', y: 2420 },
    { x: 'May', y: 2890 },
    { x: 'Jun', y: 3150 },
    { x: 'Jul', y: 2947 },
    { x: 'Aug', y: 3250 }
  ]

  const expenseData = [
    { x: 'Food', y: 350 },
    { x: 'Transport', y: 250 },
    { x: 'Shopping', y: 480 },
    { x: 'Housing', y: 1200 },
    { x: 'Bills', y: 320 }
  ]

  // Theme switcher
  useEffect(() => {
    document.documentElement.setAttribute('data-face', theme)
  }, [theme])

  return (
    <div className="min-h-screen bg-bg">
      {/* Header */}
      <header className="border-b border-white/10 bg-panel/50 backdrop-blur-xl sticky top-0 z-50">
        <div className="p-4 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
              <div className="w-10 h-10 rounded-sk bg-accent/20 flex items-center justify-center">
                <DollarSign className="w-6 h-6 text-accent" />
              </div>
              <div>
                <h1 className="text-lg font-semibold text-text">Finebank Scout</h1>
                <p className="text-xs text-muted">Financial Intelligence Platform</p>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-3">
            {/* Search */}
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
              <input 
                type="text"
                placeholder="Search transactions..."
                className="pl-10 pr-4 py-2 bg-panel border border-white/10 rounded-sk text-sm text-text placeholder-muted focus:outline-none focus:border-accent/50"
              />
            </div>

            {/* Theme Switcher */}
            <select 
              value={theme}
              onChange={(e) => setTheme(e.target.value as any)}
              className="px-3 py-2 bg-panel border border-white/10 rounded-sk text-sm text-text focus:outline-none focus:border-accent/50"
            >
              <option value="tableau">Tableau</option>
              <option value="pbi">Power BI</option>
              <option value="superset">Superset</option>
            </select>

            {/* Time Range */}
            <select 
              value={timeRange}
              onChange={(e) => setTimeRange(e.target.value as any)}
              className="px-3 py-2 bg-panel border border-white/10 rounded-sk text-sm text-text focus:outline-none focus:border-accent/50"
            >
              <option value="week">Week</option>
              <option value="month">Month</option>
              <option value="year">Year</option>
            </select>

            <Button tone="neutral">
              <Filter className="w-4 h-4" />
            </Button>

            <Button tone="neutral">
              <Bell className="w-4 h-4" />
            </Button>

            <Button tone="neutral">
              <Settings className="w-4 h-4" />
            </Button>
          </div>
        </div>
      </header>

      <div className="p-6">
        {/* Page Title */}
        <div className="mb-6">
          <h2 className="text-2xl font-bold text-text mb-1">Financial Overview</h2>
          <p className="text-sm text-muted">Monitor your financial health and spending patterns</p>
        </div>

        {/* KPI Grid */}
        <Grid cols={12} className="mb-6">
          <div className="col-span-12 md:col-span-6 lg:col-span-3">
            <KpiTile 
              label="Total Balance" 
              value={`₱${metrics.totalBalance.toLocaleString()}`}
              icon={<DollarSign className="w-5 h-5" />}
              hint={`${metrics.trends.balance > 0 ? '+' : ''}${metrics.trends.balance}% vs last period`}
            />
          </div>
          <div className="col-span-12 md:col-span-6 lg:col-span-3">
            <KpiTile 
              label="Monthly Income" 
              value={`₱${metrics.monthlyIncome.toLocaleString()}`}
              icon={<TrendingUp className="w-5 h-5" />}
              hint={`${metrics.trends.income > 0 ? '+' : ''}${metrics.trends.income}% growth`}
            />
          </div>
          <div className="col-span-12 md:col-span-6 lg:col-span-3">
            <KpiTile 
              label="Monthly Expenses" 
              value={`₱${metrics.monthlyExpenses.toLocaleString()}`}
              icon={<CreditCard className="w-5 h-5" />}
              hint={`${metrics.trends.expenses > 0 ? '+' : ''}${metrics.trends.expenses}% change`}
            />
          </div>
          <div className="col-span-12 md:col-span-6 lg:col-span-3">
            <KpiTile 
              label="Savings Rate" 
              value={`${metrics.savingsRate}%`}
              icon={<Activity className="w-5 h-5" />}
              hint={`${metrics.trends.savings > 0 ? '+' : ''}${metrics.trends.savings}% improvement`}
            />
          </div>
        </Grid>

        {/* Charts Section */}
        <Grid cols={12} className="mb-6">
          <div className="col-span-12 lg:col-span-8">
            <div className="bg-panel rounded-sk p-4 border border-white/10">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-semibold text-text">Revenue Trend</h3>
                <Button tone="neutral">
                  <Download className="w-4 h-4 mr-2" />
                  Export
                </Button>
              </div>
              <Timeseries data={revenueData} />
            </div>
          </div>
          <div className="col-span-12 lg:col-span-4">
            <div className="bg-panel rounded-sk p-4 border border-white/10 h-full">
              <h3 className="text-lg font-semibold text-text mb-4">Spending by Category</h3>
              <div className="space-y-3">
                {expenseData.map((item, idx) => {
                  const total = expenseData.reduce((sum, e) => sum + e.y, 0)
                  const percentage = (item.y / total * 100).toFixed(1)
                  return (
                    <div key={idx} className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <div className="w-2 h-2 rounded-full bg-accent" />
                        <span className="text-sm text-text">{item.x}</span>
                      </div>
                      <div className="flex items-center gap-3">
                        <span className="text-sm text-muted">{percentage}%</span>
                        <span className="text-sm font-semibold text-text">₱{item.y}</span>
                      </div>
                    </div>
                  )
                })}
              </div>
            </div>
          </div>
        </Grid>

        {/* Transactions Table */}
        <div className="bg-panel rounded-sk border border-white/10">
          <div className="p-4 border-b border-white/10">
            <h3 className="text-lg font-semibold text-text">Recent Transactions</h3>
          </div>
          <div className="p-4">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="text-left border-b border-white/10">
                    <th className="pb-3 text-xs font-medium text-muted uppercase tracking-wider">Date</th>
                    <th className="pb-3 text-xs font-medium text-muted uppercase tracking-wider">Description</th>
                    <th className="pb-3 text-xs font-medium text-muted uppercase tracking-wider">Category</th>
                    <th className="pb-3 text-xs font-medium text-muted uppercase tracking-wider text-right">Amount</th>
                    <th className="pb-3 text-xs font-medium text-muted uppercase tracking-wider">Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-white/5">
                  <tr>
                    <td className="py-3 text-sm text-text">2024-05-15</td>
                    <td className="py-3 text-sm text-text">Grocery Store</td>
                    <td className="py-3 text-sm text-muted">Food</td>
                    <td className="py-3 text-sm text-red-400 text-right">-₱85.50</td>
                    <td className="py-3">
                      <span className="px-2 py-1 text-xs rounded-full bg-green-500/20 text-green-400">Completed</span>
                    </td>
                  </tr>
                  <tr>
                    <td className="py-3 text-sm text-text">2024-05-14</td>
                    <td className="py-3 text-sm text-text">Salary Deposit</td>
                    <td className="py-3 text-sm text-muted">Income</td>
                    <td className="py-3 text-sm text-green-400 text-right">+₱3,500.00</td>
                    <td className="py-3">
                      <span className="px-2 py-1 text-xs rounded-full bg-green-500/20 text-green-400">Completed</span>
                    </td>
                  </tr>
                  <tr>
                    <td className="py-3 text-sm text-text">2024-05-13</td>
                    <td className="py-3 text-sm text-text">Netflix Subscription</td>
                    <td className="py-3 text-sm text-muted">Entertainment</td>
                    <td className="py-3 text-sm text-red-400 text-right">-₱15.99</td>
                    <td className="py-3">
                      <span className="px-2 py-1 text-xs rounded-full bg-yellow-500/20 text-yellow-400">Pending</span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        {/* Savings Goals */}
        <Grid cols={12} className="mt-6">
          <div className="col-span-12 lg:col-span-6">
            <div className="bg-panel rounded-sk p-4 border border-white/10">
              <h3 className="text-lg font-semibold text-text mb-4">Savings Goals</h3>
              <div className="space-y-4">
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm text-text">Emergency Fund</span>
                    <span className="text-sm text-muted">60%</span>
                  </div>
                  <div className="w-full bg-white/10 rounded-full h-2">
                    <div className="bg-accent h-2 rounded-full" style={{ width: '60%' }} />
                  </div>
                  <div className="flex items-center justify-between mt-1">
                    <span className="text-xs text-muted">₱12,000</span>
                    <span className="text-xs text-muted">₱20,000</span>
                  </div>
                </div>
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm text-text">Vacation</span>
                    <span className="text-sm text-muted">70%</span>
                  </div>
                  <div className="w-full bg-white/10 rounded-full h-2">
                    <div className="bg-info h-2 rounded-full" style={{ width: '70%' }} />
                  </div>
                  <div className="flex items-center justify-between mt-1">
                    <span className="text-xs text-muted">₱3,500</span>
                    <span className="text-xs text-muted">₱5,000</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="col-span-12 lg:col-span-6">
            <div className="bg-gradient-to-br from-accent/20 to-accent/10 rounded-sk p-4 border border-accent/30">
              <h3 className="text-lg font-semibold text-text mb-4 flex items-center gap-2">
                <Activity className="w-5 h-5 text-accent" />
                AI Insights
              </h3>
              <div className="space-y-3 text-sm text-text/90">
                <div className="p-3 bg-panel/60 rounded-sk">
                  <div className="font-medium text-accent mb-1">💡 Optimization Opportunity</div>
                  <p className="text-xs">Your spending on Shopping increased by 15%. Consider setting a monthly budget limit.</p>
                </div>
                <div className="p-3 bg-panel/60 rounded-sk">
                  <div className="font-medium text-green-400 mb-1">✅ Achievement</div>
                  <p className="text-xs">Great job! Your savings rate improved by 25.4% this month.</p>
                </div>
                <div className="p-3 bg-panel/60 rounded-sk">
                  <div className="font-medium text-warn mb-1">⚠️ Alert</div>
                  <p className="text-xs">3 subscriptions renewing next week totaling ₱450.</p>
                </div>
              </div>
            </div>
          </div>
        </Grid>
      </div>
    </div>
  )
}