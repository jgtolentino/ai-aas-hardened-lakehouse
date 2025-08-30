'use client'

import React from 'react'

interface ChoroplethMapProps {
  data?: any[]
  className?: string
  title?: string
}

export const ChoroplethMap: React.FC<ChoroplethMapProps> = ({ 
  data = [], 
  className = '',
  title = 'Geographic Data Map'
}) => {
  return (
    <div className={`bg-white rounded-lg border p-6 ${className}`}>
      <h3 className="text-lg font-semibold mb-4">{title}</h3>
      <div className="h-80 flex items-center justify-center bg-gray-50 rounded">
        <p className="text-gray-500">Interactive map will render here with geographic data</p>
      </div>
    </div>
  )
}

export default ChoroplethMap