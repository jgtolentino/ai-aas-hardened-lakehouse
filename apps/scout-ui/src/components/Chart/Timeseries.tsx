'use client'

import React from 'react'

interface TimeseriesProps {
  data?: any[]
  className?: string
  title?: string
  xAxis?: string
  yAxis?: string
}

export const Timeseries: React.FC<TimeseriesProps> = ({ 
  data = [], 
  className = '',
  title = 'Time Series Chart',
  xAxis = 'Time',
  yAxis = 'Value'
}) => {
  return (
    <div className={`bg-white rounded-lg border p-6 ${className}`}>
      <h3 className="text-lg font-semibold mb-4">{title}</h3>
      <div className="h-64 flex items-center justify-center bg-gray-50 rounded">
        <p className="text-gray-500">Time series chart will render here ({xAxis} vs {yAxis})</p>
      </div>
    </div>
  )
}

export default Timeseries