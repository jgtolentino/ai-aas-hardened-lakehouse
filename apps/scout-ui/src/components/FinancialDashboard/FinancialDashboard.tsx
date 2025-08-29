import React, { useState, useEffect } from 'react';
import { Calendar, TrendingUp, TrendingDown, DollarSign, Users, ShoppingCart, AlertCircle } from 'lucide-react';
import { MetricCard } from './components/MetricCard';
import { RevenueChart } from './components/RevenueChart';
import { TransactionTable } from './components/TransactionTable';
import { StoreMap } from './components/StoreMap';
import { DateRangePicker } from './components/DateRangePicker';
import { NotificationCenter } from './components/NotificationCenter';
import { useDashboardData } from './hooks/useDashboardData';
import { useRealtimeUpdates } from './hooks/useRealtimeUpdates';
import type { DashboardProps, TimeRange } from './types';

export const FinancialDashboard: React.FC<DashboardProps> = ({ 
  theme = 'light',
  period = 'daily',
  storeId 
}) => {
  const [timeRange, setTimeRange] = useState<TimeRange>('today');
  const [selectedMetric, setSelectedMetric] = useState<string>('revenue');
  const [isLoading, setIsLoading] = useState(true);
  
  // Fetch dashboard data
  const { metrics, charts, transactions, stores } = useDashboardData({
    period,
    timeRange,
    storeId
  });

  // Subscribe to real-time updates
  useRealtimeUpdates((update) => {
    console.log('Real-time update:', update);
    // Handle real-time data updates here
  });

  useEffect(() => {
    // Simulate loading
    setTimeout(() => setIsLoading(false), 1000);
  }, []);

  const kpiMetrics = [
    {
      id: 'revenue',
      title: 'Total Revenue',
      value: metrics?.revenue?.value || 0,
      change: metrics?.revenue?.change || 0,
      trend: metrics?.revenue?.trend || 'stable',
      icon: DollarSign,
      format: 'currency',
      color: 'blue'
    },
    {
      id: 'transactions',
      title: 'Transactions',
      value: metrics?.transactions?.value || 0,
      change: metrics?.transactions?.change || 0,
      trend: metrics?.transactions?.trend || 'stable',
      icon: ShoppingCart,
      format: 'number',
      color: 'green'
    },
    {
      id: 'aov',
      title: 'Average Order Value',
      value: metrics?.aov?.value || 0,
      change: metrics?.aov?.change || 0,
      trend: metrics?.aov?.trend || 'stable',
      icon: TrendingUp,
      format: 'currency',
      color: 'purple'
    },
    {
      id: 'customers',
      title: 'Unique Customers',
      value: metrics?.customers?.value || 0,
      change: metrics?.customers?.change || 0,
      trend: metrics?.customers?.trend || 'stable',
      icon: Users,
      format: 'number',
      color: 'orange'
    }
  ];

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className={`min-h-screen ${theme === 'dark' ? 'bg-gray-900 text-white' : 'bg-gray-50 text-gray-900'}`}>
      {/* Header */}
      <header className="sticky top-0 z-50 bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700">
        <div className="px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center">
              <h1 className="text-2xl font-bold">Scout Financial Dashboard</h1>
            </div>
            <div className="flex items-center space-x-4">
              <DateRangePicker 
                value={timeRange} 
                onChange={setTimeRange}
                className="hidden md:block"
              />
              <NotificationCenter />
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="px-4 sm:px-6 lg:px-8 py-8">
        {/* KPI Metrics Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          {kpiMetrics.map((metric) => (
            <MetricCard
              key={metric.id}
              {...metric}
              onClick={() => setSelectedMetric(metric.id)}
              isSelected={selectedMetric === metric.id}
            />
          ))}
        </div>

        {/* Charts and Map Section */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
          {/* Revenue Chart */}
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold">Revenue Trend</h2>
              <select 
                className="text-sm border rounded px-2 py-1"
                value={period}
                onChange={(e) => {/* Handle period change */}}
              >
                <option value="hourly">Hourly</option>
                <option value="daily">Daily</option>
                <option value="weekly">Weekly</option>
                <option value="monthly">Monthly</option>
              </select>
            </div>
            <RevenueChart 
              data={charts?.revenue || []}
              period={period}
              height={300}
            />
          </div>

          {/* Store Performance Map */}
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold">Store Performance</h2>
              <button className="text-sm text-blue-600 hover:text-blue-800">
                View All Stores
              </button>
            </div>
            <StoreMap 
              stores={stores || []}
              metric={selectedMetric}
              height={300}
            />
          </div>
        </div>

        {/* Transaction Table */}
        <div className="bg-white dark:bg-gray-800 rounded-lg shadow">
          <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-semibold">Recent Transactions</h2>
              <div className="flex items-center space-x-2">
                <button className="text-sm text-blue-600 hover:text-blue-800">
                  Export CSV
                </button>
                <button className="text-sm text-blue-600 hover:text-blue-800">
                  View All
                </button>
              </div>
            </div>
          </div>
          <TransactionTable 
            data={transactions || []}
            pageSize={10}
          />
        </div>

        {/* Insights Panel (AI-Powered) */}
        <div className="mt-8 bg-gradient-to-r from-blue-500 to-purple-600 rounded-lg shadow-lg p-6 text-white">
          <div className="flex items-start space-x-4">
            <AlertCircle className="h-6 w-6 flex-shrink-0 mt-1" />
            <div>
              <h3 className="text-lg font-semibold mb-2">AI Insights</h3>
              <ul className="space-y-2 text-sm">
                <li>• Revenue is trending 12% above forecast for this period</li>
                <li>• Store #15 in Makati showing unusual transaction patterns - investigate potential system issue</li>
                <li>• Product SKU-1234 experiencing 3x normal demand - consider inventory adjustment</li>
                <li>• Customer retention improved by 8% compared to last month</li>
              </ul>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
};

export default FinancialDashboard;
