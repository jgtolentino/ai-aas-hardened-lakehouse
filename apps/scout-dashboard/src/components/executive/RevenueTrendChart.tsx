'use client'

import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import { useRevenueTrend } from '@/data/hooks'

function ChartSkeleton() {
  return (
    <div className="h-64 bg-gray-50 rounded animate-pulse flex items-center justify-center">
      <div className="text-gray-400">Loading chart...</div>
    </div>
  )
}

function ChartError({ message }: { message: string }) {
  return (
    <div className="h-64 bg-red-50 rounded flex items-center justify-center">
      <div className="text-sm text-red-600">{message}</div>
    </div>
  )
}

export function RevenueTrendChart() {
  const { data, isLoading, isError } = useRevenueTrend()

  if (isLoading) return <ChartSkeleton />
  if (isError || !data) return <ChartError message="Failed to load revenue trend data" />

  return (
    <div className="h-64">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data}>
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis 
            dataKey="d" 
            tick={{ fontSize: 12 }}
            tickLine={{ stroke: '#374151' }}
          />
          <YAxis 
            tick={{ fontSize: 12 }}
            tickLine={{ stroke: '#374151' }}
            tickFormatter={(value) => `₱${(value / 1000).toFixed(0)}K`}
          />
          <Tooltip 
            formatter={(value: number) => [
              `₱${new Intl.NumberFormat().format(value)}`,
              'Revenue'
            ]}
            labelStyle={{ color: '#374151' }}
            contentStyle={{ 
              backgroundColor: '#ffffff',
              border: '1px solid #e5e7eb',
              borderRadius: '6px'
            }}
          />
          <Line 
            type="monotone" 
            dataKey="rev" 
            stroke="#2563eb" 
            strokeWidth={2}
            dot={{ fill: '#2563eb', strokeWidth: 2, r: 4 }}
            activeDot={{ r: 6, fill: '#2563eb' }}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  )
}