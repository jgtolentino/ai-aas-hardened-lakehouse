import React from 'react';
import { KpiTile, DataTable, ChartCard, FilterPanel } from '../';

export interface DashboardContainerProps {
  title: string;
  loading?: boolean;
  data?: Record<string, any[]>;
  filters?: Record<string, any>;
  onFilterChange?: (key: string, value: any) => void;
}

export const DashboardContainer: React.FC<DashboardContainerProps> = ({
  title,
  loading = false,
  data = {},
  filters = {},
  onFilterChange
}) => {
  return (
    <div className="dashboard-container">
      <header className="dashboard-header">
        <h1 className="text-2xl font-semibold text-gray-900">{title}</h1>
        <div className="dashboard-filters">
          {/* Filters would go here */}
        </div>
      </header>
      
      <div className="dashboard-grid grid grid-cols-12 gap-4 p-6">
        
        <div className="col-span-6" style={{gridRow: '1 / span 4'}}>
          <ChartCard
            title="Revenue Trend"
            chartType="line"
            data={data['chart_101'] || []}
            loading={loading}
          />
        </div>
        <div className="col-span-6" style={{gridRow: '1 / span 4'}}>
          <ChartCard
            title="Campaign Performance"
            chartType="bar"
            data={data['chart_102'] || []}
            loading={loading}
          />
        </div>
        <div className="col-span-4" style={{gridRow: '5 / span 3'}}>
          <KpiTile
            label="Customer Satisfaction"
            value={data['chart_103']?.[0]?.value || '₱0'}
            delta={data['chart_103']?.[0]?.delta || 0}
            state={loading ? 'loading' : 'default'}
          />
        </div>
        <div className="col-span-8" style={{gridRow: '5 / span 3'}}>
          <div className="p-4 border rounded-lg bg-gray-50">
            <h3 className="font-medium">Regional Performance</h3>
            <p className="text-sm text-gray-500">Component: choropleth</p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default DashboardContainer;