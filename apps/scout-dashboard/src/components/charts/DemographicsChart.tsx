'use client'

import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'

interface DemographicsChartProps {
  segment: string
}

const data = [
  { age: '18-24', male: 23, female: 29 },
  { age: '25-34', male: 34, female: 31 },
  { age: '35-44', male: 28, female: 26 },
  { age: '45-54', male: 18, female: 22 },
  { age: '55+', male: 12, female: 15 },
]

export function DemographicsChart({ segment }: DemographicsChartProps) {
  return (
    <ResponsiveContainer width="100%" height={400}>
      <BarChart data={data} margin={{ top: 20, right: 30, left: 20, bottom: 5 }}>
        <CartesianGrid strokeDasharray="3 3" className="opacity-30" />
        <XAxis dataKey="age" className="text-sm" />
        <YAxis className="text-sm" />
        <Tooltip formatter={(value: any, name: string) => [`${value}%`, name === 'male' ? 'Male' : 'Female']} />
        <Bar dataKey="male" fill="#0057ff" name="male" />
        <Bar dataKey="female" fill="#ec4899" name="female" />
      </BarChart>
    </ResponsiveContainer>
  )
}