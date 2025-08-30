'use client'

import React from 'react'

interface StackedBarChartProps {
  data?: any[]
  className?: string
  title?: string
}

export const StackedBarChart: React.FC<StackedBarChartProps> = ({ 
  data = [], 
  className = '',
  title = 'Stacked Bar Chart'
}) => {
  return (
    <div className={`bg-white rounded-lg border p-6 ${className}`}>
      <h3 className="text-lg font-semibold mb-4">{title}</h3>
      <div className="h-64 flex items-center justify-center bg-gray-50 rounded">
        <p className="text-gray-500">Chart will render here with live data</p>
      </div>
    </div>
  )
}

export default StackedBarChart