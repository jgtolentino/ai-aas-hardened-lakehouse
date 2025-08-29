'use client'

import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, LineChart, Line } from 'recharts'

interface CustomReportProps {
  reportType: string
  dateRange: string
}

const executiveData = [
  { metric: 'Revenue', current: 2400000, target: 2200000, variance: '+9%' },
  { metric: 'Campaigns', current: 23, target: 20, variance: '+15%' },
  { metric: 'Conversion Rate', current: 3.2, target: 3.5, variance: '-8%' },
  { metric: 'Customer Satisfaction', current: 4.8, target: 4.5, variance: '+7%' },
]

const campaignData = [
  { month: 'Jan', performance: 85, spend: 125000 },
  { month: 'Feb', performance: 88, spend: 135000 },
  { month: 'Mar', performance: 82, spend: 128000 },
  { month: 'Apr', performance: 91, spend: 142000 },
  { month: 'May', performance: 94, spend: 148000 },
  { month: 'Jun', performance: 89, spend: 139000 },
]

export function CustomReport({ reportType, dateRange }: CustomReportProps) {
  if (reportType === 'executive-summary') {
    return (
      <div className="space-y-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="bg-gray-50 p-4 rounded-lg">
            <h4 className="text-sm font-medium text-gray-900 mb-3">Key Performance Indicators</h4>
            <div className="space-y-3">
              {executiveData.map((item) => (
                <div key={item.metric} className="flex items-center justify-between">
                  <span className="text-sm text-gray-600">{item.metric}</span>
                  <div className="flex items-center space-x-2">
                    <span className="text-sm font-medium">
                      {typeof item.current === 'number' && item.current > 1000 
                        ? `₱${item.current.toLocaleString()}` 
                        : item.current}
                    </span>
                    <span className={`text-xs px-2 py-1 rounded ${
                      item.variance.startsWith('+') 
                        ? 'bg-green-100 text-green-600' 
                        : 'bg-red-100 text-red-600'
                    }`}>
                      {item.variance}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>
          
          <div className="bg-gray-50 p-4 rounded-lg">
            <h4 className="text-sm font-medium text-gray-900 mb-3">Quick Insights</h4>
            <ul className="text-sm text-gray-600 space-y-2">
              <li>• Revenue exceeded target by 9% this quarter</li>
              <li>• Customer satisfaction improved to 4.8/5.0</li>
              <li>• 3 new campaigns launched successfully</li>
              <li>• Conversion rate needs attention (-8% vs target)</li>
            </ul>
          </div>
        </div>
      </div>
    )
  }

  if (reportType === 'campaign-performance') {
    return (
      <div className="space-y-6">
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={campaignData}>
            <CartesianGrid strokeDasharray="3 3" className="opacity-30" />
            <XAxis dataKey="month" className="text-sm" />
            <YAxis yAxisId="left" className="text-sm" />
            <YAxis yAxisId="right" orientation="right" className="text-sm" />
            <Tooltip />
            <Line yAxisId="left" type="monotone" dataKey="performance" stroke="#0057ff" name="Performance %" />
            <Line yAxisId="right" type="monotone" dataKey="spend" stroke="#10b981" name="Spend (₱)" />
          </LineChart>
        </ResponsiveContainer>
        
        <div className="mt-4 text-sm text-gray-600">
          <p>Campaign performance has shown consistent growth with May achieving the highest performance score of 94%. 
             Total spend has increased proportionally with performance improvements.</p>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="bg-gray-50 p-8 rounded-lg text-center">
        <div className="text-gray-400">
          <svg className="mx-auto h-12 w-12 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
        </div>
        <h4 className="text-lg font-medium text-gray-900 mb-2">{reportType.split('-').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ')} Report</h4>
        <p className="text-gray-500">Report content for {dateRange} will be generated here</p>
        <p className="text-sm text-gray-400 mt-2">This is a placeholder for the {reportType} report type</p>
      </div>
    </div>
  )
}