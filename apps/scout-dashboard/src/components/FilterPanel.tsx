import React, { useState } from 'react';
import { useFiltersStore, formatDateRange, getFilterDisplayValue, validateFilters } from '../store/filters';
import dashboardConfig from '../config/dashboard-config.json';

export interface FilterPanelProps {
  className?: string;
}

export const FilterPanel: React.FC<FilterPanelProps> = ({ className = '' }) => {
  const {
    dateRange,
    region,
    storeFormat,
    category,
    setDateRange,
    setRegion,
    setStoreFormat,
    setCategory,
    resetFilters,
    getActiveFilters,
    hasActiveFilters,
    savedPresets,
    activePreset,
    savePreset,
    loadPreset,
    deletePreset
  } = useFiltersStore();

  const [showPresetSave, setShowPresetSave] = useState(false);
  const [presetName, setPresetName] = useState('');
  const [presetDescription, setPresetDescription] = useState('');

  const globalFilters = dashboardConfig.filters.global;

  const DateRangeFilter = () => {
    const filter = globalFilters.find(f => f.id === 'date_range');
    if (!filter) return null;

    const handlePresetChange = (preset: string) => {
      const today = new Date();
      let start: Date;
      let end = today;

      switch (preset) {
        case 'last_7_days':
          start = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000);
          break;
        case 'last_30_days':
          start = new Date(today.getTime() - 30 * 24 * 60 * 60 * 1000);
          break;
        case 'last_90_days':
          start = new Date(today.getTime() - 90 * 24 * 60 * 60 * 1000);
          break;
        case 'ytd':
          start = new Date(today.getFullYear(), 0, 1);
          break;
        case 'custom':
          return; // Keep current dates for custom
        default:
          start = new Date(today.getTime() - 30 * 24 * 60 * 60 * 1000);
      }

      setDateRange({
        start: start.toISOString().split('T')[0],
        end: end.toISOString().split('T')[0],
        preset: preset as any
      });
    };

    return (
      <div className="space-y-3">
        <label className="block text-sm font-medium text-gray-700">
          {filter.label}
        </label>
        
        {/* Preset Options */}
        <div className="space-y-2">
          {filter.options.map(option => (
            <label key={option.value} className="flex items-center">
              <input
                type="radio"
                name="dateRange"
                value={option.value}
                checked={dateRange.preset === option.value}
                onChange={(e) => handlePresetChange(e.target.value)}
                className="mr-2 text-blue-600 focus:ring-blue-500"
              />
              <span className="text-sm text-gray-600">{option.label}</span>
            </label>
          ))}
        </div>

        {/* Custom Date Range */}
        {dateRange.preset === 'custom' && (
          <div className="grid grid-cols-2 gap-2 mt-3">
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Start Date</label>
              <input
                type="date"
                value={dateRange.start}
                onChange={(e) => setDateRange({ ...dateRange, start: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">End Date</label>
              <input
                type="date"
                value={dateRange.end}
                onChange={(e) => setDateRange({ ...dateRange, end: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
        )}

        <div className="text-xs text-gray-500 bg-gray-50 p-2 rounded">
          Selected: {formatDateRange(dateRange)}
        </div>
      </div>
    );
  };

  const MultiSelectFilter = ({ filterId, label, options, value, onChange }: {
    filterId: string;
    label: string;
    options: Array<{ value: string; label: string }>;
    value: string[];
    onChange: (value: string[]) => void;
  }) => {
    const [isOpen, setIsOpen] = useState(false);

    const handleOptionToggle = (optionValue: string) => {
      if (optionValue === 'all') {
        onChange(['all']);
      } else {
        const newValue = value.includes(optionValue)
          ? value.filter(v => v !== optionValue && v !== 'all')
          : [...value.filter(v => v !== 'all'), optionValue];
        
        onChange(newValue.length === 0 ? ['all'] : newValue);
      }
    };

    return (
      <div className="space-y-3">
        <label className="block text-sm font-medium text-gray-700">
          {label}
        </label>
        
        <div className="relative">
          <button
            onClick={() => setIsOpen(!isOpen)}
            className="w-full flex items-center justify-between px-3 py-2 border border-gray-300 rounded-lg bg-white text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <span className="text-gray-600">
              {getFilterDisplayValue(filterId, value)}
            </span>
            <svg
              className={`w-4 h-4 transition-transform ${isOpen ? 'rotate-180' : ''}`}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="m19 9-7 7-7-7" />
            </svg>
          </button>

          {isOpen && (
            <div className="absolute z-10 w-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg max-h-48 overflow-y-auto">
              {options.map(option => (
                <label
                  key={option.value}
                  className="flex items-center px-3 py-2 hover:bg-gray-50 cursor-pointer"
                >
                  <input
                    type="checkbox"
                    checked={value.includes(option.value)}
                    onChange={() => handleOptionToggle(option.value)}
                    className="mr-2 text-blue-600 focus:ring-blue-500"
                  />
                  <span className="text-sm text-gray-700">{option.label}</span>
                </label>
              ))}
            </div>
          )}
        </div>
      </div>
    );
  };

  const PresetManager = () => (
    <div className="space-y-3 border-t border-gray-200 pt-4">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-medium text-gray-700">Filter Presets</h3>
        <button
          onClick={() => setShowPresetSave(true)}
          className="text-xs text-blue-600 hover:text-blue-800"
        >
          Save Current
        </button>
      </div>

      {showPresetSave && (
        <div className="bg-gray-50 p-3 rounded-lg space-y-2">
          <input
            type="text"
            placeholder="Preset name"
            value={presetName}
            onChange={(e) => setPresetName(e.target.value)}
            className="w-full px-2 py-1 border border-gray-300 rounded text-sm"
          />
          <input
            type="text"
            placeholder="Description (optional)"
            value={presetDescription}
            onChange={(e) => setPresetDescription(e.target.value)}
            className="w-full px-2 py-1 border border-gray-300 rounded text-sm"
          />
          <div className="flex space-x-2">
            <button
              onClick={() => {
                if (presetName.trim()) {
                  savePreset(presetName.trim(), presetDescription.trim() || undefined);
                  setPresetName('');
                  setPresetDescription('');
                  setShowPresetSave(false);
                }
              }}
              className="flex-1 bg-blue-600 text-white text-xs py-1 px-2 rounded hover:bg-blue-700"
            >
              Save
            </button>
            <button
              onClick={() => {
                setPresetName('');
                setPresetDescription('');
                setShowPresetSave(false);
              }}
              className="flex-1 bg-gray-300 text-gray-700 text-xs py-1 px-2 rounded hover:bg-gray-400"
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      <div className="space-y-1 max-h-32 overflow-y-auto">
        {savedPresets.map(preset => (
          <div
            key={preset.id}
            className={`flex items-center justify-between p-2 rounded text-xs ${
              activePreset === preset.id ? 'bg-blue-50 border border-blue-200' : 'bg-gray-50'
            }`}
          >
            <div className="flex-1">
              <button
                onClick={() => loadPreset(preset.id)}
                className="text-left w-full hover:text-blue-600"
              >
                <div className="font-medium">{preset.name}</div>
                {preset.description && (
                  <div className="text-gray-500">{preset.description}</div>
                )}
              </button>
            </div>
            {!preset.isSystem && (
              <button
                onClick={() => deletePreset(preset.id)}
                className="ml-2 text-red-500 hover:text-red-700"
              >
                ×
              </button>
            )}
          </div>
        ))}
      </div>
    </div>
  );

  const FilterSummary = () => {
    const activeFilters = getActiveFilters();
    const filterCount = Object.keys(activeFilters).length;

    if (filterCount === 0) return null;

    return (
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 space-y-2">
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium text-blue-800">
            {filterCount} filter{filterCount > 1 ? 's' : ''} active
          </span>
          <button
            onClick={resetFilters}
            className="text-xs text-blue-600 hover:text-blue-800 underline"
          >
            Clear all
          </button>
        </div>
        <div className="text-xs text-blue-700">
          Data is filtered based on your current selection
        </div>
      </div>
    );
  };

  return (
    <div className={`space-y-6 ${className}`}>
      {/* Filter Summary */}
      <FilterSummary />

      {/* Global Filters */}
      <div className="space-y-6">
        {/* Date Range */}
        <DateRangeFilter />

        {/* Region */}
        {(() => {
          const regionFilter = globalFilters.find(f => f.id === 'region');
          return regionFilter ? (
            <MultiSelectFilter
              filterId="region"
              label={regionFilter.label}
              options={regionFilter.options}
              value={region}
              onChange={setRegion}
            />
          ) : null;
        })()}

        {/* Store Format */}
        {(() => {
          const storeFormatFilter = globalFilters.find(f => f.id === 'store_format');
          return storeFormatFilter ? (
            <MultiSelectFilter
              filterId="storeFormat"
              label={storeFormatFilter.label}
              options={storeFormatFilter.options}
              value={storeFormat}
              onChange={setStoreFormat}
            />
          ) : null;
        })()}

        {/* Category */}
        {(() => {
          const categoryFilter = globalFilters.find(f => f.id === 'category');
          return categoryFilter ? (
            <MultiSelectFilter
              filterId="category"
              label={categoryFilter.label}
              options={categoryFilter.options}
              value={category}
              onChange={setCategory}
            />
          ) : null;
        })()}
      </div>

      {/* Preset Manager */}
      <PresetManager />

      {/* Validation Messages */}
      {(() => {
        const validation = validateFilters({
          dateRange,
          region,
          storeFormat,
          category
        });

        if (!validation.valid) {
          return (
            <div className="bg-red-50 border border-red-200 rounded-lg p-3">
              <div className="text-sm font-medium text-red-800 mb-2">
                Filter Validation Issues:
              </div>
              <ul className="text-xs text-red-700 space-y-1">
                {validation.errors.map((error, index) => (
                  <li key={index}>• {error}</li>
                ))}
              </ul>
            </div>
          );
        }

        return null;
      })()}
    </div>
  );
};

export default FilterPanel;