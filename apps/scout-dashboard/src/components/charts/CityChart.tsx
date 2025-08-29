'use client'

import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip, Legend } from 'recharts'

interface CityChartProps {
  region: string
}

const data = [
  { name: 'Manila', value: 35, color: '#0057ff' },
  { name: 'Quezon City', value: 22, color: '#10b981' },
  { name: 'Cebu City', value: 18, color: '#f59e0b' },
  { name: 'Davao City', value: 12, color: '#ef4444' },
  { name: 'Makati', value: 8, color: '#8b5cf6' },
  { name: 'Others', value: 5, color: '#6b7280' },
]

export function CityChart({ region }: CityChartProps) {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <PieChart>
        <Pie
          data={data}
          cx="50%"
          cy="50%"
          outerRadius={80}
          fill="#8884d8"
          dataKey="value"
          label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
        >
          {data.map((entry, index) => (
            <Cell key={`cell-${index}`} fill={entry.color} />
          ))}
        </Pie>
        <Tooltip formatter={(value: any) => [`${value}%`, 'Share']} />
        <Legend />
      </PieChart>
    </ResponsiveContainer>
  )
}