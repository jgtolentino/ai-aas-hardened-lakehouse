import React, { useMemo } from 'react';
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  PieChart,
  Pie,
  Cell,
  AreaChart,
  Area,
  ScatterChart,
  Scatter,
  ComposedChart,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer
} from 'recharts';

// Color palette for Scout Dashboard
const SCOUT_COLORS = {
  primary: '#3B82F6',
  secondary: '#10B981',
  accent: '#F59E0B',
  danger: '#EF4444',
  neutral: '#6B7280',
  success: '#059669',
  warning: '#D97706',
  info: '#0891B2'
};

const CHART_PALETTE = [
  SCOUT_COLORS.primary,
  SCOUT_COLORS.secondary,
  SCOUT_COLORS.accent,
  SCOUT_COLORS.danger,
  SCOUT_COLORS.info,
  SCOUT_COLORS.warning,
  SCOUT_COLORS.neutral,
  SCOUT_COLORS.success
];

// Base chart wrapper interface
export interface BaseChartProps {
  data: any[];
  width?: number;
  height?: number;
  loading?: boolean;
  error?: string;
  title?: string;
  subtitle?: string;
  className?: string;
}

// Revenue trend chart for Overview tab
export interface RevenueTrendChartProps extends BaseChartProps {
  showComparison?: boolean;
  comparisonData?: any[];
  currency?: string;
}

