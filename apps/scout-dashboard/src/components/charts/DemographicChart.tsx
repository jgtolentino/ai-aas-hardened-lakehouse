'use client'

import React from 'react'

interface DemographicChartProps {
  data?: any[]
  className?: string
  title?: string
}

export const DemographicChart: React.FC<DemographicChartProps> = ({ 
  data = [], 
  className = '',
  title = 'Demographic Analysis'
}) => {
  return (
    <div className={`bg-white rounded-lg border p-6 ${className}`}>
      <h3 className="text-lg font-semibold mb-4">{title}</h3>
      <div className="h-64 flex items-center justify-center bg-gray-50 rounded">
        <p className="text-gray-500">Demographic data visualization will render here</p>
      </div>
    </div>
  )
}

export default DemographicChart