'use client'
import React from 'react'
import { Button } from '../Button/Button'
import { Filter, X } from 'lucide-react'

export interface FilterOption {
  key: string
  label: string
  type: 'select' | 'text' | 'date'
  options?: { value: string; label: string }[]
  placeholder?: string
}

export interface FilterPanelProps {
  filters: FilterOption[]
  values: Record<string, any>
  onFilterChange: (key: string, value: any) => void
  onApply?: () => void
  onReset?: () => void
}

export function FilterPanel({ 
  filters, 
  values, 
  onFilterChange, 
  onApply, 
  onReset 
}: FilterPanelProps) {
  return (
    <div className="bg-panel rounded-sk p-4 border border-white/10">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-sm font-medium text-text flex items-center gap-2">
          <Filter className="w-4 h-4" />
          Filters
        </h3>
        {onReset && (
          <button onClick={onReset} className="text-xs text-muted hover:text-text">
            <X className="w-4 h-4" />
          </button>
        )}
      </div>
      
      <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-4 gap-3">
        {filters.map((filter) => (
          <div key={filter.key}>
            <label className="text-xs text-muted mb-1 block">{filter.label}</label>
            {filter.type === 'select' && (
              <select
                value={values[filter.key] || ''}
                onChange={(e) => onFilterChange(filter.key, e.target.value)}
                className="w-full px-3 py-2 bg-bg border border-white/10 rounded-sk text-sm text-text focus:outline-none focus:border-accent/50"
              >
                <option value="">{filter.placeholder || 'All'}</option>
                {filter.options?.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            )}
            {filter.type === 'text' && (
              <input
                type="text"
                value={values[filter.key] || ''}
                onChange={(e) => onFilterChange(filter.key, e.target.value)}
                placeholder={filter.placeholder}
                className="w-full px-3 py-2 bg-bg border border-white/10 rounded-sk text-sm text-text focus:outline-none focus:border-accent/50"
              />
            )}
          </div>
        ))}
      </div>
      
      {onApply && (
        <div className="mt-4 flex justify-end">
          <Button tone="primary" onClick={onApply}>
            Apply Filters
          </Button>
        </div>
      )}
    </div>
  )
}