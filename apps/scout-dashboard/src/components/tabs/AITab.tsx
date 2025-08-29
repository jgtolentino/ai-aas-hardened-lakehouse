import React, { useState, useEffect } from 'react';
import { ChartContainer, LineChart, BarChart, ScatterChart } from '../charts/ChartWrappers';
import { useFiltersStore, useGlobalFilters } from '../../store/filters';
import { useAIInsights, useAnomalyDetection } from '../../services/ai-integration';
import dashboardConfig from '../../config/dashboard-config.json';

export interface AITabProps {
  persona: string;
  className?: string;
}

// Mock data generators for AI insights
const generatePredictiveAnalytics = () => {
  const data = [];
  const today = new Date();
  
  // Historical data (last 30 days)
  for (let i = 30; i >= 1; i--) {
    const date = new Date(today);
    date.setDate(date.getDate() - i);
    data.push({
      date: date.toISOString().split('T')[0],
      actual: Math.random() * 200000 + 800000,
      predicted: null,
      confidence: null,
      type: 'historical'
    });
  }
  
  // Predicted data (next 30 days)
  for (let i = 0; i < 30; i++) {
    const date = new Date(today);
    date.setDate(date.getDate() + i);
    const baseValue = 850000 + (i * 5000); // Growth trend
    const seasonal = Math.sin(i / 7) * 50000; // Weekly seasonality
    const predicted = baseValue + seasonal + (Math.random() - 0.5) * 100000;
    
    data.push({
      date: date.toISOString().split('T')[0],
      actual: null,
      predicted: predicted,
      confidence: 0.75 + Math.random() * 0.2, // 75-95% confidence
      type: 'predicted'
    });
  }
  
  return data;
};

const generateRecommendations = () => [
  {
    id: '1',
    type: 'pricing',
    priority: 'high',
    title: 'Optimize Electronics Pricing',
    description: 'Electronics category shows price sensitivity. Consider 5-8% price reduction for competitive advantage.',
    impact: { revenue: '+₱2.3M', probability: 0.82 },
    confidence: 0.89,
    category: 'Pricing Strategy',
    timeline: '2-3 weeks',
    effort: 'Medium',
    tags: ['electronics', 'pricing', 'competition']
  },
  {
    id: '2',
    type: 'inventory',
    priority: 'high',
    title: 'Increase Fresh Products Inventory',
    description: 'Demand forecast shows 15% increase in fresh products. Recommend inventory increase in Metro Manila stores.',
    impact: { revenue: '+₱1.8M', probability: 0.76 },
    confidence: 0.84,
    category: 'Inventory Management',
    timeline: '1 week',
    effort: 'Low',
    tags: ['fresh-products', 'inventory', 'metro-manila']
  },
  {
    id: '3',
    type: 'expansion',
    priority: 'medium',
    title: 'New Store Location - Iloilo',
    description: 'Market analysis suggests high potential for new convenience store in Iloilo Business District.',
    impact: { revenue: '+₱850K', probability: 0.71 },
    confidence: 0.78,
    category: 'Expansion',
    timeline: '3-6 months',
    effort: 'High',
    tags: ['expansion', 'iloilo', 'convenience']
  },
  {
    id: '4',
    type: 'promotion',
    priority: 'medium',
    title: 'Target Millennials with Digital Campaigns',
    description: 'Millennial segment shows high engagement with mobile app. Recommend targeted promotions.',
    impact: { revenue: '+₱1.2M', probability: 0.68 },
    confidence: 0.73,
    category: 'Marketing',
    timeline: '2 weeks',
    effort: 'Medium',
    tags: ['millennials', 'digital', 'promotions']
  },
  {
    id: '5',
    type: 'loyalty',
    priority: 'low',
    title: 'Enhance Premium Tier Benefits',
    description: 'Platinum customers show declining engagement. Recommend enhanced benefits to improve retention.',
    impact: { revenue: '+₱650K', probability: 0.65 },
    confidence: 0.70,
    category: 'Customer Retention',
    timeline: '4 weeks',
    effort: 'Medium',
    tags: ['loyalty', 'premium', 'retention']
  }
];

const generateTrendForecasting = () => {
  const categories = ['Electronics', 'Fresh Products', 'FMCG', 'Apparel', 'Home & Garden'];
  return categories.map(category => ({
    category,
    currentTrend: Math.random() * 20 - 5, // -5% to +15%
    forecast30Day: Math.random() * 25 - 5, // -5% to +20%
    forecast90Day: Math.random() * 30 - 10, // -10% to +20%
    confidence: 0.6 + Math.random() * 0.3, // 60-90%
    factors: [
      'Seasonal demand',
      'Economic indicators',
      'Competitor actions',
      'Consumer behavior'
    ].slice(0, Math.floor(Math.random() * 3) + 2)
  }));
};

