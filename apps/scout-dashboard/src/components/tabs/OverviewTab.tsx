import React, { useState, useEffect } from 'react';
import { ChartContainer, RevenueTrendChart, ComposedMetricsChart } from '../charts/ChartWrappers';
import { useFiltersStore, useGlobalFilters } from '../../store/filters';
import { useAIInsights } from '../../services/ai-integration';
import dashboardConfig from '../../config/dashboard-config.json';

export interface OverviewTabProps {
  persona: string;
  className?: string;
}

// Mock data generators for retail analytics
const generateRevenueData = (days: number = 30) => {
  const data = [];
  const baseRevenue = 1200000; // PHP 1.2M base daily
  
  for (let i = days; i >= 0; i--) {
    const date = new Date();
    date.setDate(date.getDate() - i);
    
    // Add seasonal variation and trends
    const seasonalFactor = 1 + 0.2 * Math.sin((date.getDay() / 7) * Math.PI); // Weekend boost
    const trendFactor = 1 + (days - i) * 0.001; // Slight upward trend
    const randomFactor = 0.8 + Math.random() * 0.4; // Random variation
    
    const revenue = Math.round(baseRevenue * seasonalFactor * trendFactor * randomFactor);
    const previousRevenue = Math.round(revenue * (0.9 + Math.random() * 0.2)); // Comparison data
    
    data.push({
      date: date.toISOString(),
      revenue,
      previousRevenue,
      transactions: Math.round(revenue / 420), // Average basket size ~PHP 420
      footTraffic: Math.round(revenue / 320) // Conversion rate factor
    });
  }
  
  return data;
};

const generateKPIData = () => {
  const kpis = dashboardConfig.kpis;
  
  return {
    revenue: {
      ...kpis.revenue,
      current: 45234567,
      change: 12.3,
      trend: 'up'
    },
    transactions: {
      ...kpis.transactions,
      current: 107542,
      change: 8.7,
      trend: 'up'
    },
    avg_basket_size: {
      ...kpis.avg_basket_size,
      current: 420.65,
      change: 3.2,
      trend: 'up'
    },
    market_share: {
      ...kpis.market_share,
      current: 16.8,
      change: 0.9,
      trend: 'up'
    },
    store_count: {
      ...kpis.store_count,
      current: 247,
      change: 2.1,
      trend: 'up'
    },
    customer_satisfaction: {
      ...kpis.customer_satisfaction,
      current: 86.4,
      change: -1.2,
      trend: 'down'
    }
  };
};

const generateTopPerformersData = () => [
  { name: 'Electronics', revenue: 12500000, growth: 18.5, contribution: 24.3 },
  { name: 'Fresh Products', revenue: 11200000, growth: 12.3, contribution: 21.8 },
  { name: 'FMCG', revenue: 9800000, growth: 8.7, contribution: 19.1 },
  { name: 'Apparel', revenue: 8900000, growth: 15.2, contribution: 17.3 },
  { name: 'Home & Garden', revenue: 6100000, growth: 6.4, contribution: 11.9 }
];

