import React, { useState, useEffect } from 'react';
import { ChartCard } from '../ChartCard/ChartCard';
import { DataTable } from '../DataTable/DataTable';
import { KpiTile } from '../Kpi/KpiTile';
import { FilterPanel } from '../FilterPanel/FilterPanel';

export interface ComponentUsageStats {
  component_id: string;
  component_name: string;
  component_type: string;
  library_name: string;
  total_usage: number;
  teams_using: number;
  files_using: number;
  detachment_rate: number;
  trend: 'up' | 'down' | 'stable';
  last_used: string;
}

export interface DesignInsight {
  component_id: string;
  component_name: string;
  insight_type: string;
  insight_message: string;
  insight_priority: 'high' | 'medium' | 'low' | 'info';
  total_usage: number;
  detachment_rate: number;
}

export interface DesignAnalyticsDashboardProps {
  className?: string;
}

export const DesignAnalyticsDashboard: React.FC<DesignAnalyticsDashboardProps> = ({
  className = ''
}) => {
  const [componentStats, setComponentStats] = useState<ComponentUsageStats[]>([]);
  const [insights, setInsights] = useState<DesignInsight[]>([]);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState({
    library: 'all',
    timeRange: 'last30days',
    componentType: 'all'
  });

  // Mock data - replace with actual Supabase queries
  useEffect(() => {
    const mockData: ComponentUsageStats[] = [
      {
        component_id: 'kpi-tile',
        component_name: 'KPI Tile',
        component_type: 'atom',
        library_name: 'scout-ui',
        total_usage: 143,
        teams_using: 8,
        files_using: 12,
        detachment_rate: 5.6,
        trend: 'up',
        last_used: '2024-08-28T10:30:00Z'
      },
      {
        component_id: 'data-table',
        component_name: 'Data Table',
        component_type: 'organism',
        library_name: 'scout-ui',
        total_usage: 89,
        teams_using: 6,
        files_using: 15,
        detachment_rate: 12.4,
        trend: 'stable',
        last_used: '2024-08-27T16:45:00Z'
      },
      {
        component_id: 'chart-card',
        component_name: 'Chart Card',
        component_type: 'molecule',
        library_name: 'scout-ui',
        total_usage: 67,
        teams_using: 4,
        files_using: 8,
        detachment_rate: 23.5,
        trend: 'down',
        last_used: '2024-08-26T14:20:00Z'
      },
      {
        component_id: 'filter-panel',
        component_name: 'Filter Panel',
        component_type: 'organism',
        library_name: 'scout-ui',
        total_usage: 34,
        teams_using: 3,
        files_using: 6,
        detachment_rate: 8.8,
        trend: 'up',
        last_used: '2024-08-28T09:15:00Z'
      }
    ];

    const mockInsights: DesignInsight[] = [
      {
        component_id: 'chart-card',
        component_name: 'Chart Card',
        insight_type: 'high_detachment',
        insight_message: 'Component has high detachment rate (23.5%). Consider updating default props or creating variants.',
        insight_priority: 'high',
        total_usage: 67,
        detachment_rate: 23.5
      },
      {
        component_id: 'data-table',
        component_name: 'Data Table',
        insight_type: 'frequently_overridden',
        insight_message: 'Component is frequently overridden. Consider adding more variant options.',
        insight_priority: 'medium',
        total_usage: 89,
        detachment_rate: 12.4
      }
    ];

    setTimeout(() => {
      setComponentStats(mockData);
      setInsights(mockInsights);
      setLoading(false);
    }, 1000);
  }, [filters]);

  const totalComponents = componentStats.length;
  const avgUsage = componentStats.reduce((sum, comp) => sum + comp.total_usage, 0) / totalComponents || 0;
  const avgDetachmentRate = componentStats.reduce((sum, comp) => sum + comp.detachment_rate, 0) / totalComponents || 0;
  const activeComponents = componentStats.filter(comp => comp.total_usage > 0).length;

  const usageTrendData = componentStats.map(comp => ({
    component: comp.component_name,
    usage: comp.total_usage,
    trend: comp.trend
  }));

  const detachmentData = componentStats.map(comp => ({
    component: comp.component_name,
    detachment_rate: comp.detachment_rate,
    usage: comp.total_usage
  }));

  const componentTableColumns = [
    {
      key: 'component_name',
      label: 'Component',
      sortable: true,
      render: (value: string, row: ComponentUsageStats) => (
        <div>
          <div className="font-medium">{value}</div>
          <div className="text-sm text-gray-500">{row.component_type} • {row.library_name}</div>
        </div>
      )
    },
    {
      key: 'total_usage',
      label: 'Usage',
      sortable: true,
      render: (value: number) => (
        <span className="font-mono">{value.toLocaleString()}</span>
      )
    },
    {
      key: 'teams_using',
      label: 'Teams',
      sortable: true
    },
    {
      key: 'detachment_rate',
      label: 'Detachment Rate',
      sortable: true,
      render: (value: number) => (
        <span className={`font-mono ${value > 15 ? 'text-red-600' : value > 10 ? 'text-yellow-600' : 'text-green-600'}`}>
          {value.toFixed(1)}%
        </span>
      )
    },
    {
      key: 'trend',
      label: 'Trend',
      render: (value: string) => {
        const icons = { up: '📈', down: '📉', stable: '➡️' };
        const colors = { up: 'text-green-600', down: 'text-red-600', stable: 'text-gray-500' };
        return (
          <span className={colors[value as keyof typeof colors]}>
            {icons[value as keyof typeof icons]} {value}
          </span>
        );
      }
    }
  ];

  const insightTableColumns = [
    {
      key: 'component_name',
      label: 'Component',
      sortable: true
    },
    {
      key: 'insight_priority',
      label: 'Priority',
      render: (value: string) => {
        const colors = {
          high: 'bg-red-100 text-red-800',
          medium: 'bg-yellow-100 text-yellow-800',
          low: 'bg-blue-100 text-blue-800',
          info: 'bg-gray-100 text-gray-800'
        };
        return (
          <span className={`px-2 py-1 rounded-full text-xs font-medium ${colors[value as keyof typeof colors]}`}>
            {value.toUpperCase()}
          </span>
        );
      }
    },
    {
      key: 'insight_message',
      label: 'Insight',
      render: (value: string) => (
        <div className="text-sm">{value}</div>
      )
    }
  ];

  const filterOptions = [
    {
      key: 'library',
      label: 'Library',
      type: 'select' as const,
      options: [
        { value: 'all', label: 'All Libraries' },
        { value: 'scout-ui', label: 'Scout UI' },
        { value: 'core-ui', label: 'Core UI' }
      ],
      placeholder: 'Select library'
    },
    {
      key: 'timeRange',
      label: 'Time Range',
      type: 'select' as const,
      options: [
        { value: 'last7days', label: 'Last 7 days' },
        { value: 'last30days', label: 'Last 30 days' },
        { value: 'last90days', label: 'Last 90 days' },
        { value: 'lastyear', label: 'Last year' }
      ],
      placeholder: 'Select time range'
    },
    {
      key: 'componentType',
      label: 'Component Type',
      type: 'select' as const,
      options: [
        { value: 'all', label: 'All Types' },
        { value: 'atom', label: 'Atoms' },
        { value: 'molecule', label: 'Molecules' },
        { value: 'organism', label: 'Organisms' },
        { value: 'template', label: 'Templates' }
      ],
      placeholder: 'Select component type'
    }
  ];

  return (
    <div className={`design-analytics-dashboard space-y-6 ${className}`}>
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">Design System Analytics</h1>
          <p className="text-gray-600">Monitor component usage, adoption, and health across teams</p>
        </div>
      </div>

      {/* Filters */}
      <FilterPanel
        title="Analytics Filters"
        filters={filterOptions}
        values={filters}
        onFilterChange={(key, value) => setFilters(prev => ({ ...prev, [key]: value }))}
        onApplyFilters={() => {}}
        onResetFilters={() => setFilters({ library: 'all', timeRange: 'last30days', componentType: 'all' })}
      />

      {/* KPIs */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiTile
          label="Total Components"
          value={totalComponents.toString()}
          hint="In design system"
          state={loading ? 'loading' : 'default'}
        />
        <KpiTile
          label="Active Components"
          value={activeComponents.toString()}
          delta={((activeComponents / totalComponents - 1) * 100)}
          hint="Components with usage > 0"
          state={loading ? 'loading' : 'default'}
        />
        <KpiTile
          label="Avg Usage"
          value={avgUsage.toFixed(0)}
          hint="Per component"
          state={loading ? 'loading' : 'default'}
        />
        <KpiTile
          label="Avg Detachment Rate"
          value={`${avgDetachmentRate.toFixed(1)}%`}
          delta={avgDetachmentRate > 15 ? (15 - avgDetachmentRate) : (avgDetachmentRate - 15)}
          hint="Lower is better"
          state={loading ? 'loading' : 'default'}
        />
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <ChartCard
          title="Component Usage Trends"
          subtitle="Usage by component over time"
          chartType="bar"
          data={usageTrendData}
          loading={loading}
          height={300}
          showLegend={true}
        />
        <ChartCard
          title="Detachment Rates"
          subtitle="Component detachment rates vs usage"
          chartType="scatter"
          data={detachmentData}
          loading={loading}
          height={300}
          showLegend={false}
        />
      </div>

      {/* Tables */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
        {/* Component Stats */}
        <div>
          <h2 className="text-lg font-medium text-gray-900 mb-4">Component Statistics</h2>
          <DataTable
            data={componentStats}
            columns={componentTableColumns}
            loading={loading}
            searchable={true}
            pagination={true}
            pageSize={10}
          />
        </div>

        {/* Insights */}
        <div>
          <h2 className="text-lg font-medium text-gray-900 mb-4">Design System Insights</h2>
          <DataTable
            data={insights}
            columns={insightTableColumns}
            loading={loading}
            searchable={false}
            pagination={false}
          />
        </div>
      </div>

      {/* AI Insights Panel */}
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
        <h3 className="text-sm font-medium text-blue-900 mb-2">🤖 AI Design System Insights</h3>
        <ul className="space-y-2 text-sm text-blue-800">
          <li>• Chart Card shows high detachment rate - consider creating size and style variants</li>
          <li>• KPI Tile has excellent adoption - promote as a success pattern to other teams</li>
          <li>• Filter Panel is underused - add to component spotlight in next design review</li>
          <li>• Overall system health: 🟢 Good (87/100) - focus on reducing detachment rates</li>
        </ul>
      </div>
    </div>
  );
};

export default DesignAnalyticsDashboard;