const generateAnomalyData = () => [
  {
    id: '1',
    timestamp: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
    type: 'revenue_spike',
    severity: 'medium',
    title: 'Unusual Revenue Spike - Electronics',
    description: 'Electronics category showing 35% above normal revenue in Cebu stores',
    value: 1.35,
    threshold: 1.2,
    affectedStores: ['CB001', 'CB002'],
    possibleCauses: ['New product launch', 'Competitor promotion ended', 'Supply shortage elsewhere']
  },
  {
    id: '2',
    timestamp: new Date(Date.now() - 4 * 60 * 60 * 1000).toISOString(),
    type: 'inventory_low',
    severity: 'high',
    title: 'Critical Inventory Levels - Fresh Products',
    description: 'Multiple fresh product SKUs below safety stock in Metro Manila',
    value: 0.15,
    threshold: 0.20,
    affectedStores: ['MM001', 'MM003', 'MM004'],
    possibleCauses: ['Supply chain delay', 'Unexpected demand surge', 'Delivery issues']
  },
  {
    id: '3',
    timestamp: new Date(Date.now() - 6 * 60 * 60 * 1000).toISOString(),
    type: 'customer_behavior',
    severity: 'low',
    title: 'Unusual Shopping Pattern - Evening Traffic',
    description: 'Evening customer traffic 20% below normal across multiple regions',
    value: 0.8,
    threshold: 0.9,
    affectedStores: ['MM002', 'DV001', 'IL001'],
    possibleCauses: ['Weather conditions', 'Local events', 'Economic factors']
  }
];

const generateModelPerformanceData = () => [
  { model: 'Revenue Forecasting', accuracy: 87.3, precision: 84.2, recall: 89.1, f1Score: 86.6 },
  { model: 'Demand Prediction', accuracy: 82.7, precision: 79.8, recall: 85.4, f1Score: 82.5 },
  { model: 'Customer Segmentation', accuracy: 91.2, precision: 88.7, recall: 93.5, f1Score: 91.0 },
  { model: 'Price Optimization', accuracy: 76.8, precision: 74.3, recall: 79.2, f1Score: 76.7 },
  { model: 'Churn Prediction', accuracy: 84.9, precision: 81.5, recall: 88.1, f1Score: 84.7 }
];

