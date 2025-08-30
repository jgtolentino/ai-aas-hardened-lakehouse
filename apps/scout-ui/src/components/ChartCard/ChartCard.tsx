'use client'
import React from 'react'
import { Timeseries, type SeriesPoint } from '../Chart/Timeseries'

export interface ChartCardProps {
  title: string
  subtitle?: string
  data: SeriesPoint[]
  className?: string
}

export function ChartCard({ title, subtitle, data, className = '' }: ChartCardProps) {
  return (
    <div className={`bg-panel rounded-sk p-4 border border-white/10 ${className}`}>
      <div className="mb-4">
        <h3 className="text-lg font-semibold text-text">{title}</h3>
        {subtitle && <p className="text-sm text-muted">{subtitle}</p>}
      </div>
      <Timeseries data={data} />
    </div>
  )
}