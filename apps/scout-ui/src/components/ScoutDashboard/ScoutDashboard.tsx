import React, { useState, useEffect } from 'react';
import { ChartCard } from '../ChartCard/ChartCard';
import { DataTable } from '../DataTable/DataTable';
import { KpiTile } from '../Kpi/KpiTile';
import { FilterPanel } from '../FilterPanel/FilterPanel';

// Scout-specific data interfaces
export interface ScoutMetric {
  id: string;
  label: string;
  value: string;
  trend?: {
    value: number;
    direction: 'up' | 'down' | 'stable';
  };
  currency?: string;
  format?: 'currency' | 'percentage' | 'number' | 'duration';
}

export interface ScoutCampaign {
  id: string;
  campaign_name: string;
  client: string;
  status: 'active' | 'paused' | 'completed' | 'draft';
  budget: number;
  spend: number;
  performance_score: number;
  start_date: string;
  end_date: string;
  created_at: string;
}

export interface ScoutRegionalData {
  region: string;
  country: string;
  total_sales: number;
  campaign_count: number;
  performance_rating: number;
}

export interface ScoutDashboardProps {
  className?: string;
  timeRange?: '7d' | '30d' | '90d' | '1y';
  department?: 'all' | 'creative' | 'account' | 'strategy';
}

