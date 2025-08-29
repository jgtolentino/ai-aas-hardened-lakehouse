'use client'

import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'

const data = [
  { name: 'Jan', revenue: 186000 },
  { name: 'Feb', revenue: 205000 },
  { name: 'Mar', revenue: 198000 },
  { name: 'Apr', revenue: 230000 },
  { name: 'May', revenue: 249000 },
  { name: 'Jun', revenue: 267000 },
  { name: 'Jul', revenue: 285000 },
  { name: 'Aug', revenue: 312000 },
  { name: 'Sep', revenue: 294000 },
  { name: 'Oct', revenue: 318000 },
  { name: 'Nov', revenue: 335000 },
  { name: 'Dec', revenue: 358000 },
]

export function RevenueChart() {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <LineChart data={data} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
        <CartesianGrid strokeDasharray="3 3" className="opacity-30" />
        <XAxis dataKey="name" className="text-sm" />
        <YAxis className="text-sm" tickFormatter={(value) => `₱${(value / 1000).toFixed(0)}K`} />
        <Tooltip formatter={(value: any) => [`₱${value.toLocaleString()}`, 'Revenue']} />
        <Line 
          type="monotone" 
          dataKey="revenue" 
          stroke="#0057ff" 
          strokeWidth={2} 
          dot={{ fill: '#0057ff', strokeWidth: 2, r: 4 }}
          activeDot={{ r: 6, stroke: '#0057ff', strokeWidth: 2 }}
        />
      </LineChart>
    </ResponsiveContainer>
  )
}