export const OverviewTab: React.FC<OverviewTabProps> = ({
  persona,
  className = ''
}) => {
  const filters = useGlobalFilters();
  const { insights, loading: insightsLoading, refreshInsights } = useAIInsights('overview');
  
  const [revenueData, setRevenueData] = useState(generateRevenueData());
  const [kpiData, setKPIData] = useState(generateKPIData());
  const [topPerformersData, setTopPerformersData] = useState(generateTopPerformersData());
  const [loading, setLoading] = useState(false);

  // Simulate data refresh when filters change
  useEffect(() => {
    setLoading(true);
    const timer = setTimeout(() => {
      setRevenueData(generateRevenueData());
      setKPIData(generateKPIData());
      setTopPerformersData(generateTopPerformersData());
      setLoading(false);
    }, 800);

    return () => clearTimeout(timer);
  }, [filters]);

  const KPICard = ({ kpi, value, change, trend }: {
    kpi: any;
    value: number;
    change: number;
    trend: 'up' | 'down' | 'flat';
  }) => {
    const formatValue = (val: number) => {
      switch (kpi.format) {
        case 'currency':
          return new Intl.NumberFormat('en-PH', {
            style: 'currency',
            currency: kpi.currency || 'PHP',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
          }).format(val);
        case 'percentage':
          return `${val.toFixed(1)}%`;
        case 'number':
          return val.toLocaleString();
        default:
          return val.toString();
      }
    };

    const getChangeColor = () => {
      if (trend === 'up') return 'text-green-600';
      if (trend === 'down') return 'text-red-600';
      return 'text-gray-600';
    };

    const getChangeIcon = () => {
      if (trend === 'up') return '↗';
      if (trend === 'down') return '↘';
      return '→';
    };

    return (
      <div className="bg-white rounded-lg border border-gray-200 p-6 shadow-sm">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-medium text-gray-600">{kpi.label}</p>
            <p className="text-2xl font-bold text-gray-900 mt-1">
              {formatValue(value)}
            </p>
          </div>
          <div className="text-right">
            <p className={`text-sm font-medium ${getChangeColor()}`}>
              {getChangeIcon()} {Math.abs(change)}%
            </p>
            <p className="text-xs text-gray-500 mt-1">vs prev period</p>
          </div>
        </div>
        
        {/* Progress bar for target achievement */}
        {kpi.target && (
          <div className="mt-4">
            <div className="flex justify-between text-xs text-gray-600 mb-1">
              <span>Target: {formatValue(kpi.target)}</span>
              <span>{((value / kpi.target) * 100).toFixed(0)}%</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div
                className={`h-2 rounded-full ${
                  value >= kpi.target ? 'bg-green-500' : value >= kpi.target * 0.8 ? 'bg-yellow-500' : 'bg-red-500'
                }`}
                style={{ width: `${Math.min((value / kpi.target) * 100, 100)}%` }}
              ></div>
            </div>
          </div>
        )}
      </div>
    );
  };

  const AlertsPanel = () => {
    const alerts = [
      {
        id: '1',
        type: 'warning',
        title: 'Customer Satisfaction Decline',
        message: 'Customer satisfaction dropped 1.2% this period. Review service quality metrics.',
        time: '2 hours ago',
        priority: 'medium'
      },
      {
        id: '2',
        type: 'info',
        title: 'Electronics Category Surge',
        message: 'Electronics showing 18.5% growth - consider increasing inventory.',
        time: '4 hours ago',
        priority: 'low'
      },
      {
        id: '3',
        type: 'success',
        title: 'Revenue Target Achieved',
        message: 'Monthly revenue target exceeded by 12.3%. Great performance!',
        time: '1 day ago',
        priority: 'low'
      }
    ];

    const getAlertIcon = (type: string) => {
      switch (type) {
        case 'warning':
          return '⚠️';
        case 'success':
          return '✅';
        case 'info':
          return 'ℹ️';
        default:
          return '📊';
      }
    };

    const getAlertColor = (type: string) => {
      switch (type) {
        case 'warning':
          return 'border-yellow-200 bg-yellow-50';
        case 'success':
          return 'border-green-200 bg-green-50';
        case 'info':
          return 'border-blue-200 bg-blue-50';
        default:
          return 'border-gray-200 bg-gray-50';
      }
    };

    return (
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm">
        <div className="px-6 py-4 border-b border-gray-100">
          <h3 className="text-lg font-semibold text-gray-900">Recent Alerts</h3>
        </div>
        <div className="p-6 space-y-4">
          {alerts.map(alert => (
            <div key={alert.id} className={`border rounded-lg p-4 ${getAlertColor(alert.type)}`}>
              <div className="flex items-start space-x-3">
                <span className="text-lg">{getAlertIcon(alert.type)}</span>
                <div className="flex-1">
                  <h4 className="font-medium text-gray-900 text-sm">{alert.title}</h4>
                  <p className="text-sm text-gray-600 mt-1">{alert.message}</p>
                  <p className="text-xs text-gray-500 mt-2">{alert.time}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  };

  const TopPerformersTable = () => (
    <div className="bg-white rounded-lg border border-gray-200 shadow-sm">
      <div className="px-6 py-4 border-b border-gray-100">
        <h3 className="text-lg font-semibold text-gray-900">Top Performing Categories</h3>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Category
              </th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                Revenue
              </th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                Growth
              </th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                Contribution
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {topPerformersData.map((item, index) => (
              <tr key={item.name} className="hover:bg-gray-50">
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="flex items-center">
                    <span className="text-xs font-medium text-gray-500 mr-2">#{index + 1}</span>
                    <span className="text-sm font-medium text-gray-900">{item.name}</span>
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-right text-sm text-gray-900">
                  ₱{(item.revenue / 1000000).toFixed(1)}M
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-right">
                  <span className={`text-sm font-medium ${
                    item.growth > 0 ? 'text-green-600' : 'text-red-600'
                  }`}>
                    {item.growth > 0 ? '+' : ''}{item.growth}%
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-right text-sm text-gray-900">
                  {item.contribution}%
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );

  const AIInsightsPanel = () => (
    <div className="bg-white rounded-lg border border-gray-200 shadow-sm">
      <div className="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <h3 className="text-lg font-semibold text-gray-900">AI Insights</h3>
        <div className="flex items-center space-x-2">
          <div className="w-2 h-2 bg-purple-500 rounded-full"></div>
          <span className="text-xs text-gray-500">MCP Dev Mode</span>
        </div>
      </div>
      <div className="p-6">
        {insightsLoading ? (
          <div className="space-y-4">
            {[1, 2].map(i => (
              <div key={i} className="animate-pulse">
                <div className="h-4 bg-gray-200 rounded w-3/4 mb-2"></div>
                <div className="h-3 bg-gray-200 rounded w-full mb-1"></div>
                <div className="h-3 bg-gray-200 rounded w-5/6"></div>
              </div>
            ))}
          </div>
        ) : (
          <div className="space-y-4">
            {insights.slice(0, 3).map(insight => (
              <div key={insight.id} className="border-l-4 border-purple-500 pl-4">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <h4 className="font-medium text-gray-900 text-sm">{insight.title}</h4>
                    <p className="text-sm text-gray-600 mt-1">{insight.description}</p>
                    {insight.recommendation && (
                      <div className="mt-2 bg-purple-50 rounded p-2">
                        <p className="text-xs font-medium text-purple-800">Recommendation:</p>
                        <p className="text-xs text-purple-700">{insight.recommendation.action}</p>
                      </div>
                    )}
                  </div>
                  <div className="ml-4 text-right">
                    <span className={`inline-block px-2 py-1 text-xs font-medium rounded ${
                      insight.confidence === 'high'
                        ? 'bg-green-100 text-green-800'
                        : insight.confidence === 'medium'
                        ? 'bg-yellow-100 text-yellow-800'
                        : 'bg-gray-100 text-gray-800'
                    }`}>
                      {insight.confidence} confidence
                    </span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );

  return (
    <div className={`space-y-6 p-6 ${className}`}>
      {/* KPI Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {Object.entries(kpiData).map(([key, kpi]) => (
          <KPICard
            key={key}
            kpi={kpi}
            value={kpi.current}
            change={kpi.change}
            trend={kpi.trend}
          />
        ))}
      </div>

      {/* Revenue Trend Chart */}
      <ChartContainer
        title="Revenue Trend Analysis"
        subtitle="Daily revenue performance with period comparison"
        loading={loading}
      >
        <RevenueTrendChart
          data={revenueData}
          height={350}
          showComparison={true}
          currency="PHP"
          loading={loading}
        />
      </ChartContainer>

      {/* Bottom Grid - Insights and Tables */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Top Performers */}
        <TopPerformersTable />

        {/* AI Insights */}
        <AIInsightsPanel />
      </div>

      {/* Alerts Panel */}
      <AlertsPanel />
    </div>
  );
};

export default OverviewTab;