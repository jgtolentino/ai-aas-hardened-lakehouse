import React from "react";

export type ChartCardProps = {
  title: string;
  subtitle?: string;
  chartType: "line" | "bar" | "pie" | "area";
  data: any[];
  loading?: boolean;
  error?: string;
  height?: number;
  showLegend?: boolean;
  onExport?: () => void;
  onRefresh?: () => void;
};

export const ChartCard: React.FC<ChartCardProps> = ({
  title,
  subtitle,
  chartType,
  data,
  loading = false,
  error,
  height = 300,
  showLegend = true,
  onExport,
  onRefresh
}) => {
  if (error) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h3 className="text-lg font-semibold text-gray-900">{title}</h3>
            {subtitle && <p className="text-sm text-gray-600">{subtitle}</p>}
          </div>
        </div>
        <div className="flex items-center justify-center" style={{ height }}>
          <div className="text-center">
            <div className="text-red-500 text-4xl mb-2">⚠️</div>
            <p className="text-red-600 font-medium">Error loading chart</p>
            <p className="text-sm text-gray-500 mt-1">{error}</p>
            {onRefresh && (
              <button
                onClick={onRefresh}
                className="mt-3 px-4 py-2 text-sm bg-red-50 text-red-700 rounded-md hover:bg-red-100"
              >
                Try Again
              </button>
            )}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg border border-gray-200 p-6 shadow-sm">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-lg font-semibold text-gray-900">{title}</h3>
          {subtitle && <p className="text-sm text-gray-600">{subtitle}</p>}
        </div>
        <div className="flex space-x-2">
          {onRefresh && (
            <button
              onClick={onRefresh}
              className="p-2 text-gray-400 hover:text-gray-600 rounded-md hover:bg-gray-50"
              title="Refresh"
            >
              🔄
            </button>
          )}
          {onExport && (
            <button
              onClick={onExport}
              className="p-2 text-gray-400 hover:text-gray-600 rounded-md hover:bg-gray-50"
              title="Export"
            >
              📊
            </button>
          )}
        </div>
      </div>

      <div className="relative" style={{ height }}>
        {loading ? (
          <div className="absolute inset-0 flex items-center justify-center bg-gray-50 rounded-md">
            <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-brand-turquoise"></div>
            <span className="ml-3 text-gray-600">Loading chart...</span>
          </div>
        ) : (
          <div className="w-full h-full flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-50 rounded-md">
            <div className="text-center">
              <div className="text-4xl mb-2">
                {chartType === "line" && "📈"}
                {chartType === "bar" && "📊"}
                {chartType === "pie" && "🥧"}
                {chartType === "area" && "📈"}
              </div>
              <p className="text-gray-600 font-medium">{chartType.toUpperCase()} Chart</p>
              <p className="text-sm text-gray-500">{data.length} data points</p>
            </div>
          </div>
        )}
      </div>

      {showLegend && !loading && (
        <div className="mt-4 flex flex-wrap gap-4 text-sm">
          <div className="flex items-center">
            <div className="w-3 h-3 bg-blue-500 rounded-full mr-2"></div>
            <span className="text-gray-600">Series 1</span>
          </div>
          <div className="flex items-center">
            <div className="w-3 h-3 bg-green-500 rounded-full mr-2"></div>
            <span className="text-gray-600">Series 2</span>
          </div>
        </div>
      )}
    </div>
  );
};