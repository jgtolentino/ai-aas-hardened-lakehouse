'use client'
import React, { useState, useEffect } from 'react'
import { 
  TrendingUp, 
  TrendingDown, 
  Users, 
  DollarSign, 
  CreditCard,
  Activity,
  Globe,
  MapPin,
  BarChart3,
  PieChart,
  Map,
  Layers,
  Navigation,
  Target,
  Award,
  ShoppingBag,
  Building,
  Briefcase,
  Search,
  Bell,
  User,
  ChevronDown,
  ArrowUpRight,
  ArrowDownRight
} from 'lucide-react'

// Main Finebank Dashboard Component aligned with PRD
export default function FinebankDashboard() {
  const [selectedPeriod, setSelectedPeriod] = useState('today')
  const [selectedRegion, setSelectedRegion] = useState('all')
  const [searchQuery, setSearchQuery] = useState('')

  return (
    <div className="min-h-screen bg-[#0b0d12] text-[#e6e9f2]">
      {/* Header */}
      <header className="border-b border-[#1a1d29] bg-[#121622]">
        <div className="px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-8">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-gradient-to-br from-[#0057ff] to-[#0099ff] rounded-lg flex items-center justify-center">
                  <Building className="w-6 h-6 text-white" />
                </div>
                <div>
                  <h1 className="text-xl font-semibold">Finebank.io</h1>
                  <p className="text-xs text-[#9aa3b2]">Financial Management Dashboard</p>
                </div>
              </div>
            </div>

            <div className="flex items-center gap-4">
              {/* Search Bar */}
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#9aa3b2]" />
                <input
                  type="text"
                  placeholder="Search transactions..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-10 pr-4 py-2 bg-[#1a1d29] border border-[#2a2d39] rounded-lg text-sm focus:outline-none focus:border-[#0057ff] w-80"
                />
              </div>

              {/* Notifications */}
              <button className="relative p-2 hover:bg-[#1a1d29] rounded-lg transition-colors">
                <Bell className="w-5 h-5 text-[#9aa3b2]" />
                <span className="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full"></span>
              </button>

              {/* User Profile */}
              <div className="flex items-center gap-3 px-3 py-2 hover:bg-[#1a1d29] rounded-lg cursor-pointer transition-colors">
                <div className="w-8 h-8 bg-gradient-to-br from-purple-500 to-pink-500 rounded-full flex items-center justify-center">
                  <User className="w-4 h-4 text-white" />
                </div>
                <div className="text-sm">
                  <p className="font-medium">John Doe</p>
                  <p className="text-xs text-[#9aa3b2]">Premium Account</p>
                </div>
                <ChevronDown className="w-4 h-4 text-[#9aa3b2]" />
              </div>
            </div>
          </div>
        </div>
      </header>

      <div className="p-6">
        {/* Period Selector */}
        <div className="flex items-center justify-between mb-6">
          <div className="flex gap-2">
            {['today', 'week', 'month', 'quarter', 'year'].map((period) => (
              <button
                key={period}
                onClick={() => setSelectedPeriod(period)}
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${
                  selectedPeriod === period
                    ? 'bg-[#0057ff] text-white'
                    : 'bg-[#121622] text-[#9aa3b2] hover:bg-[#1a1d29]'
                }`}
              >
                {period.charAt(0).toUpperCase() + period.slice(1)}
              </button>
            ))}
          </div>
        </div>

        {/* Main KPI Cards - PRD Required Metrics */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          {/* Total Balance */}
          <div className="bg-[#121622] rounded-xl p-6 border border-[#1a1d29]">
            <div className="flex items-start justify-between mb-4">
              <div className="p-3 bg-[#0057ff]/10 rounded-lg">
                <DollarSign className="w-6 h-6 text-[#0057ff]" />
              </div>
              <span className="flex items-center gap-1 text-xs font-medium text-green-400">
                <ArrowUpRight className="w-3 h-3" />
                +12.5%
              </span>
            </div>
            <p className="text-[#9aa3b2] text-sm mb-1">Total Balance</p>
            <p className="text-2xl font-bold">$24,650</p>
            <p className="text-xs text-[#9aa3b2] mt-2">Updated just now</p>
          </div>

          {/* Monthly Income */}
          <div className="bg-[#121622] rounded-xl p-6 border border-[#1a1d29]">
            <div className="flex items-start justify-between mb-4">
              <div className="p-3 bg-blue-500/10 rounded-lg">
                <TrendingUp className="w-6 h-6 text-blue-500" />
              </div>
              <span className="flex items-center gap-1 text-xs font-medium text-green-400">
                <ArrowUpRight className="w-3 h-3" />
                +8.2%
              </span>
            </div>
            <p className="text-[#9aa3b2] text-sm mb-1">Monthly Income</p>
            <p className="text-2xl font-bold">$8,900</p>
            <p className="text-xs text-[#9aa3b2] mt-2">May 2024</p>
          </div>

          {/* Monthly Expenses */}
          <div className="bg-[#121622] rounded-xl p-6 border border-[#1a1d29]">
            <div className="flex items-start justify-between mb-4">
              <div className="p-3 bg-purple-500/10 rounded-lg">
                <CreditCard className="w-6 h-6 text-purple-500" />
              </div>
              <span className="flex items-center gap-1 text-xs font-medium text-red-400">
                <ArrowDownRight className="w-3 h-3" />
                -3.8%
              </span>
            </div>
            <p className="text-[#9aa3b2] text-sm mb-1">Monthly Expenses</p>
            <p className="text-2xl font-bold">$3,900</p>
            <p className="text-xs text-[#9aa3b2] mt-2">May 2024</p>
          </div>

          {/* Active Customers */}
          <div className="bg-[#121622] rounded-xl p-6 border border-[#1a1d29]">
            <div className="flex items-start justify-between mb-4">
              <div className="p-3 bg-green-500/10 rounded-lg">
                <Users className="w-6 h-6 text-green-500" />
              </div>
              <span className="flex items-center gap-1 text-xs font-medium text-green-400">
                <ArrowUpRight className="w-3 h-3" />
                +15.3%
              </span>
            </div>
            <p className="text-[#9aa3b2] text-sm mb-1">Active Customers</p>
            <p className="text-2xl font-bold">45,832</p>
            <p className="text-xs text-[#9aa3b2] mt-2">Last 30 days</p>
          </div>
        </div>

        {/* Consumer Intelligence Section */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
          {/* Consumer Segments */}
          <div className="bg-[#121622] rounded-xl p-6 border border-[#1a1d29]">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold">Consumer Intelligence</h3>
              <button className="text-sm text-[#0057ff] hover:underline">View All</button>
            </div>
            <div className="space-y-4">
              {/* Segment Distribution */}
              <div className="space-y-3">
                {[
                  { segment: 'Premium Banking', value: 35, color: 'bg-[#0057ff]', customers: '16,041' },
                  { segment: 'Digital Natives', value: 28, color: 'bg-blue-500', customers: '12,833' },
                  { segment: 'Traditional Savers', value: 22, color: 'bg-purple-500', customers: '10,083' },
                  { segment: 'SME Owners', value: 15, color: 'bg-green-500', customers: '6,875' }
                ].map((segment) => (
                  <div key={segment.segment} className="space-y-2">
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-[#e6e9f2]">{segment.segment}</span>
                      <span className="text-[#9aa3b2]">{segment.customers} customers</span>
                    </div>
                    <div className="w-full bg-[#1a1d29] rounded-full h-2">
                      <div
                        className={`${segment.color} h-2 rounded-full transition-all duration-500`}
                        style={{ width: `${segment.value}%` }}
                      />
                    </div>
                  </div>
                ))}
              </div>

              {/* Key Insights */}
              <div className="mt-4 p-4 bg-[#1a1d29] rounded-lg">
                <p className="text-xs text-[#9aa3b2] mb-2">Key Insight</p>
                <p className="text-sm text-[#e6e9f2]">
                  Premium Banking segment shows 23% higher engagement with digital channels, 
                  representing 45% of total revenue despite being 35% of customer base.
                </p>
              </div>
            </div>
          </div>

          {/* Behavioral Analytics */}
          <div className="bg-[#121622] rounded-xl p-6 border border-[#1a1d29]">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold">Behavioral Analytics</h3>
              <button className="text-sm text-[#0057ff] hover:underline">Configure</button>
            </div>
            <div className="grid grid-cols-2 gap-4">
              {[
                { label: 'Avg. Transaction', value: '$485', change: '+12%', icon: CreditCard },
                { label: 'Digital Adoption', value: '78%', change: '+8%', icon: Globe },
                { label: 'Product Holdings', value: '3.2', change: '+0.4', icon: ShoppingBag },
                { label: 'Engagement Score', value: '8.5', change: '+1.2', icon: Target }
              ].map((metric) => (
                <div key={metric.label} className="p-4 bg-[#1a1d29] rounded-lg">
                  <div className="flex items-center gap-2 mb-2">
                    <metric.icon className="w-4 h-4 text-[#9aa3b2]" />
                    <span className="text-xs text-[#9aa3b2]">{metric.label}</span>
                  </div>
                  <p className="text-xl font-bold mb-1">{metric.value}</p>
                  <span className="text-xs text-green-400">{metric.change}</span>
                </div>
              ))}
            </div>

            {/* Predictive Model */}
            <div className="mt-4 p-4 bg-gradient-to-r from-[#0057ff]/10 to-purple-500/10 rounded-lg border border-[#0057ff]/20">
              <div className="flex items-center gap-2 mb-2">
                <Activity className="w-4 h-4 text-[#0057ff]" />
                <p className="text-xs font-medium text-[#0057ff]">AI Prediction</p>
              </div>
              <p className="text-sm text-[#e6e9f2]">
                85% probability of increased loan demand in Q3 2024 based on current behavioral patterns
              </p>
            </div>
          </div>
        </div>

        {/* Geographical Intelligence with Choropleth Map */}
        <GeographicalIntelligence />

        {/* Competitive Intelligence */}
        <CompetitiveIntelligence />
      </div>
    </div>
  )
}

// Geographical Intelligence Component with Choropleth Map
function GeographicalIntelligence() {
  const [selectedMetric, setSelectedMetric] = useState('revenue')
  const [hoveredRegion, setHoveredRegion] = useState(null)

  const regionData = {
    'NCR': { revenue: 850000, customers: 45000, growth: 12.5, branches: 28 },
    'Region I': { revenue: 320000, customers: 18000, growth: 8.2, branches: 12 },
    'Region II': { revenue: 280000, customers: 15000, growth: 6.5, branches: 8 },
    'Region III': { revenue: 450000, customers: 28000, growth: 10.3, branches: 15 },
    'Region IV-A': { revenue: 680000, customers: 38000, growth: 11.8, branches: 22 },
    'Region IV-B': { revenue: 220000, customers: 12000, growth: 5.2, branches: 6 },
    'Region V': { revenue: 340000, customers: 20000, growth: 7.8, branches: 10 },
    'Region VI': { revenue: 420000, customers: 25000, growth: 9.5, branches: 14 },
    'Region VII': { revenue: 560000, customers: 32000, growth: 10.8, branches: 18 },
    'Region VIII': { revenue: 260000, customers: 14000, growth: 5.8, branches: 7 },
    'Region IX': { revenue: 290000, customers: 16000, growth: 6.2, branches: 9 },
    'Region X': { revenue: 380000, customers: 22000, growth: 8.5, branches: 11 },
    'Region XI': { revenue: 480000, customers: 27000, growth: 9.8, branches: 16 },
    'Region XII': { revenue: 320000, customers: 18000, growth: 7.2, branches: 10 },
    'Region XIII': { revenue: 240000, customers: 13000, growth: 5.5, branches: 5 },
    'BARMM': { revenue: 180000, customers: 10000, growth: 4.8, branches: 4 },
    'CAR': { revenue: 200000, customers: 11000, growth: 5.0, branches: 5 }
  }

  const getColorIntensity = (value, metric) => {
    const values = Object.values(regionData).map(d => d[metric])
    const max = Math.max(...values)
    const min = Math.min(...values)
    const normalized = (value - min) / (max - min)
    
    // Create gradient from light to dark based on value
    if (metric === 'growth') {
      return `rgba(0, 87, 255, ${0.2 + normalized * 0.8})`
    }
    return `rgba(0, 87, 255, ${0.2 + normalized * 0.8})`
  }

  return (
    <div className="bg-[#121622] rounded-xl p-6 border border-[#1a1d29] mb-6">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-lg font-semibold">Geographical Intelligence</h3>
          <p className="text-sm text-[#9aa3b2]">Regional performance analysis across Philippines</p>
        </div>
        <div className="flex gap-2">
          {['revenue', 'customers', 'growth', 'branches'].map((metric) => (
            <button
              key={metric}
              onClick={() => setSelectedMetric(metric)}
              className={`px-3 py-1 rounded-lg text-sm font-medium transition-all ${
                selectedMetric === metric
                  ? 'bg-[#0057ff] text-white'
                  : 'bg-[#1a1d29] text-[#9aa3b2] hover:bg-[#2a2d39]'
              }`}
            >
              {metric.charAt(0).toUpperCase() + metric.slice(1)}
            </button>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Choropleth Map */}
        <div className="lg:col-span-2">
          <div className="relative bg-[#1a1d29] rounded-lg p-4 h-[500px]">
            {/* Philippines Map SVG - Simplified representation */}
            <svg viewBox="0 0 800 1000" className="w-full h-full">
              {/* Map regions with choropleth coloring */}
              {Object.entries(regionData).map(([region, data], index) => {
                const color = getColorIntensity(data[selectedMetric], selectedMetric)
                // Simplified region paths - in production, use actual GeoJSON data
                const y = 50 + (index * 55)
                const x = index % 2 === 0 ? 200 : 400
                
                return (
                  <g key={region}>
                    <rect
                      x={x}
                      y={y}
                      width="180"
                      height="50"
                      fill={color}
                      stroke="#2a2d39"
                      strokeWidth="1"
                      className="cursor-pointer transition-all hover:stroke-[#0057ff] hover:stroke-2"
                      onMouseEnter={() => setHoveredRegion({ region, data, x, y })}
                      onMouseLeave={() => setHoveredRegion(null)}
                    />
                    <text
                      x={x + 90}
                      y={y + 25}
                      textAnchor="middle"
                      className="fill-[#e6e9f2] text-xs pointer-events-none"
                    >
                      {region}
                    </text>
                  </g>
                )
              })}
            </svg>

            {/* Tooltip */}
            {hoveredRegion && (
              <div
                className="absolute bg-[#121622] border border-[#2a2d39] rounded-lg p-3 z-10 pointer-events-none"
                style={{
                  left: `${hoveredRegion.x}px`,
                  top: `${hoveredRegion.y}px`,
                  transform: 'translate(-50%, -120%)'
                }}
              >
                <p className="font-semibold text-sm mb-2">{hoveredRegion.region}</p>
                <div className="space-y-1 text-xs">
                  <p>Revenue: ₱{(hoveredRegion.data.revenue / 1000).toFixed(0)}K</p>
                  <p>Customers: {(hoveredRegion.data.customers / 1000).toFixed(1)}K</p>
                  <p>Growth: {hoveredRegion.data.growth}%</p>
                  <p>Branches: {hoveredRegion.data.branches}</p>
                </div>
              </div>
            )}

            {/* Legend */}
            <div className="absolute bottom-4 left-4 bg-[#121622] rounded-lg p-3">
              <p className="text-xs text-[#9aa3b2] mb-2">Legend ({selectedMetric})</p>
              <div className="flex items-center gap-2">
                <div className="w-20 h-2 bg-gradient-to-r from-[#0057ff]/20 to-[#0057ff] rounded-full" />
                <span className="text-xs text-[#e6e9f2]">Low to High</span>
              </div>
            </div>
          </div>
        </div>

        {/* Regional Rankings */}
        <div>
          <h4 className="text-sm font-semibold mb-3">Top Performing Regions</h4>
          <div className="space-y-2">
            {Object.entries(regionData)
              .sort((a, b) => b[1][selectedMetric] - a[1][selectedMetric])
              .slice(0, 5)
              .map(([region, data], index) => (
                <div key={region} className="flex items-center justify-between p-3 bg-[#1a1d29] rounded-lg">
                  <div className="flex items-center gap-3">
                    <span className="text-lg font-bold text-[#0057ff]">#{index + 1}</span>
                    <div>
                      <p className="text-sm font-medium">{region}</p>
                      <p className="text-xs text-[#9aa3b2]">
                        {selectedMetric === 'revenue' && `₱${(data.revenue / 1000).toFixed(0)}K`}
                        {selectedMetric === 'customers' && `${(data.customers / 1000).toFixed(1)}K`}
                        {selectedMetric === 'growth' && `${data.growth}%`}
                        {selectedMetric === 'branches' && `${data.branches} branches`}
                      </p>
                    </div>
                  </div>
                  <MapPin className="w-4 h-4 text-[#9aa3b2]" />
                </div>
              ))}
          </div>

          {/* Regional Insights */}
          <div className="mt-4 p-4 bg-gradient-to-r from-[#0057ff]/10 to-purple-500/10 rounded-lg border border-[#0057ff]/20">
            <div className="flex items-center gap-2 mb-2">
              <Globe className="w-4 h-4 text-[#0057ff]" />
              <p className="text-xs font-medium text-[#0057ff]">Regional Insight</p>
            </div>
            <p className="text-sm text-[#e6e9f2]">
              NCR and Region IV-A account for 38% of total revenue. 
              Opportunity for expansion in underserved regions like BARMM and CAR.
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}

// Competitive Intelligence Component
function CompetitiveIntelligence() {
  return (
    <div className="bg-[#121622] rounded-xl p-6 border border-[#1a1d29]">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-lg font-semibold">Competitive Intelligence</h3>
          <p className="text-sm text-[#9aa3b2]">Market position and competitor analysis</p>
        </div>
        <button className="text-sm text-[#0057ff] hover:underline">Full Report</button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Market Share */}
        <div className="p-4 bg-[#1a1d29] rounded-lg">
          <h4 className="text-sm font-semibold mb-3">Market Share</h4>
          <div className="space-y-3">
            {[
              { bank: 'Finebank', share: 23.5, color: 'bg-[#0057ff]' },
              { bank: 'Competitor A', share: 28.2, color: 'bg-red-500' },
              { bank: 'Competitor B', share: 19.8, color: 'bg-yellow-500' },
              { bank: 'Competitor C', share: 15.3, color: 'bg-green-500' },
              { bank: 'Others', share: 13.2, color: 'bg-gray-500' }
            ].map((bank) => (
              <div key={bank.bank} className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <div className={`w-3 h-3 rounded-full ${bank.color}`} />
                  <span className="text-sm">{bank.bank}</span>
                </div>
                <span className="text-sm font-medium">{bank.share}%</span>
              </div>
            ))}
          </div>
        </div>

        {/* Product Comparison */}
        <div className="p-4 bg-[#1a1d29] rounded-lg">
          <h4 className="text-sm font-semibold mb-3">Product Competitiveness</h4>
          <div className="space-y-3">
            {[
              { product: 'Savings Account', score: 8.5, benchmark: 7.2 },
              { product: 'Credit Cards', score: 7.8, benchmark: 8.1 },
              { product: 'Personal Loans', score: 9.2, benchmark: 7.5 },
              { product: 'Digital Banking', score: 8.9, benchmark: 8.3 },
              { product: 'Investment Products', score: 7.5, benchmark: 8.0 }
            ].map((product) => (
              <div key={product.product} className="space-y-1">
                <div className="flex items-center justify-between text-xs">
                  <span>{product.product}</span>
                  <span className={product.score > product.benchmark ? 'text-green-400' : 'text-red-400'}>
                    {product.score > product.benchmark ? '+' : ''}{(product.score - product.benchmark).toFixed(1)}
                  </span>
                </div>
                <div className="flex gap-1">
                  <div className="flex-1 bg-[#2a2d39] rounded-full h-1.5">
                    <div
                      className="bg-[#0057ff] h-1.5 rounded-full"
                      style={{ width: `${product.score * 10}%` }}
                    />
                  </div>
                  <div className="w-0.5 h-1.5 bg-red-500" style={{ marginLeft: `${product.benchmark * 10}%` }} />
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Key Differentiators */}
        <div className="p-4 bg-[#1a1d29] rounded-lg">
          <h4 className="text-sm font-semibold mb-3">Competitive Advantages</h4>
          <div className="space-y-2">
            {[
              { feature: 'Lower Interest Rates', impact: 'High', icon: TrendingDown },
              { feature: '24/7 Digital Support', impact: 'High', icon: Globe },
              { feature: 'Instant Loan Approval', impact: 'Medium', icon: Activity },
              { feature: 'Rewards Program', impact: 'High', icon: Award },
              { feature: 'Branch Network', impact: 'Medium', icon: Building }
            ].map((feature) => (
              <div key={feature.feature} className="flex items-center justify-between p-2 bg-[#121622] rounded-lg">
                <div className="flex items-center gap-2">
                  <feature.icon className="w-4 h-4 text-[#0057ff]" />
                  <span className="text-sm">{feature.feature}</span>
                </div>
                <span className={`text-xs px-2 py-1 rounded-full ${
                  feature.impact === 'High' ? 'bg-green-500/20 text-green-400' : 'bg-yellow-500/20 text-yellow-400'
                }`}>
                  {feature.impact}
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
