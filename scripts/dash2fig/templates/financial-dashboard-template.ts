/**
 * Financial Dashboard Template - Finebank UI Kit Integration
 * 
 * This template provides a structured approach to convert financial dashboard
 * components from Figma designs into React components compatible with our
 * Scout UI system.
 */

export interface FinancialDashboardTemplate {
  // Layout Structure
  layout: {
    type: 'financial_dashboard';
    gridSystem: '12_column';
    spacing: 'consistent_16px';
    breakpoints: ['mobile', 'tablet', 'desktop'];
  };

  // Component Mapping
  components: {
    // Header Components
    dashboard_header: {
      figma_component: 'Dashboard Header';
      react_component: 'DashboardHeader';
      props: ['title', 'user', 'notifications', 'search'];
    };

    // Navigation
    sidebar_navigation: {
      figma_component: 'Sidebar Navigation';
      react_component: 'SidebarNav';
      props: ['menuItems', 'activeItem', 'collapsed'];
    };

    // Financial KPIs
    balance_card: {
      figma_component: 'Balance Card';
      react_component: 'FinancialKpiCard';
      props: ['amount', 'label', 'trend', 'currency'];
    };

    revenue_chart: {
      figma_component: 'Revenue Chart';
      react_component: 'RevenueChart';
      props: ['data', 'timeRange', 'chartType'];
    };

    expense_breakdown: {
      figma_component: 'Expense Pie Chart';
      react_component: 'ExpenseBreakdown';
      props: ['categories', 'amounts', 'colors'];
    };

    // Transaction Components
    transaction_list: {
      figma_component: 'Transaction List';
      react_component: 'TransactionTable';
      props: ['transactions', 'pagination', 'filters'];
    };

    // Analytics Cards
    performance_card: {
      figma_component: 'Performance Card';
      react_component: 'PerformanceCard';
      props: ['metric', 'value', 'change', 'period'];
    };
  };

  // Design System Tokens
  designTokens: {
    colors: {
      primary: '#2563EB';      // Blue primary
      secondary: '#10B981';    // Green success
      danger: '#EF4444';       // Red danger
      warning: '#F59E0B';      // Amber warning
      neutral: {
        50: '#F9FAFB',
        100: '#F3F4F6',
        500: '#6B7280',
        900: '#111827'
      };
    };

    typography: {
      heading_xl: {
        fontSize: '36px',
        fontWeight: '700',
        lineHeight: '1.2'
      };
      heading_lg: {
        fontSize: '24px',
        fontWeight: '600',
        lineHeight: '1.3'
      };
      body_regular: {
        fontSize: '14px',
        fontWeight: '400',
        lineHeight: '1.5'
      };
      caption: {
        fontSize: '12px',
        fontWeight: '500',
        lineHeight: '1.4'
      };
    };

    spacing: {
      xs: '4px',
      sm: '8px',
      md: '16px',
      lg: '24px',
      xl: '32px',
      '2xl': '48px'
    };

    borderRadius: {
      sm: '4px',
      md: '8px',
      lg: '12px',
      xl: '16px'
    };

    shadows: {
      card: '0 1px 3px rgba(0, 0, 0, 0.1)',
      elevated: '0 4px 6px rgba(0, 0, 0, 0.1)',
      large: '0 10px 15px rgba(0, 0, 0, 0.1)'
    };
  };
}

