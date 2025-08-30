'use client'

import React from 'react'

interface ParetoChartProps {
  data?: any[]
  className?: string
  title?: string
}

export const ParetoChart: React.FC<ParetoChartProps> = ({ 
  data = [], 
  className = '',
  title = 'Pareto Analysis'
}) => {
  return (
    <div className={`bg-white rounded-lg border p-6 ${className}`}>
      <h3 className="text-lg font-semibold mb-4">{title}</h3>
      <div className="h-64 flex items-center justify-center bg-gray-50 rounded">
        <p className="text-gray-500">Pareto chart will render here (80/20 rule)</p>
      </div>
    </div>
  )
}

export default ParetoChart