export const ScoutDashboard: React.FC<ScoutDashboardProps> = ({
  className = '',
  timeRange = '30d',
  department = 'all'
}) => {
  const [metrics, setMetrics] = useState<ScoutMetric[]>([]);
  const [campaigns, setCampaigns] = useState<ScoutCampaign[]>([]);
  const [regionalData, setRegionalData] = useState<ScoutRegionalData[]>([]);
  const [revenueData, setRevenueData] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  
  const [filters, setFilters] = useState({
    timeRange: timeRange,
    department: department,
    client: 'all',
    status: 'all'
  });

  // Mock data for Scout Dashboard - replace with actual Supabase queries
  useEffect(() => {
    const mockMetrics: ScoutMetric[] = [
      {
        id: 'total_revenue',
        label: 'Total Revenue',
        value: '2,847,350',
        trend: { value: 12.5, direction: 'up' },
        currency: '₱',
        format: 'currency'
      },
      {
        id: 'active_campaigns',
        label: 'Active Campaigns',
        value: '24',
        trend: { value: 8.3, direction: 'up' },
        format: 'number'
      },
      {
        id: 'client_satisfaction',
        label: 'Client Satisfaction',
        value: '94.2',
        trend: { value: 2.1, direction: 'up' },
        format: 'percentage'
      },
      {
        id: 'avg_campaign_roi',
        label: 'Avg Campaign ROI',
        value: '385',
        trend: { value: -5.2, direction: 'down' },
        format: 'percentage'
      }
    ];

    const mockCampaigns: ScoutCampaign[] = [
      {
        id: 'camp_001',
        campaign_name: 'Globe 5G Digital Push',
        client: 'Globe Telecom',
        status: 'active',
        budget: 850000,
        spend: 680000,
        performance_score: 92.5,
        start_date: '2024-07-15',
        end_date: '2024-09-30',
        created_at: '2024-07-10T09:00:00Z'
      },
      {
        id: 'camp_002',
        campaign_name: 'Jollibee Holiday Campaign',
        client: 'Jollibee Foods Corporation',
        status: 'active',
        budget: 1200000,
        spend: 950000,
        performance_score: 87.8,
        start_date: '2024-08-01',
        end_date: '2024-12-25',
        created_at: '2024-07-25T14:30:00Z'
      },
      {
        id: 'camp_003',
        campaign_name: 'SM Mall Brand Refresh',
        client: 'SM Prime Holdings',
        status: 'completed',
        budget: 650000,
        spend: 625000,
        performance_score: 95.2,
        start_date: '2024-06-01',
        end_date: '2024-08-15',
        created_at: '2024-05-20T11:15:00Z'
      }
    ];

    const mockRevenueData = [
      { month: 'Jan', revenue: 2150000, campaigns: 18 },
      { month: 'Feb', revenue: 2350000, campaigns: 22 },
      { month: 'Mar', revenue: 2680000, campaigns: 25 },
      { month: 'Apr', revenue: 2420000, campaigns: 21 },
      { month: 'May', revenue: 2890000, campaigns: 28 },
      { month: 'Jun', revenue: 3150000, campaigns: 32 },
      { month: 'Jul', revenue: 2947000, campaigns: 29 },
      { month: 'Aug', revenue: 3250000, campaigns: 35 }
    ];

    const mockRegionalData: ScoutRegionalData[] = [
      { region: 'Metro Manila', country: 'Philippines', total_sales: 12500000, campaign_count: 45, performance_rating: 94.2 },
      { region: 'Cebu', country: 'Philippines', total_sales: 8200000, campaign_count: 28, performance_rating: 89.5 },
      { region: 'Davao', country: 'Philippines', total_sales: 6800000, campaign_count: 22, performance_rating: 91.8 },
      { region: 'Bangkok', country: 'Thailand', total_sales: 15200000, campaign_count: 38, performance_rating: 87.3 },
      { region: 'Ho Chi Minh', country: 'Vietnam', total_sales: 9600000, campaign_count: 31, performance_rating: 92.1 }
    ];

    // Simulate API loading
    setTimeout(() => {
      setMetrics(mockMetrics);
      setCampaigns(mockCampaigns);
      setRevenueData(mockRevenueData);
      setRegionalData(mockRegionalData);
      setLoading(false);
    }, 1200);
  }, [filters]);

  // Campaign performance data for charts
  const campaignPerformanceData = campaigns.map(campaign => ({
    name: campaign.campaign_name.split(' ').slice(0, 2).join(' '), // Shortened names
    performance: campaign.performance_score,
    budget: campaign.budget,
    spend: campaign.spend,
    roi: ((campaign.budget - campaign.spend) / campaign.spend * 100)
  }));

  // Filter panel configuration
  const filterOptions = [
    {
      key: 'timeRange',
      label: 'Time Range',
      type: 'select' as const,
      options: [
        { value: '7d', label: 'Last 7 days' },
        { value: '30d', label: 'Last 30 days' },
        { value: '90d', label: 'Last 90 days' },
        { value: '1y', label: 'Last year' }
      ],
      placeholder: 'Select time range'
    },
    {
      key: 'department',
      label: 'Department',
      type: 'select' as const,
      options: [
        { value: 'all', label: 'All Departments' },
        { value: 'creative', label: 'Creative' },
        { value: 'account', label: 'Account Management' },
        { value: 'strategy', label: 'Strategy' }
      ],
      placeholder: 'Select department'
    },
    {
      key: 'client',
      label: 'Client',
      type: 'select' as const,
      options: [
        { value: 'all', label: 'All Clients' },
        { value: 'globe', label: 'Globe Telecom' },
        { value: 'jollibee', label: 'Jollibee Foods' },
        { value: 'sm', label: 'SM Prime Holdings' }
      ],
      placeholder: 'Select client'
    }
  ];

  // Campaign table columns
  const campaignTableColumns = [
    {
      key: 'campaign_name',
      label: 'Campaign',
      sortable: true,
      render: (value: string, row: ScoutCampaign) => (
        <div>
          <div className="font-medium text-gray-900">{value}</div>
          <div className="text-sm text-gray-500">{row.client}</div>
        </div>
      )
    },
    {
      key: 'status',
      label: 'Status',
      render: (value: string) => {
        const statusColors = {
          active: 'bg-green-100 text-green-800',
          paused: 'bg-yellow-100 text-yellow-800',
          completed: 'bg-blue-100 text-blue-800',
          draft: 'bg-gray-100 text-gray-800'
        };
        return (
          <span className={`px-2 py-1 rounded-full text-xs font-medium ${statusColors[value as keyof typeof statusColors]}`}>
            {value.toUpperCase()}
          </span>
        );
      }
    },
    {
      key: 'budget',
      label: 'Budget',
      sortable: true,
      render: (value: number) => (
        <span className="font-mono">₱{value.toLocaleString()}</span>
      )
    },
    {
      key: 'spend',
      label: 'Spend',
      sortable: true,
      render: (value: number) => (
        <span className="font-mono">₱{value.toLocaleString()}</span>
      )
    },
    {
      key: 'performance_score',
      label: 'Performance',
      sortable: true,
      render: (value: number) => (
        <div className="flex items-center">
          <span className={`font-mono ${value >= 90 ? 'text-green-600' : value >= 80 ? 'text-yellow-600' : 'text-red-600'}`}>
            {value.toFixed(1)}%
          </span>
          <div className="ml-2 w-16 bg-gray-200 rounded-full h-2">
            <div 
              className={`h-2 rounded-full ${value >= 90 ? 'bg-green-500' : value >= 80 ? 'bg-yellow-500' : 'bg-red-500'}`}
              style={{ width: `${value}%` }}
            ></div>
          </div>
        </div>
      )
    }
  ];

  return (
    <div className={`scout-dashboard space-y-6 ${className}`}>
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Scout Analytics Dashboard</h1>
          <p className="text-gray-600 mt-1">TBWA Enterprise Campaign Intelligence Platform</p>
        </div>
        <div className="flex items-center space-x-2 text-sm text-gray-500">
          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full bg-green-100 text-green-800 font-medium">
            Live Data
          </span>
          <span>Last updated: {new Date().toLocaleTimeString()}</span>
        </div>
      </div>

      {/* Filters */}
      <FilterPanel
        title="Dashboard Filters"
        filters={filterOptions}
        values={filters}
        onFilterChange={(key, value) => setFilters(prev => ({ ...prev, [key]: value }))}
        onApplyFilters={() => {}}
        onResetFilters={() => setFilters({ timeRange: '30d', department: 'all', client: 'all', status: 'all' })}
      />

      {/* KPIs */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {metrics.map((metric) => (
          <KpiTile
            key={metric.id}
            label={metric.label}
            value={metric.format === 'currency' ? `${metric.currency}${metric.value}` : 
                   metric.format === 'percentage' ? `${metric.value}%` : metric.value}
            delta={metric.trend?.value}
            hint={metric.format === 'currency' ? 'Philippine Peso' : 
                  metric.format === 'percentage' ? 'Percentage' : 'Count'}
            state={loading ? 'loading' : 'default'}
          />
        ))}
      </div>

      {/* Charts Row 1 */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <ChartCard
          title="Revenue Trend"
          subtitle="Monthly revenue and campaign count"
          chartType="line"
          data={revenueData}
          loading={loading}
          height={300}
          showLegend={true}
        />
        <ChartCard
          title="Campaign Performance"
          subtitle="Performance scores by campaign"
          chartType="bar"
          data={campaignPerformanceData}
          loading={loading}
          height={300}
          showLegend={false}
        />
      </div>

      {/* Campaign Management Table */}
      <div className="bg-white rounded-lg shadow">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">Active Campaigns</h2>
          <p className="text-sm text-gray-500 mt-1">Monitor and manage your current campaign portfolio</p>
        </div>
        <div className="p-6">
          <DataTable
            data={campaigns}
            columns={campaignTableColumns}
            loading={loading}
            searchable={true}
            pagination={true}
            pageSize={10}
          />
        </div>
      </div>

      {/* Regional Performance */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
        <div className="bg-white rounded-lg shadow">
          <div className="px-6 py-4 border-b border-gray-200">
            <h2 className="text-lg font-semibold text-gray-900">Regional Performance</h2>
            <p className="text-sm text-gray-500 mt-1">Sales and campaign metrics by region</p>
          </div>
          <div className="p-6">
            <div className="space-y-4">
              {regionalData.map((region, index) => (
                <div key={index} className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                  <div>
                    <div className="font-medium text-gray-900">{region.region}</div>
                    <div className="text-sm text-gray-500">{region.country}</div>
                  </div>
                  <div className="text-right">
                    <div className="font-mono text-lg font-semibold">₱{region.total_sales.toLocaleString()}</div>
                    <div className="text-sm text-gray-500">{region.campaign_count} campaigns</div>
                  </div>
                  <div className="flex items-center">
                    <span className={`text-sm font-medium ${
                      region.performance_rating >= 90 ? 'text-green-600' : 
                      region.performance_rating >= 85 ? 'text-yellow-600' : 'text-red-600'
                    }`}>
                      {region.performance_rating}%
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* AI Insights Panel */}
        <div className="bg-gradient-to-br from-blue-50 to-indigo-50 border border-blue-200 rounded-lg">
          <div className="px-6 py-4 border-b border-blue-200">
            <h3 className="text-lg font-semibold text-blue-900 flex items-center">
              🤖 Scout AI Insights
            </h3>
          </div>
          <div className="p-6">
            <div className="space-y-4 text-sm text-blue-800">
              <div className="p-3 bg-white/60 rounded-lg">
                <div className="font-medium text-blue-900">🎯 Campaign Optimization</div>
                <p>Globe 5G campaign showing strong performance. Consider increasing budget allocation by 15% to maximize reach.</p>
              </div>
              
              <div className="p-3 bg-white/60 rounded-lg">
                <div className="font-medium text-blue-900">📊 Regional Insights</div>
                <p>Metro Manila showing highest ROI. Bangkok market has potential for expansion based on demographic analysis.</p>
              </div>
              
              <div className="p-3 bg-white/60 rounded-lg">
                <div className="font-medium text-blue-900">⚠️ Performance Alert</div>
                <p>Average ROI decreased by 5.2%. Recommend reviewing creative assets and targeting parameters.</p>
              </div>
              
              <div className="p-3 bg-white/60 rounded-lg">
                <div className="font-medium text-blue-900">🚀 Growth Opportunities</div>
                <p>Client satisfaction at 94.2% - excellent retention rate. Perfect time to propose new service offerings.</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ScoutDashboard;