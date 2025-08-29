import React, { useState, useEffect } from 'react';
import { ChartContainer, ComposedMetricsChart, PieChart, LineChart } from '../charts/ChartWrappers';
import { useFiltersStore, useGlobalFilters } from '../../store/filters';
import { useAIInsights } from '../../services/ai-integration';
import dashboardConfig from '../../config/dashboard-config.json';

export interface CompetitiveTabProps {
  persona: string;
  className?: string;
}

// Mock data generators for competitive analysis
const generateMarketShareData = () => [
  { name: 'Our Company', value: 16.8, color: '#3b82f6', trend: 0.9 },
  { name: 'Competitor A', value: 22.3, color: '#ef4444', trend: -1.2 },
  { name: 'Competitor B', value: 18.5, color: '#f59e0b', trend: 0.3 },
  { name: 'Competitor C', value: 14.2, color: '#10b981', trend: -0.5 },
  { name: 'Others', value: 28.2, color: '#6b7280', trend: 0.5 }
];

const generateCompetitivePricingData = () => {
  const categories = ['Electronics', 'Fresh Products', 'FMCG', 'Apparel', 'Home & Garden'];
  const companies = ['Our Company', 'Competitor A', 'Competitor B', 'Competitor C'];
  const data = [];

  categories.forEach(category => {
    const basePrice = Math.random() * 1000 + 500;
    companies.forEach((company, index) => {
      const variation = (Math.random() - 0.5) * 0.2; // ±10% variation
      data.push({
        category,
        company,
        averagePrice: basePrice * (1 + variation),
        priceIndex: 100 + (variation * 100),
        competitiveness: Math.random() * 100,
        isOurs: company === 'Our Company'
      });
    });
  });

  return data;
};

const generateBrandPositioningData = () => [
  { 
    brand: 'Our Company', 
    quality: 85, 
    value: 78, 
    innovation: 82, 
    service: 88, 
    overall: 83.3,
    quadrant: 'Quality Leader'
  },
  { 
    brand: 'Competitor A', 
    quality: 78, 
    value: 65, 
    innovation: 75, 
    service: 72, 
    overall: 72.5,
    quadrant: 'Premium Player'
  },
  { 
    brand: 'Competitor B', 
    quality: 65, 
    value: 92, 
    innovation: 68, 
    service: 75, 
    overall: 75.0,
    quadrant: 'Value Leader'
  },
  { 
    brand: 'Competitor C', 
    quality: 72, 
    value: 85, 
    innovation: 88, 
    service: 80, 
    overall: 81.3,
    quadrant: 'Innovation Leader'
  }
];

const generateTrendComparisonData = (days: number = 90) => {
  const data = [];
  const companies = ['Our Company', 'Competitor A', 'Competitor B', 'Industry Avg'];
  
  for (let i = days; i >= 0; i--) {
    const date = new Date();
    date.setDate(date.getDate() - i);
    
    const entry = {
      date: date.toISOString().split('T')[0],
      'Our Company': 16.8 + Math.sin(i / 10) * 2 + (Math.random() - 0.5) * 0.5,
      'Competitor A': 22.3 + Math.sin((i + 30) / 15) * 1.5 + (Math.random() - 0.5) * 0.8,
      'Competitor B': 18.5 + Math.cos(i / 12) * 1.2 + (Math.random() - 0.5) * 0.6,
      'Industry Avg': 18.0 + Math.sin(i / 20) * 0.8 + (Math.random() - 0.5) * 0.3
    };
    
    data.push(entry);
  }
  
  return data;
};

