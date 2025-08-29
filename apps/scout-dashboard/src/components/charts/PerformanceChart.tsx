'use client'

import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'

const data = [
  { name: 'Email', performance: 65, target: 70 },
  { name: 'Social', performance: 78, target: 75 },
  { name: 'Search', performance: 82, target: 80 },
  { name: 'Display', performance: 45, target: 60 },
  { name: 'Video', performance: 88, target: 85 },
  { name: 'Mobile', performance: 92, target: 90 },
]

export function PerformanceChart() {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <BarChart data={data} margin={{ top: 20, right: 30, left: 20, bottom: 5 }}>
        <CartesianGrid strokeDasharray="3 3" className="opacity-30" />
        <XAxis dataKey="name" className="text-sm" />
        <YAxis className="text-sm" />
        <Tooltip formatter={(value: any, name: string) => [`${value}%`, name === 'performance' ? 'Actual' : 'Target']} />
        <Bar dataKey="target" fill="#e5e7eb" name="target" />
        <Bar dataKey="performance" fill="#0057ff" name="performance" />
      </BarChart>
    </ResponsiveContainer>
  )
}