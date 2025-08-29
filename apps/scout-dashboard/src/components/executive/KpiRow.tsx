import React from 'react';
import { cn } from '@/lib/utils';

interface KpiMetric {
  id: string;
  title: string;
  value: number | string;
  previousValue?: number | string;
  unit?: string;
  trend?: 'up' | 'down' | 'neutral';
  change?: number;
  changeType?: 'percentage' | 'absolute';
  isLoading?: boolean;
  format?: 'currency' | 'number' | 'percentage';
}

interface KpiRowProps {
  metrics: KpiMetric[];
  className?: string;
  variant?: 'default' | 'compact' | 'detailed';
}

interface KpiTileProps {
  metric: KpiMetric;
  variant?: 'default' | 'compact' | 'detailed';
}

const LoadingSkeleton: React.FC<{ variant?: string }> = ({ variant }) => (
  <div className={cn(
    "animate-pulse bg-gray-200 rounded",
    variant === 'compact' ? "h-16" : "h-24"
  )}>
    <div className="p-4 space-y-2">
      <div className="h-3 bg-gray-300 rounded w-20"></div>
      <div className="h-6 bg-gray-300 rounded w-16"></div>
      {variant !== 'compact' && (
        <div className="h-3 bg-gray-300 rounded w-12"></div>
      )}
    </div>
  </div>
);

const formatValue = (value: number | string, format?: string, unit?: string): string => {
  if (typeof value === 'string') return value;
  
  switch (format) {
    case 'currency':
      return new Intl.NumberFormat('en-PH', {
        style: 'currency',
        currency: 'PHP',
        minimumFractionDigits: 0,
        maximumFractionDigits: 0,
      }).format(value);
    case 'percentage':
      return `${value.toFixed(1)}%`;
    case 'number':
      return new Intl.NumberFormat('en-PH').format(value);
    default:
      return unit ? `${value.toLocaleString()}${unit}` : value.toLocaleString();
  }
};

const getTrendIcon = (trend?: 'up' | 'down' | 'neutral') => {
  switch (trend) {
    case 'up':
      return (
        <svg className="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
        </svg>
      );
    case 'down':
      return (
        <svg className="w-4 h-4 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 17h8m0 0V9m0 8l-8-8-4 4-6-6" />
        </svg>
      );
    case 'neutral':
      return (
        <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 12H4" />
        </svg>
      );
    default:
      return null;
  }
};

const KpiTile: React.FC<KpiTileProps> = ({ metric, variant = 'default' }) => {
  if (metric.isLoading) {
    return <LoadingSkeleton variant={variant} />;
  }

  const isCompact = variant === 'compact';
  const isDetailed = variant === 'detailed';

  return (
    <div
      className={cn(
        "bg-white rounded-lg border border-gray-200 p-4 shadow-sm hover:shadow-md transition-shadow",
        isCompact && "p-3",
        isDetailed && "p-6"
      )}
      role="article"
      aria-labelledby={`kpi-title-${metric.id}`}
      aria-describedby={`kpi-value-${metric.id}`}
    >
      <div className="flex items-start justify-between">
        <div className="flex-1">
          <h3
            id={`kpi-title-${metric.id}`}
            className={cn(
              "font-medium text-gray-600 text-sm mb-2",
              isCompact && "text-xs mb-1",
              isDetailed && "text-base mb-3"
            )}
          >
            {metric.title}
          </h3>
          
          <div className="flex items-baseline gap-2 mb-1">
            <span
              id={`kpi-value-${metric.id}`}
              className={cn(
                "text-2xl font-bold text-gray-900",
                isCompact && "text-xl",
                isDetailed && "text-3xl"
              )}
              aria-live="polite"
            >
              {formatValue(metric.value, metric.format, metric.unit)}
            </span>
            
            {metric.trend && getTrendIcon(metric.trend)}
          </div>

          {!isCompact && metric.change !== undefined && (
            <div className="flex items-center gap-1">
              <span
                className={cn(
                  "text-xs font-medium",
                  metric.trend === 'up' && "text-green-600",
                  metric.trend === 'down' && "text-red-600",
                  metric.trend === 'neutral' && "text-gray-500"
                )}
                aria-label={`Change from previous period: ${metric.change}${metric.changeType === 'percentage' ? '%' : ''}`}
              >
                {metric.changeType === 'percentage' && (metric.change > 0 ? '+' : '')}
                {metric.change}
                {metric.changeType === 'percentage' ? '%' : ''}
              </span>
              <span className="text-xs text-gray-500">vs previous</span>
            </div>
          )}

          {isDetailed && metric.previousValue !== undefined && (
            <div className="mt-2 pt-2 border-t border-gray-100">
              <span className="text-xs text-gray-500">
                Previous: {formatValue(metric.previousValue, metric.format, metric.unit)}
              </span>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export const KpiRow: React.FC<KpiRowProps> = ({ 
  metrics, 
  className, 
  variant = 'default' 
}) => {
  return (
    <div
      className={cn(
        "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4",
        variant === 'compact' && "gap-3",
        variant === 'detailed' && "gap-6 lg:grid-cols-3",
        className
      )}
      role="region"
      aria-label="Key Performance Indicators"
    >
      {metrics.map((metric) => (
        <KpiTile
          key={metric.id}
          metric={metric}
          variant={variant}
        />
      ))}
    </div>
  );
};

export default KpiRow;
export type { KpiMetric, KpiRowProps };