export const CompetitiveTab: React.FC<CompetitiveTabProps> = ({
  persona,
  className = ''
}) => {
  const filters = useGlobalFilters();
  const { insights, loading: insightsLoading, refreshInsights } = useAIInsights('competitive');
  
  const [marketShareData, setMarketShareData] = useState(generateMarketShareData());
  const [pricingData, setPricingData] = useState(generateCompetitivePricingData());
  const [brandPositioningData, setBrandPositioningData] = useState(generateBrandPositioningData());
  const [trendData, setTrendData] = useState(generateTrendComparisonData());
  const [loading, setLoading] = useState(false);
  const [selectedCategory, setSelectedCategory] = useState<string>('all');

  // Simulate data refresh when filters change
  useEffect(() => {
    setLoading(true);
    const timer = setTimeout(() => {
      setMarketShareData(generateMarketShareData());
      setPricingData(generateCompetitivePricingData());
      setBrandPositioningData(generateBrandPositioningData());
      setTrendData(generateTrendComparisonData());
      setLoading(false);
    }, 800);

    return () => clearTimeout(timer);
  }, [filters]);

  const MarketShareOverview = () => (
    <ChartContainer
      title="Market Share Overview"
      subtitle="Current market position across all categories"
      loading={loading}
    >
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Pie Chart */}
        <div>
          <PieChart
            data={marketShareData}
            height={300}
            showLegend={true}
            centerLabel="Market Share"
            loading={loading}
          />
        </div>
        
        {/* Market Share Details */}
        <div className="space-y-4">
          {marketShareData.map(item => (
            <div key={item.name} className="flex items-center justify-between p-3 rounded-lg bg-gray-50">
              <div className="flex items-center space-x-3">
                <div 
                  className="w-4 h-4 rounded-full" 
                  style={{ backgroundColor: item.color }}
                />
                <div>
                  <span className={`font-medium ${item.name === 'Our Company' ? 'text-blue-600' : 'text-gray-900'}`}>
                    {item.name}
                  </span>
                  <p className="text-sm text-gray-500">{item.value}% market share</p>
                </div>
              </div>
              <div className="text-right">
                <span className={`text-sm font-medium ${
                  item.trend > 0 ? 'text-green-600' : item.trend < 0 ? 'text-red-600' : 'text-gray-600'
                }`}>
                  {item.trend > 0 ? '+' : ''}{item.trend}%
                </span>
                <p className="text-xs text-gray-500">vs last period</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </ChartContainer>
  );

  const CompetitivePricingAnalysis = () => {
    const categories = [...new Set(pricingData.map(d => d.category))];
    const filteredData = selectedCategory === 'all' 
      ? pricingData 
      : pricingData.filter(d => d.category === selectedCategory);

    return (
      <ChartContainer
        title="Competitive Pricing Analysis"
        subtitle="Price positioning across categories and competitors"
        loading={loading}
      >
        <div className="space-y-4">
          {/* Category Filter */}
          <div className="flex items-center space-x-2">
            <span className="text-sm font-medium text-gray-700">Category:</span>
            <select
              value={selectedCategory}
              onChange={(e) => setSelectedCategory(e.target.value)}
              className="px-3 py-1 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="all">All Categories</option>
              {categories.map(cat => (
                <option key={cat} value={cat}>{cat}</option>
              ))}
            </select>
          </div>

          {/* Pricing Table */}
          <div className="overflow-x-auto">
            <table className="w-full border-collapse">
              <thead>
                <tr className="bg-gray-50">
                  <th className="px-4 py-3 text-left text-sm font-medium text-gray-700 border-b">Category</th>
                  <th className="px-4 py-3 text-left text-sm font-medium text-gray-700 border-b">Company</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700 border-b">Avg Price</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700 border-b">Price Index</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700 border-b">Competitiveness</th>
                </tr>
              </thead>
              <tbody>
                {filteredData.map((item, index) => (
                  <tr key={index} className={`border-b hover:bg-gray-50 ${item.isOurs ? 'bg-blue-50' : ''}`}>
                    <td className="px-4 py-3 text-sm text-gray-900">{item.category}</td>
                    <td className="px-4 py-3 text-sm">
                      <span className={item.isOurs ? 'font-medium text-blue-600' : 'text-gray-900'}>
                        {item.company}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-900 text-right">
                      ₱{item.averagePrice.toFixed(2)}
                    </td>
                    <td className="px-4 py-3 text-sm text-right">
                      <span className={`${
                        item.priceIndex > 105 ? 'text-red-600' : 
                        item.priceIndex < 95 ? 'text-green-600' : 'text-gray-600'
                      }`}>
                        {item.priceIndex.toFixed(0)}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-sm text-right">
                      <div className="flex items-center justify-end space-x-2">
                        <div className="w-16 bg-gray-200 rounded-full h-2">
                          <div
                            className={`h-2 rounded-full ${
                              item.competitiveness > 75 ? 'bg-green-500' : 
                              item.competitiveness > 50 ? 'bg-yellow-500' : 'bg-red-500'
                            }`}
                            style={{ width: `${item.competitiveness}%` }}
                          />
                        </div>
                        <span className="text-xs text-gray-500 w-8">
                          {item.competitiveness.toFixed(0)}%
                        </span>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </ChartContainer>
    );
  };

  const BrandPositioningMatrix = () => (
    <ChartContainer
      title="Brand Positioning Matrix"
      subtitle="Quality vs Value positioning across competitors"
      loading={loading}
    >
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Positioning Chart */}
        <div className="relative">
          <div className="w-full h-80 bg-gray-50 rounded-lg p-4 relative overflow-hidden">
            {/* Axis labels */}
            <div className="absolute bottom-2 left-1/2 transform -translate-x-1/2 text-xs text-gray-600">
              Value →
            </div>
            <div className="absolute left-2 top-1/2 transform -translate-y-1/2 -rotate-90 text-xs text-gray-600">
              Quality →
            </div>
            
            {/* Grid lines */}
            <svg className="absolute inset-4 w-full h-full" style={{ width: 'calc(100% - 2rem)', height: 'calc(100% - 2rem)' }}>
              <defs>
                <pattern id="grid" width="20" height="20" patternUnits="userSpaceOnUse">
                  <path d="M 20 0 L 0 0 0 20" fill="none" stroke="#e5e7eb" strokeWidth="0.5"/>
                </pattern>
              </defs>
              <rect width="100%" height="100%" fill="url(#grid)" />
              <line x1="50%" y1="0" x2="50%" y2="100%" stroke="#d1d5db" strokeWidth="1"/>
              <line x1="0" y1="50%" x2="100%" y2="50%" stroke="#d1d5db" strokeWidth="1"/>
            </svg>
            
            {/* Brand positions */}
            {brandPositioningData.map((brand, index) => (
              <div
                key={brand.brand}
                className={`absolute transform -translate-x-1/2 -translate-y-1/2 w-3 h-3 rounded-full ${
                  brand.brand === 'Our Company' ? 'bg-blue-500' : 'bg-gray-400'
                } cursor-pointer hover:scale-150 transition-transform`}
                style={{
                  left: `${(brand.value / 100) * 80 + 10}%`,
                  top: `${100 - ((brand.quality / 100) * 80 + 10)}%`
                }}
                title={`${brand.brand}: Quality ${brand.quality}%, Value ${brand.value}%`}
              />
            ))}
          </div>
        </div>
        
        {/* Brand Metrics */}
        <div className="space-y-4">
          {brandPositioningData.map(brand => (
            <div key={brand.brand} className={`p-4 rounded-lg border ${
              brand.brand === 'Our Company' ? 'border-blue-200 bg-blue-50' : 'border-gray-200'
            }`}>
              <div className="flex items-center justify-between mb-2">
                <h4 className={`font-medium ${
                  brand.brand === 'Our Company' ? 'text-blue-600' : 'text-gray-900'
                }`}>
                  {brand.brand}
                </h4>
                <span className="text-sm text-gray-500">{brand.quadrant}</span>
              </div>
              <div className="grid grid-cols-2 gap-2 text-sm">
                <div>Quality: <span className="font-medium">{brand.quality}%</span></div>
                <div>Value: <span className="font-medium">{brand.value}%</span></div>
                <div>Innovation: <span className="font-medium">{brand.innovation}%</span></div>
                <div>Service: <span className="font-medium">{brand.service}%</span></div>
              </div>
              <div className="mt-2 text-sm">
                Overall Score: <span className="font-medium">{brand.overall}%</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </ChartContainer>
  );

  const MarketTrendComparison = () => (
    <ChartContainer
      title="Market Share Trends"
      subtitle="Competitive performance over time"
      loading={loading}
    >
      <LineChart
        data={trendData}
        height={400}
        lines={[
          { dataKey: 'Our Company', color: '#3b82f6' },
          { dataKey: 'Competitor A', color: '#ef4444' },
          { dataKey: 'Competitor B', color: '#f59e0b' },
          { dataKey: 'Industry Avg', color: '#6b7280' }
        ]}
        showLegend={true}
        loading={loading}
      />
    </ChartContainer>
  );

  const CompetitiveInsights = () => (
    <div className="bg-white rounded-lg border border-gray-200 shadow-sm">
      <div className="px-6 py-4 border-b border-gray-100">
        <h3 className="text-lg font-semibold text-gray-900">Competitive Insights</h3>
      </div>
      <div className="p-6 space-y-4">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="bg-red-50 border border-red-200 rounded-lg p-4">
            <h4 className="font-medium text-red-800">Threats</h4>
            <ul className="text-sm text-red-700 mt-2 space-y-1">
              <li>• Competitor A's aggressive pricing in Electronics</li>
              <li>• Market share decline in Fresh Products</li>
              <li>• New entrant in convenience segment</li>
            </ul>
          </div>
          <div className="bg-green-50 border border-green-200 rounded-lg p-4">
            <h4 className="font-medium text-green-800">Opportunities</h4>
            <ul className="text-sm text-green-700 mt-2 space-y-1">
              <li>• Service quality advantage over competitors</li>
              <li>• Innovation leadership in Home & Garden</li>
              <li>• Untapped potential in premium segments</li>
            </ul>
          </div>
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
            <h4 className="font-medium text-blue-800">Recommendations</h4>
            <ul className="text-sm text-blue-700 mt-2 space-y-1">
              <li>• Enhance value proposition in Electronics</li>
              <li>• Expand premium product offerings</li>
              <li>• Leverage service advantage in marketing</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );

  return (
    <div className={`space-y-6 p-6 ${className}`}>
      {/* Market Share Overview */}
      <MarketShareOverview />
      
      {/* Grid: Pricing Analysis and Brand Positioning */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
        <CompetitivePricingAnalysis />
        <BrandPositioningMatrix />
      </div>
      
      {/* Market Trend Comparison */}
      <MarketTrendComparison />
      
      {/* Competitive Insights */}
      <CompetitiveInsights />
    </div>
  );
};

export default CompetitiveTab;