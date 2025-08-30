'use client'

import React from 'react'

interface KpiTileProps {
  title: string
  value: string | number
  change?: number
  changeType?: 'positive' | 'negative' | 'neutral'
  className?: string
}

export const KpiTile: React.FC<KpiTileProps> = ({ 
  title, 
  value, 
  change, 
  changeType = 'neutral',
  className = '' 
}) => {
  const getChangeColor = () => {
    switch (changeType) {
      case 'positive': return 'text-green-600'
      case 'negative': return 'text-red-600'
      default: return 'text-gray-600'
    }
  }

  return (
    <div className={`bg-white rounded-lg border p-6 ${className}`}>
      <h3 className="text-sm font-medium text-gray-500 mb-2">{title}</h3>
      <div className="text-2xl font-bold text-gray-900 mb-1">{value}</div>
      {change !== undefined && (
        <div className={`text-sm ${getChangeColor()}`}>
          {change > 0 ? '+' : ''}{change}%
        </div>
      )}
    </div>
  )
}

export default KpiTile