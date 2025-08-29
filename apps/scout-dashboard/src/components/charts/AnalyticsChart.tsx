'use client'

import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from 'recharts'

interface AnalyticsChartProps {
  timeRange: string
}

const data = [
  { date: '2024-01-01', sessions: 1240, pageviews: 3420, bounceRate: 42 },
  { date: '2024-01-02', sessions: 1380, pageviews: 3890, bounceRate: 38 },
  { date: '2024-01-03', sessions: 1150, pageviews: 3200, bounceRate: 45 },
  { date: '2024-01-04', sessions: 1420, pageviews: 4100, bounceRate: 35 },
  { date: '2024-01-05', sessions: 1680, pageviews: 4750, bounceRate: 32 },
  { date: '2024-01-06', sessions: 1520, pageviews: 4320, bounceRate: 39 },
  { date: '2024-01-07', sessions: 1750, pageviews: 5100, bounceRate: 28 },
]

export function AnalyticsChart({ timeRange }: AnalyticsChartProps) {
  return (
    <ResponsiveContainer width="100%" height={400}>
      <LineChart data={data} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
        <CartesianGrid strokeDasharray="3 3" className="opacity-30" />
        <XAxis dataKey="date" className="text-sm" tickFormatter={(value) => new Date(value).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} />
        <YAxis yAxisId="left" className="text-sm" />
        <YAxis yAxisId="right" orientation="right" className="text-sm" />
        <Tooltip 
          labelFormatter={(value) => new Date(value).toLocaleDateString()}
          formatter={(value: any, name: string) => {
            if (name === 'bounceRate') return [`${value}%`, 'Bounce Rate']
            return [value.toLocaleString(), name === 'sessions' ? 'Sessions' : 'Page Views']
          }}
        />
        <Legend />
        <Line yAxisId="left" type="monotone" dataKey="sessions" stroke="#0057ff" strokeWidth={2} name="Sessions" />
        <Line yAxisId="left" type="monotone" dataKey="pageviews" stroke="#10b981" strokeWidth={2} name="Page Views" />
        <Line yAxisId="right" type="monotone" dataKey="bounceRate" stroke="#f59e0b" strokeWidth={2} name="Bounce Rate (%)" />
      </LineChart>
    </ResponsiveContainer>
  )
}