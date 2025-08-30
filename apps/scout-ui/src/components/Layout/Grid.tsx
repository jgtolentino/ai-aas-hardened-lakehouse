'use client'

import React from 'react'

interface GridProps {
  children: React.ReactNode
  className?: string
  columns?: number
}

export const Grid: React.FC<GridProps> = ({ 
  children, 
  className = '',
  columns = 3 
}) => {
  return (
    <div className={`grid grid-cols-1 md:grid-cols-${columns} gap-6 ${className}`}>
      {children}
    </div>
  )
}

export default Grid