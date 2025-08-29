'use client'

import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip, Legend } from 'recharts'

const data = [
  { name: 'Millennials (25-40)', value: 35, color: '#0057ff' },
  { name: 'Gen Z (18-24)', value: 28, color: '#10b981' },
  { name: 'Gen X (41-55)', value: 22, color: '#f59e0b' },
  { name: 'Baby Boomers (55+)', value: 15, color: '#ef4444' },
]

export function SegmentChart() {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <PieChart>
        <Pie
          data={data}
          cx="50%"
          cy="50%"
          labelLine={false}
          label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(0)}%`}
          outerRadius={80}
          fill="#8884d8"
          dataKey="value"
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