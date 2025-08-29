'use client'

import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import { useTopBrands } from '@/data/hooks'

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

export function TopBrandsChart() {
  const { data, isLoading, isError } = useTopBrands()

  if (isLoading) return <ChartSkeleton />
  if (isError || !data) return <ChartError message="Failed to load top brands data" />

  return (
    <div className="h-64">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data} margin={{ top: 20, right: 30, left: 20, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis 
            dataKey="name" 
            tick={{ fontSize: 12 }}
            tickLine={{ stroke: '#374151' }}
          />
          <YAxis 
            tick={{ fontSize: 12 }}
            tickLine={{ stroke: '#374151' }}
          />
          <Tooltip 
            formatter={(value: number) => [value, 'Performance Score']}
            labelStyle={{ color: '#374151' }}
            contentStyle={{ 
              backgroundColor: '#ffffff',
              border: '1px solid #e5e7eb',
              borderRadius: '6px'
            }}
          />
          <Bar 
            dataKey="v" 
            fill="#0ea5e9"
            radius={[4, 4, 0, 0]}
          />
        </BarChart>
      </ResponsiveContainer>
    </div>
  )
}