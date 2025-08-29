'use client'

import { RadarChart, PolarGrid, PolarAngleAxis, PolarRadiusAxis, Radar, ResponsiveContainer, Legend } from 'recharts'

interface BehaviorChartProps {
  segment: string
}

const data = [
  { behavior: 'Social Media', current: 85, benchmark: 70 },
  { behavior: 'Email Engagement', current: 65, benchmark: 60 },
  { behavior: 'Mobile Usage', current: 92, benchmark: 75 },
  { behavior: 'Online Shopping', current: 78, benchmark: 65 },
  { behavior: 'Brand Loyalty', current: 58, benchmark: 55 },
  { behavior: 'Price Sensitivity', current: 72, benchmark: 68 },
]

export function BehaviorChart({ segment }: BehaviorChartProps) {
  return (
    <ResponsiveContainer width="100%" height={400}>
      <RadarChart data={data}>
        <PolarGrid />
        <PolarAngleAxis dataKey="behavior" className="text-sm" />
        <PolarRadiusAxis angle={30} domain={[0, 100]} className="text-sm" />
        <Radar name="Current" dataKey="current" stroke="#0057ff" fill="#0057ff" fillOpacity={0.3} />
        <Radar name="Benchmark" dataKey="benchmark" stroke="#10b981" fill="#10b981" fillOpacity={0.3} />
        <Legend />
      </RadarChart>
    </ResponsiveContainer>
  )
}