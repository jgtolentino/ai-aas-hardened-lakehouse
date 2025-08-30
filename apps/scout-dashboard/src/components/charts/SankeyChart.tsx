'use client'

import React from 'react'

interface SankeyChartProps {
  data?: any[]
  className?: string
  title?: string
}

export const SankeyChart: React.FC<SankeyChartProps> = ({ 
  data = [], 
  className = '',
  title = 'Flow Analysis'
}) => {
  return (
    <div className={`bg-white rounded-lg border p-6 ${className}`}>
      <h3 className="text-lg font-semibold mb-4">{title}</h3>
      <div className="h-64 flex items-center justify-center bg-gray-50 rounded">
        <p className="text-gray-500">Sankey diagram will render here (flow visualization)</p>
      </div>
    </div>
  )
}

export default SankeyChart