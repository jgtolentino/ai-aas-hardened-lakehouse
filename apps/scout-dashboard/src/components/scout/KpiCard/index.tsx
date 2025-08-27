import React from 'react';
import { TrendingUp, TrendingDown, Activity, DollarSign, ShoppingCart, Package } from 'lucide-react';
import { cn } from '@/lib/utils';

export interface KpiCardProps {
  title: string;
  value: string | number;
  change?: number;
  changeType?: 'increase' | 'decrease';
  prefix?: string;
  suffix?: string;
  icon?: 'gmv' | 'transactions' | 'basket' | 'items' | React.ComponentType<any>;
  state?: 'loading' | 'empty' | 'error' | 'ready';
  errorMessage?: string;
  className?: string;
  ariaLabel?: string;
}

const iconMap = {
  gmv: DollarSign,
  transactions: ShoppingCart,
  basket: Activity,
  items: Package,
};

export const KpiCard: React.FC<KpiCardProps> = ({
  title,
  value,
  change,
  changeType = 'increase',
  prefix = '',
  suffix = '',
  icon,
  state = 'ready',
  errorMessage = 'Failed to load data',
  className,
  ariaLabel,
}) => {
  const Icon = typeof icon === 'string' ? iconMap[icon] : icon;
  const isPositive = changeType === 'increase';
  const TrendIcon = isPositive ? TrendingUp : TrendingDown;

  // Loading state
  if (state === 'loading') {
    return (
      <div
        className={cn(
          'bg-white rounded-lg border border-gray-200 p-6 animate-pulse',
          className
        )}
        role="status"
        aria-label={`Loading ${title}`}
      >
        <div className="flex justify-between items-start mb-4">
          <div className="h-4 w-24 bg-gray-200 rounded" />
          <div className="h-6 w-6 bg-gray-200 rounded" />
        </div>
        <div className="h-8 w-32 bg-gray-200 rounded mb-2" />
        <div className="h-4 w-16 bg-gray-200 rounded" />
      </div>
    );
  }

  // Error state
  if (state === 'error') {
    return (
      <div
        className={cn(
          'bg-white rounded-lg border border-red-200 p-6',
          className
        )}
        role="alert"
        aria-label={`Error loading ${title}`}
      >
        <div className="flex justify-between items-start mb-4">
          <h3 className="text-sm font-medium text-gray-500">{title}</h3>
          <div className="text-red-500">⚠️</div>
        </div>
        <p className="text-sm text-red-600">{errorMessage}</p>
      </div>
    );
  }

  // Empty state
  if (state === 'empty') {
    return (
      <div
        className={cn(
          'bg-white rounded-lg border border-gray-200 p-6',
          className
        )}
        aria-label={ariaLabel || `${title}: No data available`}
      >
        <div className="flex justify-between items-start mb-4">
          <h3 className="text-sm font-medium text-gray-500">{title}</h3>
          {Icon && <Icon className="h-5 w-5 text-gray-400" />}
        </div>
        <div className="text-2xl font-bold text-gray-400">--</div>
        <p className="text-xs text-gray-400 mt-2">No data available</p>
      </div>
    );
  }

  // Ready state (default)
  return (
    <div
      className={cn(
        'bg-white rounded-lg border border-gray-200 p-6 hover:border-gray-300 transition-colors',
        className
      )}
      aria-label={ariaLabel || `${title}: ${prefix}${value}${suffix}, ${changeType} of ${Math.abs(change || 0)}%`}
    >
      <div className="flex justify-between items-start mb-4">
        <h3 className="text-sm font-medium text-gray-500">{title}</h3>
        {Icon && <Icon className="h-5 w-5 text-gray-400" />}
      </div>
      
      <div className="flex items-baseline justify-between">
        <div>
          <span className="text-2xl font-bold text-gray-900">
            {prefix}{value}{suffix}
          </span>
        </div>
      </div>

      {change !== undefined && (
        <div className="flex items-center mt-2 space-x-1">
          <TrendIcon
            className={cn(
              'h-4 w-4',
              isPositive ? 'text-green-500' : 'text-red-500'
            )}
          />
          <span
            className={cn(
              'text-sm font-medium',
              isPositive ? 'text-green-600' : 'text-red-600'
            )}
          >
            {Math.abs(change)}%
          </span>
        </div>
      )}
    </div>
  );
};

export default KpiCard;
