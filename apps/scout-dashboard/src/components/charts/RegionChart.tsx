'use client'

import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'

interface RegionChartProps {
  selectedRegion: string
}

const data = [
  { region: 'NCR', revenue: 1200000, growth: 18 },
  { region: 'CALABARZON', revenue: 380000, growth: 22 },
  { region: 'Central Luzon', revenue: 290000, growth: 15 },
  { region: 'Central Visayas', revenue: 245000, growth: 8 },
  { region: 'Western Visayas', revenue: 180000, growth: 12 },
  { region: 'Northern Mindanao', revenue: 165000, growth: 25 },
]

export function RegionChart({ selectedRegion }: RegionChartProps) {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <BarChart data={data} margin={{ top: 20, right: 30, left: 20, bottom: 5 }}>
        <CartesianGrid strokeDasharray="3 3" className="opacity-30" />
        <XAxis dataKey="region" className="text-sm" angle={-45} textAnchor="end" height={60} />
        <YAxis className="text-sm" tickFormatter={(value) => `₱${(value / 1000).toFixed(0)}K`} />
        <Tooltip formatter={(value: any) => [`₱${value.toLocaleString()}`, 'Revenue']} />
        <Bar dataKey="revenue" fill="#0057ff" />
      </BarChart>
    </ResponsiveContainer>
  )
}