export const RevenueTrendChart: React.FC<RevenueTrendChartProps> = ({
  data,
  height = 300,
  loading,
  error,
  showComparison = false,
  comparisonData,
  currency = 'PHP',
  className = ''
}) => {
  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('en-PH', {
      style: 'currency',
      currency: currency,
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(value);
  };

  if (loading) {
    return <ChartSkeleton height={height} />;
  }

  if (error) {
    return <ChartError message={error} height={height} />;
  }

  return (
    <div className={className}>
      <ResponsiveContainer width="100%" height={height}>
        <LineChart data={data} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
          <XAxis 
            dataKey="date" 
            stroke="#6B7280"
            fontSize={12}
            tickFormatter={(value) => new Date(value).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' })}
          />
          <YAxis 
            stroke="#6B7280"
            fontSize={12}
            tickFormatter={formatCurrency}
          />
          <Tooltip
            content={({ active, payload, label }) => {
              if (active && payload && payload.length) {
                return (
                  <div className="bg-white p-3 border border-gray-200 rounded-lg shadow-lg">
                    <p className="text-sm font-medium text-gray-900">
                      {new Date(label).toLocaleDateString('en-PH', { 
                        year: 'numeric', 
                        month: 'long', 
                        day: 'numeric' 
                      })}
                    </p>
                    {payload.map((entry, index) => (
                      <p key={index} className="text-sm" style={{ color: entry.color }}>
                        {entry.name}: {formatCurrency(entry.value as number)}
                      </p>
                    ))}
                  </div>
                );
              }
              return null;
            }}
          />
          <Legend />
          <Line 
            type="monotone" 
            dataKey="revenue" 
            stroke={SCOUT_COLORS.primary}
            strokeWidth={2}
            dot={{ fill: SCOUT_COLORS.primary, strokeWidth: 2, r: 4 }}
            activeDot={{ r: 6, strokeWidth: 2 }}
            name="Revenue"
          />
          {showComparison && (
            <Line 
              type="monotone" 
              dataKey="previousRevenue" 
              stroke={SCOUT_COLORS.neutral}
              strokeWidth={2}
              strokeDasharray="5 5"
              dot={{ fill: SCOUT_COLORS.neutral, strokeWidth: 2, r: 3 }}
              name="Previous Period"
            />
          )}
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
};

// Category performance chart for Mix tab
export interface CategoryMixChartProps extends BaseChartProps {
  chartType: 'bar' | 'pie' | 'treemap';
  showPercentage?: boolean;
}

export const CategoryMixChart: React.FC<CategoryMixChartProps> = ({
  data,
  height = 300,
  chartType = 'bar',
  showPercentage = true,
  loading,
  error,
  className = ''
}) => {
  const formatPercentage = (value: number) => `${value.toFixed(1)}%`;
  const formatCurrency = (value: number) => `₱${(value / 1000000).toFixed(1)}M`;

  if (loading) return <ChartSkeleton height={height} />;
  if (error) return <ChartError message={error} height={height} />;

  const renderChart = () => {
    switch (chartType) {
      case 'pie':
        return (
          <PieChart>
            <Pie
              data={data}
              dataKey="value"
              nameKey="category"
              cx="50%"
              cy="50%"
              outerRadius={100}
              label={({ name, percent }) => `${name} ${(percent * 100).toFixed(1)}%`}
            >
              {data.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={CHART_PALETTE[index % CHART_PALETTE.length]} />
              ))}
            </Pie>
            <Tooltip formatter={(value, name) => [formatCurrency(value as number), name]} />
          </PieChart>
        );
      
      default:
        return (
          <BarChart data={data} margin={{ top: 20, right: 30, left: 20, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
            <XAxis dataKey="category" stroke="#6B7280" fontSize={12} />
            <YAxis stroke="#6B7280" fontSize={12} tickFormatter={formatCurrency} />
            <Tooltip formatter={(value) => formatCurrency(value as number)} />
            <Bar dataKey="value" fill={SCOUT_COLORS.primary} radius={[4, 4, 0, 0]} />
          </BarChart>
        );
    }
  };

  return (
    <div className={className}>
      <ResponsiveContainer width="100%" height={height}>
        {renderChart()}
      </ResponsiveContainer>
    </div>
  );
};

// Market share competitive chart
export interface CompetitiveChartProps extends BaseChartProps {
  competitors: string[];
  metrics: 'market_share' | 'price_comparison' | 'performance';
}

export const CompetitiveChart: React.FC<CompetitiveChartProps> = ({
  data,
  height = 300,
  competitors,
  metrics = 'market_share',
  loading,
  error,
  className = ''
}) => {
  if (loading) return <ChartSkeleton height={height} />;
  if (error) return <ChartError message={error} height={height} />;

  const formatValue = (value: number) => {
    switch (metrics) {
      case 'market_share':
        return `${value.toFixed(1)}%`;
      case 'price_comparison':
        return `₱${value.toLocaleString()}`;
      case 'performance':
        return value.toFixed(1);
      default:
        return value.toString();
    }
  };

  return (
    <div className={className}>
      <ResponsiveContainer width="100%" height={height}>
        <BarChart data={data} layout="horizontal" margin={{ top: 20, right: 30, left: 40, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
          <XAxis type="number" stroke="#6B7280" fontSize={12} tickFormatter={formatValue} />
          <YAxis type="category" dataKey="competitor" stroke="#6B7280" fontSize={12} width={80} />
          <Tooltip formatter={(value) => formatValue(value as number)} />
          <Bar 
            dataKey="value" 
            fill={SCOUT_COLORS.secondary}
            radius={[0, 4, 4, 0]}
          />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
};

// Geographic heatmap data visualization
export interface GeographicChartProps extends BaseChartProps {
  regions: Array<{
    name: string;
    value: number;
    coordinates: [number, number];
  }>;
  metric: 'revenue' | 'stores' | 'growth';
}

export const GeographicChart: React.FC<GeographicChartProps> = ({
  data,
  regions,
  height = 400,
  metric = 'revenue',
  loading,
  error,
  className = ''
}) => {
  if (loading) return <ChartSkeleton height={height} />;
  if (error) return <ChartError message={error} height={height} />;

  const formatMetric = (value: number) => {
    switch (metric) {
      case 'revenue':
        return `₱${(value / 1000000).toFixed(1)}M`;
      case 'stores':
        return `${value} stores`;
      case 'growth':
        return `${value.toFixed(1)}%`;
      default:
        return value.toString();
    }
  };

  return (
    <div className={className}>
      <ResponsiveContainer width="100%" height={height}>
        <ScatterChart data={regions} margin={{ top: 20, right: 20, bottom: 20, left: 20 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
          <XAxis type="number" dataKey="coordinates[0]" name="longitude" hide />
          <YAxis type="number" dataKey="coordinates[1]" name="latitude" hide />
          <Tooltip
            content={({ active, payload }) => {
              if (active && payload && payload.length) {
                const data = payload[0].payload;
                return (
                  <div className="bg-white p-3 border border-gray-200 rounded-lg shadow-lg">
                    <p className="font-medium text-gray-900">{data.name}</p>
                    <p className="text-sm text-gray-600">{formatMetric(data.value)}</p>
                  </div>
                );
              }
              return null;
            }}
          />
          <Scatter 
            dataKey="value" 
            fill={SCOUT_COLORS.primary}
            fillOpacity={0.7}
          />
        </ScatterChart>
      </ResponsiveContainer>
    </div>
  );
};

// Consumer demographics chart
export interface ConsumerDemographicsChartProps extends BaseChartProps {
  demographicType: 'age' | 'income' | 'location' | 'behavior';
}

export const ConsumerDemographicsChart: React.FC<ConsumerDemographicsChartProps> = ({
  data,
  height = 300,
  demographicType = 'age',
  loading,
  error,
  className = ''
}) => {
  if (loading) return <ChartSkeleton height={height} />;
  if (error) return <ChartError message={error} height={height} />;

  return (
    <div className={className}>
      <ResponsiveContainer width="100%" height={height}>
        <AreaChart data={data} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
          <XAxis dataKey="segment" stroke="#6B7280" fontSize={12} />
          <YAxis stroke="#6B7280" fontSize={12} />
          <Tooltip />
          <Area 
            type="monotone" 
            dataKey="value" 
            stroke={SCOUT_COLORS.accent}
            fill={SCOUT_COLORS.accent}
            fillOpacity={0.6}
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
};

// Multi-metric composed chart
export interface ComposedMetricsChartProps extends BaseChartProps {
  primaryMetric: string;
  secondaryMetric: string;
  primaryAxisLabel: string;
  secondaryAxisLabel: string;
}

export const ComposedMetricsChart: React.FC<ComposedMetricsChartProps> = ({
  data,
  height = 350,
  primaryMetric,
  secondaryMetric,
  primaryAxisLabel,
  secondaryAxisLabel,
  loading,
  error,
  className = ''
}) => {
  if (loading) return <ChartSkeleton height={height} />;
  if (error) return <ChartError message={error} height={height} />;

  return (
    <div className={className}>
      <ResponsiveContainer width="100%" height={height}>
        <ComposedChart data={data} margin={{ top: 20, right: 30, left: 20, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
          <XAxis dataKey="period" stroke="#6B7280" fontSize={12} />
          <YAxis yAxisId="left" stroke="#6B7280" fontSize={12} label={{ value: primaryAxisLabel, angle: -90, position: 'insideLeft' }} />
          <YAxis yAxisId="right" orientation="right" stroke="#6B7280" fontSize={12} label={{ value: secondaryAxisLabel, angle: 90, position: 'insideRight' }} />
          <Tooltip />
          <Legend />
          <Bar yAxisId="left" dataKey={primaryMetric} fill={SCOUT_COLORS.primary} name={primaryAxisLabel} />
          <Line yAxisId="right" type="monotone" dataKey={secondaryMetric} stroke={SCOUT_COLORS.secondary} strokeWidth={2} name={secondaryAxisLabel} />
        </ComposedChart>
      </ResponsiveContainer>
    </div>
  );
};

// Loading skeleton component
const ChartSkeleton: React.FC<{ height: number }> = ({ height }) => (
  <div className={`flex items-center justify-center animate-pulse bg-gray-100 rounded-lg`} style={{ height }}>
    <div className="text-center">
      <div className="w-16 h-16 mx-auto bg-gray-300 rounded-full mb-4"></div>
      <div className="w-24 h-4 bg-gray-300 rounded mx-auto mb-2"></div>
      <div className="w-32 h-3 bg-gray-300 rounded mx-auto"></div>
    </div>
  </div>
);

// Error display component
const ChartError: React.FC<{ message: string; height: number }> = ({ message, height }) => (
  <div className={`flex items-center justify-center bg-red-50 border border-red-200 rounded-lg`} style={{ height }}>
    <div className="text-center">
      <div className="text-red-400 text-2xl mb-2">⚠️</div>
      <div className="text-red-800 text-sm font-medium mb-1">Chart Error</div>
      <div className="text-red-600 text-xs">{message}</div>
    </div>
  </div>
);

// Chart container with common styling and functionality
export interface ChartContainerProps {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
  actions?: React.ReactNode;
  loading?: boolean;
  error?: string;
  className?: string;
}

export const ChartContainer: React.FC<ChartContainerProps> = ({
  title,
  subtitle,
  children,
  actions,
  loading,
  error,
  className = ''
}) => (
  <div className={`bg-white rounded-lg border border-gray-200 shadow-sm ${className}`}>
    <div className="flex items-center justify-between p-6 border-b border-gray-100">
      <div>
        <h3 className="text-lg font-semibold text-gray-900">{title}</h3>
        {subtitle && <p className="text-sm text-gray-600 mt-1">{subtitle}</p>}
      </div>
      {actions && <div className="flex items-center space-x-2">{actions}</div>}
    </div>
    <div className="p-6">
      {loading ? (
        <ChartSkeleton height={300} />
      ) : error ? (
        <ChartError message={error} height={300} />
      ) : (
        children
      )}
    </div>
  </div>
);

export default {
  RevenueTrendChart,
  CategoryMixChart,
  CompetitiveChart,
  GeographicChart,
  ConsumerDemographicsChart,
  ComposedMetricsChart,
  ChartContainer
};