import React from "react";

export type FilterOption = {
  key: string;
  label: string;
  type: "select" | "date" | "dateRange" | "text" | "number";
  options?: Array<{ value: string; label: string }>;
  placeholder?: string;
  value?: any;
};

export type FilterPanelProps = {
  title?: string;
  filters: FilterOption[];
  values: Record<string, any>;
  onFilterChange: (key: string, value: any) => void;
  onApplyFilters?: () => void;
  onResetFilters?: () => void;
  collapsed?: boolean;
  onToggleCollapsed?: () => void;
};

export const FilterPanel: React.FC<FilterPanelProps> = ({
  title = "Filters",
  filters,
  values,
  onFilterChange,
  onApplyFilters,
  onResetFilters,
  collapsed = false,
  onToggleCollapsed
}) => {
  const renderFilter = (filter: FilterOption) => {
    const value = values[filter.key] || "";

    switch (filter.type) {
      case "select":
        return (
          <select
            value={value}
            onChange={(e) => onFilterChange(filter.key, e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-brand-turquoise/60"
          >
            <option value="">{filter.placeholder || "Select..."}</option>
            {filter.options?.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        );

      case "date":
        return (
          <input
            type="date"
            value={value}
            onChange={(e) => onFilterChange(filter.key, e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-brand-turquoise/60"
          />
        );

      case "text":
        return (
          <input
            type="text"
            value={value}
            onChange={(e) => onFilterChange(filter.key, e.target.value)}
            placeholder={filter.placeholder}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-brand-turquoise/60"
          />
        );

      case "number":
        return (
          <input
            type="number"
            value={value}
            onChange={(e) => onFilterChange(filter.key, e.target.value)}
            placeholder={filter.placeholder}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-brand-turquoise/60"
          />
        );

      default:
        return null;
    }
  };

  return (
    <div className="bg-white rounded-lg border border-gray-200 shadow-sm">
      <div className="px-4 py-3 border-b border-gray-200">
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-medium text-gray-900">{title}</h3>
          {onToggleCollapsed && (
            <button
              onClick={onToggleCollapsed}
              className="text-gray-400 hover:text-gray-600"
            >
              {collapsed ? "▼" : "▲"}
            </button>
          )}
        </div>
      </div>

      {!collapsed && (
        <div className="p-4">
          <div className="space-y-4">
            {filters.map((filter) => (
              <div key={filter.key}>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  {filter.label}
                </label>
                {renderFilter(filter)}
              </div>
            ))}
          </div>

          {(onApplyFilters || onResetFilters) && (
            <div className="flex space-x-3 mt-6 pt-4 border-t border-gray-200">
              {onApplyFilters && (
                <button
                  onClick={onApplyFilters}
                  className="px-4 py-2 bg-brand-turquoise text-white rounded-md hover:bg-brand-turquoise/90 text-sm font-medium"
                >
                  Apply Filters
                </button>
              )}
              {onResetFilters && (
                <button
                  onClick={onResetFilters}
                  className="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 text-sm font-medium"
                >
                  Reset
                </button>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
};