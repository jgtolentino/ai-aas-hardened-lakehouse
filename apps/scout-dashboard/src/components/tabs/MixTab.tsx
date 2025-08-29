import React, { useState, useEffect } from 'react';
import { ChartContainer, CategoryMixChart, ComposedMetricsChart } from '../charts/ChartWrappers';
import { useFiltersStore, useGlobalFilters, useContextualFilters } from '../../store/filters';
import { useAIInsights } from '../../services/ai-integration';

export interface MixTabProps {
  persona: string;
  className?: string;
}

// Mock data generators for product mix analysis
const generateCategoryMixData = () => [
  { category: 'Electronics', value: 12500000, percentage: 24.3, margin: 18.5 },
  { category: 'Fresh Products', value: 11200000, percentage: 21.8, margin: 22.1 },
  { category: 'FMCG', value: 9800000, percentage: 19.1, margin: 15.3 },
  { category: 'Apparel', value: 8900000, percentage: 17.3, margin: 28.7 },
  { category: 'Home & Garden', value: 6100000, percentage: 11.9, margin: 24.2 },
  { category: 'Health & Beauty', value: 2800000, percentage: 5.6, margin: 31.4 }
];

const generateSubcategoryData = () => [
  { name: 'Smartphones', category: 'Electronics', revenue: 4200000, units: 2850, margin: 16.2 },
  { name: 'Laptops', category: 'Electronics', revenue: 3800000, units: 950, margin: 22.1 },
  { name: 'Fresh Vegetables', category: 'Fresh Products', revenue: 3500000, units: 125000, margin: 18.9 },
  { name: 'Dairy Products', category: 'Fresh Products', revenue: 2900000, units: 89000, margin: 24.3 },
  { name: 'Cleaning Products', category: 'FMCG', revenue: 2100000, units: 67000, margin: 19.8 },
  { name: 'Personal Care', category: 'FMCG', revenue: 1950000, units: 45000, margin: 12.4 },
  { name: 'Men\'s Clothing', category: 'Apparel', revenue: 2400000, units: 8900, margin: 32.1 },
  { name: 'Women\'s Clothing', category: 'Apparel', revenue: 3200000, units: 11500, margin: 26.8 }
];

const generateInventoryData = () => [
  { category: 'Electronics', stockLevel: 85, turnoverRate: 8.2, daysOfStock: 45, status: 'healthy' },
  { category: 'Fresh Products', stockLevel: 92, turnoverRate: 15.6, daysOfStock: 23, status: 'optimal' },
  { category: 'FMCG', stockLevel: 78, turnoverRate: 12.1, daysOfStock: 30, status: 'low' },
  { category: 'Apparel', stockLevel: 95, turnoverRate: 6.8, daysOfStock: 54, status: 'high' },
  { category: 'Home & Garden', stockLevel: 88, turnoverRate: 7.9, daysOfStock: 46, status: 'healthy' },
  { category: 'Health & Beauty', stockLevel: 82, turnoverRate: 11.3, daysOfStock: 32, status: 'healthy' }
];

const generateTrendData = () => {
  const categories = ['Electronics', 'Fresh Products', 'FMCG', 'Apparel', 'Home & Garden'];
  const data = [];
  
  for (let i = 11; i >= 0; i--) {
    const date = new Date();
    date.setMonth(date.getMonth() - i);
    
    const dataPoint = {
      period: date.toLocaleDateString('en-US', { month: 'short', year: 'numeric' })
    };
    
    categories.forEach(category => {
      const baseValue = 1000000 + Math.random() * 500000;
      const seasonalFactor = 1 + 0.15 * Math.sin((i / 12) * Math.PI * 2);
      dataPoint[category.toLowerCase().replace(/\s/g, '_')] = Math.round(baseValue * seasonalFactor);
    });
    
    data.push(dataPoint);
  }
  
  return data;
};