// Component Generator Functions
export const generateFinancialComponents = {
  /**
   * Generate Financial KPI Card component
   */
  financialKpiCard: (config: any) => `
import React from 'react';

interface FinancialKpiCardProps {
  amount: string;
  label: string;
  trend?: {
    value: number;
    direction: 'up' | 'down';
  };
  currency?: string;
  className?: string;
}

export const FinancialKpiCard: React.FC<FinancialKpiCardProps> = ({
  amount,
  label,
  trend,
  currency = '$',
  className = ''
}) => {
  return (
    <div className={\`bg-white rounded-lg shadow-card p-6 \${className}\`}>
      <div className="flex items-center justify-between mb-2">
        <p className="text-sm font-medium text-gray-600">{label}</p>
        {trend && (
          <span className={\`flex items-center text-sm font-medium \${
            trend.direction === 'up' ? 'text-green-600' : 'text-red-600'
          }\`}>
            {trend.direction === 'up' ? '↗️' : '↘️'} {trend.value}%
          </span>
        )}
      </div>
      <div className="flex items-baseline">
        <span className="text-sm text-gray-500">{currency}</span>
        <span className="text-2xl font-bold text-gray-900 ml-1">{amount}</span>
      </div>
    </div>
  );
};`,

  /**
   * Generate Revenue Chart component
   */
  revenueChart: (config: any) => `
import React from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

interface RevenueChartProps {
  data: Array<{ name: string; value: number }>;
  timeRange: string;
  chartType: 'line' | 'bar' | 'area';
  className?: string;
}

export const RevenueChart: React.FC<RevenueChartProps> = ({
  data,
  timeRange,
  chartType = 'line',
  className = ''
}) => {
  return (
    <div className={\`bg-white rounded-lg shadow-card p-6 \${className}\`}>
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-semibold text-gray-900">Revenue Trend</h3>
        <span className="text-sm text-gray-500">{timeRange}</span>
      </div>
      <div className="h-64">
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={data}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
            <XAxis 
              dataKey="name" 
              stroke="#6B7280" 
              fontSize={12}
              tickLine={false}
            />
            <YAxis 
              stroke="#6B7280" 
              fontSize={12}
              tickLine={false}
              axisLine={false}
            />
            <Tooltip 
              contentStyle={{
                backgroundColor: 'white',
                border: '1px solid #E5E7EB',
                borderRadius: '8px',
                boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)'
              }}
            />
            <Line 
              type="monotone" 
              dataKey="value" 
              stroke="#2563EB" 
              strokeWidth={2}
              dot={{ fill: '#2563EB', r: 4 }}
              activeDot={{ r: 6, fill: '#1D4ED8' }}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
};`,

  /**
   * Generate Transaction Table component
   */
  transactionTable: (config: any) => `
import React from 'react';

interface Transaction {
  id: string;
  date: string;
  description: string;
  category: string;
  amount: number;
  status: 'completed' | 'pending' | 'failed';
}

interface TransactionTableProps {
  transactions: Transaction[];
  pagination?: {
    currentPage: number;
    totalPages: number;
    onPageChange: (page: number) => void;
  };
  filters?: {
    category?: string;
    status?: string;
    dateRange?: { start: Date; end: Date };
  };
  className?: string;
}

export const TransactionTable: React.FC<TransactionTableProps> = ({
  transactions,
  pagination,
  filters,
  className = ''
}) => {
  const getStatusColor = (status: string) => {
    switch (status) {
      case 'completed': return 'bg-green-100 text-green-800';
      case 'pending': return 'bg-yellow-100 text-yellow-800';
      case 'failed': return 'bg-red-100 text-red-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  return (
    <div className={\`bg-white rounded-lg shadow-card \${className}\`}>
      <div className="px-6 py-4 border-b border-gray-200">
        <h3 className="text-lg font-semibold text-gray-900">Recent Transactions</h3>
      </div>
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Date
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Description
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Category
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Amount
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Status
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {transactions.map((transaction) => (
              <tr key={transaction.id} className="hover:bg-gray-50">
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {new Date(transaction.date).toLocaleDateString()}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {transaction.description}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {transaction.category}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  \${transaction.amount.toLocaleString()}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={\`inline-flex px-2 py-1 text-xs font-semibold rounded-full \${getStatusColor(transaction.status)}\`}>
                    {transaction.status}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};`
};

export default FinancialDashboardTemplate;