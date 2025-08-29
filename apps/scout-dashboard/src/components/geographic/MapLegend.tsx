import React from 'react';
import { COLOR_SCHEMES } from '@/lib/mapbox';
import { cn } from '@/lib/utils';

export type LegendType = 'choropleth' | 'point_density' | 'cluster_size' | 'heatmap';

interface LegendItem {
  color: string;
  label: string;
  value?: string | number;
  description?: string;
}

interface MapLegendProps {
  type: LegendType;
  title?: string;
  metric?: 'sales' | 'customers' | 'visits' | 'revenue';
  className?: string;
  position?: 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right';
  collapsible?: boolean;
  showDataInfo?: boolean;
  customItems?: LegendItem[];
}

interface LegendHeaderProps {
  title: string;
  collapsible?: boolean;
  isCollapsed?: boolean;
  onToggle?: () => void;
}

const LegendHeader: React.FC<LegendHeaderProps> = ({ 
  title, 
  collapsible, 
  isCollapsed, 
  onToggle 
}) => (
  <div className="flex items-center justify-between mb-3">
    <h4 className="font-semibold text-sm text-gray-900">{title}</h4>
    {collapsible && (
      <button
        onClick={onToggle}
        className="p-1 hover:bg-gray-100 rounded"
        aria-label={isCollapsed ? "Expand legend" : "Collapse legend"}
      >
        <svg 
          className={cn("w-4 h-4 text-gray-500 transition-transform", {
            "rotate-180": !isCollapsed
          })} 
          fill="none" 
          stroke="currentColor" 
          viewBox="0 0 24 24"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>
    )}
  </div>
);

interface LegendItemComponentProps {
  item: LegendItem;
  shape?: 'circle' | 'square' | 'line';
}

const LegendItemComponent: React.FC<LegendItemComponentProps> = ({ 
  item, 
  shape = 'circle' 
}) => (
  <div className="flex items-center space-x-2 text-xs">
    <div 
      className={cn("flex-shrink-0", {
        "w-3 h-3 rounded-full": shape === 'circle',
        "w-3 h-3": shape === 'square',
        "w-4 h-1": shape === 'line'
      })}
      style={{ backgroundColor: item.color }}
    />
    <div className="min-w-0 flex-1">
      <div className="text-gray-700 font-medium">{item.label}</div>
      {item.value && (
        <div className="text-gray-500 text-xs">{item.value}</div>
      )}
      {item.description && (
        <div className="text-gray-400 text-xs mt-1">{item.description}</div>
      )}
    </div>
  </div>
);

interface DataInfoProps {
  metric?: string;
  totalPoints?: number;
  dateRange?: string;
}

const DataInfo: React.FC<DataInfoProps> = ({ metric, totalPoints, dateRange }) => (
  <div className="mt-3 pt-3 border-t border-gray-200 text-xs text-gray-500">
    {metric && <div>Metric: {metric.charAt(0).toUpperCase() + metric.slice(1)}</div>}
    {totalPoints && <div>Data Points: {totalPoints.toLocaleString()}</div>}
    {dateRange && <div>Period: {dateRange}</div>}
  </div>
);

