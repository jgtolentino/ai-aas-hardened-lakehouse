import React from 'react';
import { Skeleton } from '../Skeleton';

export interface KpiCardProps {
  title: string;
  value?: number | string;
  loading?: boolean;
  error?: string;
  trend?: {
    value: number;
    direction: 'up' | 'down' | 'neutral';
  };
  metric?: string;
  className?: string;
}

export const KpiCard: React.FC<KpiCardProps> = ({
  title,
  value,
  loading,
  error,
  trend,
  metric,
  className = '',
}) => {
  if (loading) {
    return (
      <div className={`bg-white rounded-lg p-4 shadow-sm ${className}`}>
        <Skeleton className="h-4 w-24 mb-2" />
        <Skeleton className="h-8 w-32" />
      </div>
    );
  }

  if (error) {
    return (
      <div className={`bg-white rounded-lg p-4 shadow-sm border border-red-200 ${className}`}>
        <p className="text-sm text-gray-600">{title}</p>
        <p className="text-sm text-red-600 mt-1">Error loading data</p>
      </div>
    );
  }

  const formatValue = (val: number | string | undefined) => {
    if (val === undefined) return '--';
    if (typeof val === 'number') {
      if (metric === 'revenue') {
        return new Intl.NumberFormat('en-US', {
          style: 'currency',
          currency: 'PHP',
          minimumFractionDigits: 0,
        }).format(val);
      }
      return new Intl.NumberFormat('en-US').format(val);
    }
    return val;
  };

  const getTrendIcon = () => {
    if (!trend) return null;
    if (trend.direction === 'up') {
      return (
        <span className="text-green-600">↑ {Math.abs(trend.value)}%</span>
      );
    }
    if (trend.direction === 'down') {
      return (
        <span className="text-red-600">↓ {Math.abs(trend.value)}%</span>
      );
    }
    return <span className="text-gray-500">→ 0%</span>;
  };

  return (
    <div className={`bg-white rounded-lg p-4 shadow-sm hover:shadow-md transition-shadow ${className}`}>
      <p className="text-sm text-gray-600 mb-1">{title}</p>
      <p className="text-2xl font-bold text-gray-900">{formatValue(value)}</p>
      {trend && (
        <div className="mt-2 text-sm">
          {getTrendIcon()}
        </div>
      )}
    </div>
  );
};

export default KpiCard;