export const AITab: React.FC<AITabProps> = ({
  persona,
  className = ''
}) => {
  const filters = useGlobalFilters();
  const { insights, loading: insightsLoading, refreshInsights } = useAIInsights('overview');
  const { anomalies, clearAnomalies } = useAnomalyDetection();
  
  const [predictiveData, setPredictiveData] = useState(generatePredictiveAnalytics());
  const [recommendations, setRecommendations] = useState(generateRecommendations());
  const [trendForecasts, setTrendForecasts] = useState(generateTrendForecasting());
  const [anomalyData, setAnomalyData] = useState(generateAnomalyData());
  const [modelPerformance, setModelPerformance] = useState(generateModelPerformanceData());
  const [loading, setLoading] = useState(false);
  const [selectedRecommendation, setSelectedRecommendation] = useState<string | null>(null);

  // Simulate data refresh when filters change
  useEffect(() => {
    setLoading(true);
    const timer = setTimeout(() => {
      setPredictiveData(generatePredictiveAnalytics());
      setRecommendations(generateRecommendations());
      setTrendForecasts(generateTrendForecasting());
      setAnomalyData(generateAnomalyData());
      setModelPerformance(generateModelPerformanceData());
      setLoading(false);
    }, 1200); // Longer loading for AI processing simulation

    return () => clearTimeout(timer);
  }, [filters]);

  const PredictiveAnalytics = () => (
    <ChartContainer
      title="Revenue Forecasting"
      subtitle="30-day predictive analytics with confidence intervals"
      loading={loading}
    >
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <div className="flex items-center space-x-2">
              <div className="w-3 h-3 bg-blue-500 rounded-full"></div>
              <span className="text-sm text-gray-600">Historical</span>
            </div>
            <div className="flex items-center space-x-2">
              <div className="w-3 h-3 bg-green-500 rounded-full"></div>
              <span className="text-sm text-gray-600">Predicted</span>
            </div>
            <div className="flex items-center space-x-2">
              <div className="w-3 h-1 bg-gray-300"></div>
              <span className="text-sm text-gray-600">Confidence Band</span>
            </div>
          </div>
          <div className="flex items-center space-x-2">
            <div className="w-2 h-2 bg-purple-500 rounded-full animate-pulse"></div>
            <span className="text-sm text-gray-600">AI Processing</span>
          </div>
        </div>
        
        <LineChart
          data={predictiveData.map(d => ({
            date: d.date,
            Historical: d.actual,
            Predicted: d.predicted,
            confidence: d.confidence
          }))}
          height={350}
          lines={[
            { dataKey: 'Historical', color: '#3b82f6' },
            { dataKey: 'Predicted', color: '#10b981' }
          ]}
          showLegend={true}
          loading={loading}
        />
      </div>
    </ChartContainer>
  );

  const RecommendationsEngine = () => (
    <ChartContainer
      title="AI Recommendations"
      subtitle="Actionable insights ranked by impact and confidence"
      loading={loading}
    >
      <div className="space-y-4">
        {/* Summary Cards */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="bg-red-50 border border-red-200 rounded-lg p-3">
            <div className="text-red-800 font-medium">High Priority</div>
            <div className="text-2xl font-bold text-red-900">
              {recommendations.filter(r => r.priority === 'high').length}
            </div>
          </div>
          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3">
            <div className="text-yellow-800 font-medium">Medium Priority</div>
            <div className="text-2xl font-bold text-yellow-900">
              {recommendations.filter(r => r.priority === 'medium').length}
            </div>
          </div>
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
            <div className="text-blue-800 font-medium">Potential Revenue</div>
            <div className="text-2xl font-bold text-blue-900">₱6.8M</div>
          </div>
          <div className="bg-green-50 border border-green-200 rounded-lg p-3">
            <div className="text-green-800 font-medium">Avg Confidence</div>
            <div className="text-2xl font-bold text-green-900">78%</div>
          </div>
        </div>

        {/* Recommendations List */}
        <div className="space-y-3">
          {recommendations.map(rec => (
            <div 
              key={rec.id} 
              className={`border rounded-lg p-4 cursor-pointer transition-colors ${
                selectedRecommendation === rec.id 
                  ? 'border-blue-500 bg-blue-50' 
                  : 'border-gray-200 hover:border-gray-300'
              }`}
              onClick={() => setSelectedRecommendation(selectedRecommendation === rec.id ? null : rec.id)}
            >
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center space-x-2 mb-2">
                    <span className={`inline-block px-2 py-1 text-xs font-medium rounded-full ${
                      rec.priority === 'high' ? 'bg-red-100 text-red-800' :
                      rec.priority === 'medium' ? 'bg-yellow-100 text-yellow-800' :
                      'bg-blue-100 text-blue-800'
                    }`}>
                      {rec.priority.toUpperCase()}
                    </span>
                    <span className="text-sm text-gray-500">{rec.category}</span>
                  </div>
                  <h4 className="font-medium text-gray-900 mb-1">{rec.title}</h4>
                  <p className="text-sm text-gray-600 mb-3">{rec.description}</p>
                  
                  <div className="flex flex-wrap gap-1 mb-2">
                    {rec.tags.map(tag => (
                      <span key={tag} className="inline-block px-2 py-1 bg-gray-100 text-gray-700 text-xs rounded">
                        {tag}
                      </span>
                    ))}
                  </div>
                </div>
                
                <div className="ml-4 text-right">
                  <div className="text-lg font-bold text-green-600">{rec.impact.revenue}</div>
                  <div className="text-sm text-gray-500">{(rec.impact.probability * 100).toFixed(0)}% probable</div>
                  <div className="text-xs text-gray-400 mt-2">
                    Confidence: {(rec.confidence * 100).toFixed(0)}%
                  </div>
                </div>
              </div>
              
              {selectedRecommendation === rec.id && (
                <div className="mt-4 pt-4 border-t border-gray-200">
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
                    <div>
                      <span className="text-gray-600">Timeline:</span>
                      <div className="font-medium">{rec.timeline}</div>
                    </div>
                    <div>
                      <span className="text-gray-600">Effort Required:</span>
                      <div className="font-medium">{rec.effort}</div>
                    </div>
                    <div>
                      <span className="text-gray-600">Success Rate:</span>
                      <div className="font-medium">{(rec.impact.probability * 100).toFixed(0)}%</div>
                    </div>
                  </div>
                  <div className="mt-4 flex space-x-2">
                    <button className="px-4 py-2 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700">
                      Implement Recommendation
                    </button>
                    <button className="px-4 py-2 bg-gray-200 text-gray-700 text-sm rounded-lg hover:bg-gray-300">
                      Learn More
                    </button>
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </ChartContainer>
  );

  const TrendForecasting = () => (
    <ChartContainer
      title="Trend Forecasting"
      subtitle="Category performance predictions with confidence levels"
      loading={loading}
    >
      <div className="overflow-x-auto">
        <table className="w-full border-collapse">
          <thead>
            <tr className="bg-gray-50">
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-700 border-b">Category</th>
              <th className="px-4 py-3 text-center text-sm font-medium text-gray-700 border-b">Current Trend</th>
              <th className="px-4 py-3 text-center text-sm font-medium text-gray-700 border-b">30-Day Forecast</th>
              <th className="px-4 py-3 text-center text-sm font-medium text-gray-700 border-b">90-Day Forecast</th>
              <th className="px-4 py-3 text-center text-sm font-medium text-gray-700 border-b">Confidence</th>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-700 border-b">Key Factors</th>
            </tr>
          </thead>
          <tbody>
            {trendForecasts.map(forecast => (
              <tr key={forecast.category} className="border-b hover:bg-gray-50">
                <td className="px-4 py-3 text-sm font-medium text-gray-900">
                  {forecast.category}
                </td>
                <td className="px-4 py-3 text-center">
                  <span className={`text-sm font-medium ${
                    forecast.currentTrend > 0 ? 'text-green-600' : 'text-red-600'
                  }`}>
                    {forecast.currentTrend > 0 ? '+' : ''}{forecast.currentTrend.toFixed(1)}%
                  </span>
                </td>
                <td className="px-4 py-3 text-center">
                  <span className={`text-sm font-medium ${
                    forecast.forecast30Day > 0 ? 'text-green-600' : 'text-red-600'
                  }`}>
                    {forecast.forecast30Day > 0 ? '+' : ''}{forecast.forecast30Day.toFixed(1)}%
                  </span>
                </td>
                <td className="px-4 py-3 text-center">
                  <span className={`text-sm font-medium ${
                    forecast.forecast90Day > 0 ? 'text-green-600' : 'text-red-600'
                  }`}>
                    {forecast.forecast90Day > 0 ? '+' : ''}{forecast.forecast90Day.toFixed(1)}%
                  </span>
                </td>
                <td className="px-4 py-3 text-center">
                  <div className="flex items-center justify-center space-x-2">
                    <div className="w-16 bg-gray-200 rounded-full h-2">
                      <div
                        className={`h-2 rounded-full ${
                          forecast.confidence > 0.8 ? 'bg-green-500' : 
                          forecast.confidence > 0.6 ? 'bg-yellow-500' : 'bg-red-500'
                        }`}
                        style={{ width: `${forecast.confidence * 100}%` }}
                      />
                    </div>
                    <span className="text-xs text-gray-600">
                      {(forecast.confidence * 100).toFixed(0)}%
                    </span>
                  </div>
                </td>
                <td className="px-4 py-3 text-sm text-gray-600">
                  <div className="flex flex-wrap gap-1">
                    {forecast.factors.map(factor => (
                      <span key={factor} className="inline-block px-2 py-1 bg-gray-100 text-gray-700 text-xs rounded">
                        {factor}
                      </span>
                    ))}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </ChartContainer>
  );

  const AnomalyDetection = () => (
    <ChartContainer
      title="Anomaly Detection"
      subtitle="Real-time detection of unusual patterns and outliers"
      loading={loading}
    >
      <div className="space-y-4">
        {anomalyData.map(anomaly => (
          <div key={anomaly.id} className={`border rounded-lg p-4 ${
            anomaly.severity === 'high' ? 'border-red-300 bg-red-50' :
            anomaly.severity === 'medium' ? 'border-yellow-300 bg-yellow-50' :
            'border-blue-300 bg-blue-50'
          }`}>
            <div className="flex items-start justify-between">
              <div className="flex-1">
                <div className="flex items-center space-x-2 mb-2">
                  <span className={`inline-block px-2 py-1 text-xs font-medium rounded-full ${
                    anomaly.severity === 'high' ? 'bg-red-200 text-red-800' :
                    anomaly.severity === 'medium' ? 'bg-yellow-200 text-yellow-800' :
                    'bg-blue-200 text-blue-800'
                  }`}>
                    {anomaly.severity.toUpperCase()}
                  </span>
                  <span className="text-sm text-gray-500">
                    {new Date(anomaly.timestamp).toLocaleString()}
                  </span>
                </div>
                <h4 className="font-medium text-gray-900 mb-1">{anomaly.title}</h4>
                <p className="text-sm text-gray-600 mb-3">{anomaly.description}</p>
                
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                  <div>
                    <span className="text-gray-600">Affected Stores:</span>
                    <div className="font-medium">{anomaly.affectedStores.join(', ')}</div>
                  </div>
                  <div>
                    <span className="text-gray-600">Threshold:</span>
                    <div className="font-medium">
                      {anomaly.value.toFixed(2)} vs {anomaly.threshold.toFixed(2)} threshold
                    </div>
                  </div>
                </div>
              </div>
              
              <div className="ml-4">
                <div className={`w-16 h-16 rounded-full flex items-center justify-center ${
                  anomaly.severity === 'high' ? 'bg-red-500' :
                  anomaly.severity === 'medium' ? 'bg-yellow-500' :
                  'bg-blue-500'
                } text-white font-bold text-lg`}>
                  {anomaly.severity === 'high' ? '!' : anomaly.severity === 'medium' ? '⚠' : 'i'}
                </div>
              </div>
            </div>
            
            <div className="mt-4 pt-4 border-t border-gray-200">
              <div className="mb-2">
                <span className="text-sm font-medium text-gray-700">Possible Causes:</span>
              </div>
              <div className="flex flex-wrap gap-2">
                {anomaly.possibleCauses.map(cause => (
                  <span key={cause} className="inline-block px-3 py-1 bg-white border rounded-full text-sm">
                    {cause}
                  </span>
                ))}
              </div>
            </div>
          </div>
        ))}
      </div>
    </ChartContainer>
  );

  const ModelPerformance = () => (
    <ChartContainer
      title="AI Model Performance"
      subtitle="Real-time performance metrics of deployed models"
      loading={loading}
    >
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Performance Chart */}
        <div>
          <BarChart
            data={modelPerformance.map(m => ({ name: m.model, value: m.accuracy }))}
            height={300}
            color="#8b5cf6"
            title="Model Accuracy (%)"
            loading={loading}
          />
        </div>
        
        {/* Performance Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50">
                <th className="px-3 py-2 text-left font-medium text-gray-700">Model</th>
                <th className="px-3 py-2 text-center font-medium text-gray-700">Accuracy</th>
                <th className="px-3 py-2 text-center font-medium text-gray-700">Precision</th>
                <th className="px-3 py-2 text-center font-medium text-gray-700">F1</th>
              </tr>
            </thead>
            <tbody>
              {modelPerformance.map(model => (
                <tr key={model.model} className="border-b hover:bg-gray-50">
                  <td className="px-3 py-2 font-medium text-gray-900">{model.model}</td>
                  <td className="px-3 py-2 text-center">{model.accuracy.toFixed(1)}%</td>
                  <td className="px-3 py-2 text-center">{model.precision.toFixed(1)}%</td>
                  <td className="px-3 py-2 text-center">{model.f1Score.toFixed(1)}%</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </ChartContainer>
  );

  return (
    <div className={`space-y-6 p-6 ${className}`}>
      {/* AI Status Banner */}
      <div className="bg-gradient-to-r from-purple-600 to-blue-600 rounded-lg p-6 text-white">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-xl font-bold mb-2">AI Intelligence Engine</h2>
            <p className="text-purple-100">
              Powered by advanced machine learning models processing {dashboardConfig.ai_integration.mode} data
            </p>
          </div>
          <div className="text-right">
            <div className="flex items-center space-x-2">
              <div className="w-3 h-3 bg-green-400 rounded-full animate-pulse"></div>
              <span className="text-sm">Models Active</span>
            </div>
            <div className="text-sm text-purple-100 mt-1">Last Updated: Just now</div>
          </div>
        </div>
      </div>

      {/* Predictive Analytics */}
      <PredictiveAnalytics />
      
      {/* AI Recommendations */}
      <RecommendationsEngine />
      
      {/* Grid: Trend Forecasting and Anomaly Detection */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
        <TrendForecasting />
        <AnomalyDetection />
      </div>
      
      {/* Model Performance */}
      <ModelPerformance />
    </div>
  );
};

export default AITab;