const getLegendItems = (type: LegendType, metric?: string): LegendItem[] => {
  const metricLabel = metric ? metric.charAt(0).toUpperCase() + metric.slice(1) : 'Value';
  
  switch (type) {
    case 'choropleth':
      return [
        { color: COLOR_SCHEMES.SALES_HEATMAP[0], label: 'Very Low', value: '0-10%' },
        { color: COLOR_SCHEMES.SALES_HEATMAP[2], label: 'Low', value: '10-25%' },
        { color: COLOR_SCHEMES.SALES_HEATMAP[4], label: 'Medium', value: '25-50%' },
        { color: COLOR_SCHEMES.SALES_HEATMAP[6], label: 'High', value: '50-75%' },
        { color: COLOR_SCHEMES.SALES_HEATMAP[7], label: 'Very High', value: '75-100%' },
      ];
    
    case 'point_density':
      return [
        { color: COLOR_SCHEMES.SALES_HEATMAP[1], label: 'Low Density', value: '1-10 points/km²' },
        { color: COLOR_SCHEMES.SALES_HEATMAP[3], label: 'Medium Density', value: '10-50 points/km²' },
        { color: COLOR_SCHEMES.SALES_HEATMAP[5], label: 'High Density', value: '50+ points/km²' },
      ];
    
    case 'cluster_size':
      return [
        { color: COLOR_SCHEMES.SALES_HEATMAP[2], label: 'Small Cluster', value: '2-10 points' },
        { color: COLOR_SCHEMES.SALES_HEATMAP[4], label: 'Medium Cluster', value: '10-50 points' },
        { color: COLOR_SCHEMES.SALES_HEATMAP[6], label: 'Large Cluster', value: '50+ points' },
      ];
    
    case 'heatmap':
      return [
        { color: COLOR_SCHEMES.SALES_HEATMAP[0], label: 'Lowest', description: `Minimal ${metricLabel.toLowerCase()}` },
        { color: COLOR_SCHEMES.SALES_HEATMAP[2], label: 'Below Average' },
        { color: COLOR_SCHEMES.SALES_HEATMAP[4], label: 'Average' },
        { color: COLOR_SCHEMES.SALES_HEATMAP[6], label: 'Above Average' },
        { color: COLOR_SCHEMES.SALES_HEATMAP[7], label: 'Highest', description: `Peak ${metricLabel.toLowerCase()}` },
      ];
    
    default:
      return [];
  }
};

const getLegendTitle = (type: LegendType, metric?: string): string => {
  const metricLabel = metric ? metric.charAt(0).toUpperCase() + metric.slice(1) : 'Data';
  
  switch (type) {
    case 'choropleth':
      return `${metricLabel} Distribution`;
    case 'point_density':
      return 'Point Density';
    case 'cluster_size':
      return 'Cluster Size';
    case 'heatmap':
      return `${metricLabel} Intensity`;
    default:
      return 'Legend';
  }
};

export const MapLegend: React.FC<MapLegendProps> = ({
  type,
  title,
  metric,
  className,
  position = 'bottom-left',
  collapsible = false,
  showDataInfo = false,
  customItems
}) => {
  const [isCollapsed, setIsCollapsed] = React.useState(false);

  const positionClasses = {
    'top-left': 'top-4 left-4',
    'top-right': 'top-4 right-4',
    'bottom-left': 'bottom-4 left-4',
    'bottom-right': 'bottom-4 right-4',
  };

  const legendTitle = title || getLegendTitle(type, metric);
  const legendItems = customItems || getLegendItems(type, metric);
  const shape = type === 'choropleth' ? 'square' : 'circle';

  if (legendItems.length === 0) return null;

  return (
    <div className={cn(
      "absolute z-10 bg-white bg-opacity-95 backdrop-blur-sm rounded-lg shadow-lg border p-3 min-w-48 max-w-64",
      positionClasses[position],
      className
    )}>
      <LegendHeader
        title={legendTitle}
        collapsible={collapsible}
        isCollapsed={isCollapsed}
        onToggle={() => setIsCollapsed(!isCollapsed)}
      />
      
      {!isCollapsed && (
        <>
          <div className="space-y-2">
            {legendItems.map((item, index) => (
              <LegendItemComponent
                key={index}
                item={item}
                shape={shape}
              />
            ))}
          </div>
          
          {showDataInfo && (
            <DataInfo
              metric={metric}
              totalPoints={undefined} // Could be passed as prop
              dateRange={undefined} // Could be passed as prop
            />
          )}
        </>
      )}
    </div>
  );
};

// Specialized legend components
export const ChoroplethLegend: React.FC<Omit<MapLegendProps, 'type'>> = (props) => (
  <MapLegend {...props} type="choropleth" />
);

export const PointDensityLegend: React.FC<Omit<MapLegendProps, 'type'>> = (props) => (
  <MapLegend {...props} type="point_density" />
);

export const ClusterLegend: React.FC<Omit<MapLegendProps, 'type'>> = (props) => (
  <MapLegend {...props} type="cluster_size" />
);

export const HeatmapLegend: React.FC<Omit<MapLegendProps, 'type'>> = (props) => (
  <MapLegend {...props} type="heatmap" />
);

export default MapLegend;