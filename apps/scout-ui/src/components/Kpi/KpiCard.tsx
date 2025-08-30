import React from 'react'
import { TrendingUp, TrendingDown, Minus } from 'lucide-react'

export interface KpiCardProps {
  title: string
  value: string | number
  change?: number
  changeLabel?: string
  icon?: React.ReactNode
  className?: string
}

export function KpiCard({ 
  title, 
  value, 
  change, 
  changeLabel, 
  icon, 
  className = '' 
}: KpiCardProps) {
  const getTrendIcon = () => {
    if (!change) return <Minus className="w-4 h-4 text-muted" />
    if (change > 0) return <TrendingUp className="w-4 h-4 text-green-400" />
    return <TrendingDown className="w-4 h-4 text-red-400" />
  }

  const getTrendColor = () => {
    if (!change) return 'text-muted'
    return change > 0 ? 'text-green-400' : 'text-red-400'
  }

  return (
    <div className={`bg-panel rounded-sk p-6 border border-white/10 ${className}`}>
      <div className="flex items-start justify-between mb-4">
        <div className="p-2 bg-accent/10 rounded-sk">
          {icon || <Activity className="w-5 h-5 text-accent" />}
        </div>
        <div className={`flex items-center gap-1 ${getTrendColor()}`}>
          {getTrendIcon()}
          <span className="text-sm font-medium">
            {change ? `${change > 0 ? '+' : ''}${change}%` : '0%'}
          </span>
        </div>
      </div>
      
      <div>
        <p className="text-sm text-muted mb-1">{title}</p>
        <p className="text-2xl font-bold text-text">{value}</p>
        {changeLabel && (
          <p className="text-xs text-muted mt-2">{changeLabel}</p>
        )}
      </div>
    </div>
  )
}

import { Activity } from 'lucide-react'