export const MixTab: React.FC<MixTabProps> = ({
  persona,
  className = ''
}) => {
  const filters = useGlobalFilters();
  const contextualFilters = useContextualFilters('mix');
  const { insights, loading: insightsLoading, refreshInsights } = useAIInsights('mix');
  const { setContextualFilter } = useFiltersStore();
  
  const [categoryData, setCategoryData] = useState(generateCategoryMixData());
  const [subcategoryData, setSubcategoryData] = useState(generateSubcategoryData());
  const [inventoryData, setInventoryData] = useState(generateInventoryData());
  const [trendData, setTrendData] = useState(generateTrendData());
  const [viewType, setViewType] = useState<'bar' | 'pie'>('bar');
  const [loading, setLoading] = useState(false);

  // Simulate data refresh when filters change
  useEffect(() => {
    setLoading(true);
    const timer = setTimeout(() => {
      setCategoryData(generateCategoryMixData());
      setSubcategoryData(generateSubcategoryData());
      setInventoryData(generateInventoryData());
      setTrendData(generateTrendData());
      setLoading(false);
    }, 800);

    return () => clearTimeout(timer);
  }, [filters, contextualFilters]);

  const CategoryLevelSelector = () => (
    <div className="flex items-center space-x-4">
      <span className="text-sm font-medium text-gray-700">Category Level:</span>
      <select
        value={contextualFilters?.categoryLevel || 'category'}
        onChange={(e) => setContextualFilter('mix', 'categoryLevel', e.target.value)}
        className="px-3 py-1 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
      >
        <option value="category">Category</option>
        <option value="subcategory">Subcategory</option>
        <option value="brand">Brand</option>
      </select>
    </div>
  );

  const ViewTypeToggle = () => (
    <div className="flex items-center space-x-2">
      <button
        onClick={() => setViewType('bar')}
        className={`px-3 py-1 text-xs font-medium rounded ${
          viewType === 'bar'
            ? 'bg-blue-600 text-white'
            : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
        }`}
      >
        Bar Chart
      </button>
      <button
        onClick={() => setViewType('pie')}
        className={`px-3 py-1 text-xs font-medium rounded ${
          viewType === 'pie'
            ? 'bg-blue-600 text-white'
            : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
        }`}
      >
        Pie Chart
      </button>
    </div>
  );

  const CategoryPerformanceTable = () => {
    const data = contextualFilters?.categoryLevel === 'subcategory' ? subcategoryData : categoryData;
    
    return (
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm">
        <div className="px-6 py-4 border-b border-gray-100">
          <div className="flex items-center justify-between">
            <h3 className="text-lg font-semibold text-gray-900">
              {contextualFilters?.categoryLevel === 'subcategory' ? 'Subcategory' : 'Category'} Performance
            </h3>
            <div className="flex items-center space-x-4">
              <CategoryLevelSelector />
            </div>
          </div>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  {contextualFilters?.categoryLevel === 'subcategory' ? 'Subcategory' : 'Category'}
                </th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Revenue
                </th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  {contextualFilters?.categoryLevel === 'subcategory' ? 'Units' : 'Share'}
                </th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Margin %
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {data.map((item, index) => (
                <tr key={item.name || item.category} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      <span className="text-xs font-medium text-gray-500 mr-2">#{index + 1}</span>
                      <div>
                        <span className="text-sm font-medium text-gray-900">
                          {item.name || item.category}
                        </span>
                        {item.category && item.name && (
                          <div className="text-xs text-gray-500">{item.category}</div>
                        )}
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm text-gray-900">
                    ₱{(item.revenue || item.value) / 1000000 < 1 
                      ? ((item.revenue || item.value) / 1000).toFixed(0) + 'K'
                      : ((item.revenue || item.value) / 1000000).toFixed(1) + 'M'
                    }
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm text-gray-900">
                    {contextualFilters?.categoryLevel === 'subcategory' 
                      ? item.units?.toLocaleString() 
                      : item.percentage?.toFixed(1) + '%'
                    }
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right">
                    <span className={`text-sm font-medium ${
                      item.margin > 20 ? 'text-green-600' : item.margin > 15 ? 'text-yellow-600' : 'text-red-600'
                    }`}>
                      {item.margin.toFixed(1)}%
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    );
  };

  const InventoryLevelsPanel = () => (
    <div className="bg-white rounded-lg border border-gray-200 shadow-sm">
      <div className="px-6 py-4 border-b border-gray-100">
        <h3 className="text-lg font-semibold text-gray-900">Inventory Status</h3>
      </div>
      <div className="p-6">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {inventoryData.map(item => {
            const getStatusColor = (status: string) => {
              switch (status) {
                case 'optimal': return 'bg-green-100 text-green-800 border-green-200';
                case 'healthy': return 'bg-blue-100 text-blue-800 border-blue-200';
                case 'low': return 'bg-red-100 text-red-800 border-red-200';
                case 'high': return 'bg-yellow-100 text-yellow-800 border-yellow-200';
                default: return 'bg-gray-100 text-gray-800 border-gray-200';
              }
            };

            return (
              <div key={item.category} className={`border rounded-lg p-4 ${getStatusColor(item.status)}`}>
                <div className="flex items-center justify-between mb-2">
                  <h4 className="font-medium text-sm">{item.category}</h4>
                  <span className="text-xs font-medium px-2 py-1 rounded-full bg-white bg-opacity-70">
                    {item.status.toUpperCase()}
                  </span>
                </div>
                <div className="space-y-2 text-xs">
                  <div className="flex justify-between">
                    <span>Stock Level:</span>
                    <span className="font-medium">{item.stockLevel}%</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Turnover Rate:</span>
                    <span className="font-medium">{item.turnoverRate}x</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Days of Stock:</span>
                    <span className="font-medium">{item.daysOfStock} days</span>
                  </div>
                </div>
                
                {/* Stock level bar */}
                <div className="mt-3">
                  <div className="w-full bg-white bg-opacity-50 rounded-full h-2">
                    <div
                      className={`h-2 rounded-full ${
                        item.stockLevel > 90 ? 'bg-yellow-600' :
                        item.stockLevel > 70 ? 'bg-green-600' : 'bg-red-600'
                      }`}
                      style={{ width: `${item.stockLevel}%` }}
                    ></div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );

  const MixInsightsPanel = () => (
    <div className="bg-white rounded-lg border border-gray-200 shadow-sm">
      <div className="px-6 py-4 border-b border-gray-100">
        <h3 className="text-lg font-semibold text-gray-900">Mix Analysis Insights</h3>
      </div>
      <div className="p-6">
        {insightsLoading ? (
          <div className="space-y-4">
            {[1, 2, 3].map(i => (
              <div key={i} className="animate-pulse">
                <div className="h-4 bg-gray-200 rounded w-3/4 mb-2"></div>
                <div className="h-3 bg-gray-200 rounded w-full mb-1"></div>
                <div className="h-3 bg-gray-200 rounded w-5/6"></div>
              </div>
            ))}
          </div>
        ) : (
          <div className="space-y-4">
            {insights.slice(0, 2).map(insight => (
              <div key={insight.id} className="border-l-4 border-orange-500 pl-4">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <h4 className="font-medium text-gray-900 text-sm">{insight.title}</h4>
                    <p className="text-sm text-gray-600 mt-1">{insight.description}</p>
                    {insight.recommendation && (
                      <div className="mt-2 bg-orange-50 rounded p-2">
                        <p className="text-xs font-medium text-orange-800">Recommendation:</p>
                        <p className="text-xs text-orange-700">{insight.recommendation.action}</p>
                      </div>
                    )}
                  </div>
                  <div className="ml-4 text-right">
                    <span className={`inline-block px-2 py-1 text-xs font-medium rounded ${
                      insight.impact === 'high'
                        ? 'bg-red-100 text-red-800'
                        : insight.impact === 'medium'
                        ? 'bg-yellow-100 text-yellow-800'
                        : 'bg-green-100 text-green-800'
                    }`}>
                      {insight.impact} impact
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
      {/* Category Mix Chart */}
      <ChartContainer
        title="Category Revenue Mix"
        subtitle="Revenue distribution across product categories"
        loading={loading}
        actions={<ViewTypeToggle />}
      >
        <CategoryMixChart
          data={categoryData}
          height={350}
          chartType={viewType}
          showPercentage={true}
          loading={loading}
        />
      </ChartContainer>

      {/* Performance Table and Insights */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Mix Insights */}
        <MixInsightsPanel />

        {/* Performance Summary Cards */}
        <div className="space-y-4">
          <div className="bg-white rounded-lg border border-gray-200 shadow-sm p-6">
            <h4 className="font-semibold text-gray-900 mb-4">Mix Performance Summary</h4>
            <div className="grid grid-cols-2 gap-4">
              <div className="text-center">
                <div className="text-2xl font-bold text-blue-600">6</div>
                <div className="text-xs text-gray-600">Active Categories</div>
              </div>
              <div className="text-center">
                <div className="text-2xl font-bold text-green-600">21.4%</div>
                <div className="text-xs text-gray-600">Avg Margin</div>
              </div>
              <div className="text-center">
                <div className="text-2xl font-bold text-orange-600">76.3%</div>
                <div className="text-xs text-gray-600">Top 3 Contribution</div>
              </div>
              <div className="text-center">
                <div className="text-2xl font-bold text-purple-600">₱51.3M</div>
                <div className="text-xs text-gray-600">Total Revenue</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Category Trends */}
      <ChartContainer
        title="Category Performance Trends"
        subtitle="12-month revenue trends by category"
        loading={loading}
      >
        <ComposedMetricsChart
          data={trendData}
          height={350}
          primaryMetric="electronics"
          secondaryMetric="fresh_products"
          primaryAxisLabel="Electronics Revenue (₱)"
          secondaryAxisLabel="Fresh Products Revenue (₱)"
          loading={loading}
        />
      </ChartContainer>

      {/* Detailed Performance Table */}
      <CategoryPerformanceTable />

      {/* Inventory Status */}
      <InventoryLevelsPanel />
    </div>
  );
};

export default MixTab;