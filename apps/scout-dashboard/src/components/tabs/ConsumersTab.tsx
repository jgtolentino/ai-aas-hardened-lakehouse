import React, { useState, useEffect } from 'react';
import { ChartContainer, PieChart, BarChart, LineChart, DonutChart } from '../charts/ChartWrappers';
import { useFiltersStore, useGlobalFilters } from '../../store/filters';
import { useAIInsights } from '../../services/ai-integration';
import dashboardConfig from '../../config/dashboard-config.json';

export interface ConsumersTabProps {
  persona: string;
  className?: string;
}

// Mock data generators for consumer analysis
const generateDemographicBreakdownData = () => [
  { segment: 'Young Professionals (25-35)', count: 145000, percentage: 28.5, avgSpend: 520, frequency: 2.3 },
  { segment: 'Families (35-50)', count: 132000, percentage: 26.0, avgSpend: 680, frequency: 1.8 },
  { segment: 'Millennials (20-35)', count: 118000, percentage: 23.2, avgSpend: 450, frequency: 2.8 },
  { segment: 'Gen X (40-55)', count: 85000, percentage: 16.7, avgSpend: 580, frequency: 1.5 },
  { segment: 'Seniors (55+)', count: 28000, percentage: 5.6, avgSpend: 380, frequency: 1.2 }
];

const generatePurchasePatternsData = () => {
  const hours = Array.from({ length: 24 }, (_, i) => i);
  return hours.map(hour => {
    let traffic;
    if (hour >= 6 && hour <= 9) traffic = Math.random() * 30 + 70; // Morning peak
    else if (hour >= 11 && hour <= 13) traffic = Math.random() * 25 + 60; // Lunch peak
    else if (hour >= 17 && hour <= 20) traffic = Math.random() * 40 + 80; // Evening peak
    else if (hour >= 21 || hour <= 5) traffic = Math.random() * 20 + 10; // Night/early morning
    else traffic = Math.random() * 30 + 40; // Regular hours
    
    return {
      hour: hour,
      traffic: Math.round(traffic),
      transactions: Math.round(traffic * 0.8),
      avgSpend: Math.round(300 + Math.random() * 200),
      timeLabel: `${hour.toString().padStart(2, '0')}:00`
    };
  });
};

const generateLoyaltyMetricsData = () => [
  { tier: 'Platinum', customers: 12500, percentage: 2.5, avgSpend: 2150, visits: 8.2, retention: 95 },
  { tier: 'Gold', customers: 48000, percentage: 9.4, avgSpend: 1450, visits: 5.8, retention: 87 },
  { tier: 'Silver', customers: 125000, percentage: 24.6, avgSpend: 850, visits: 3.2, retention: 73 },
  { tier: 'Bronze', customers: 187000, percentage: 36.8, avgSpend: 520, visits: 2.1, retention: 58 },
  { tier: 'New', customers: 136500, percentage: 26.7, avgSpend: 380, visits: 1.4, retention: 42 }
];

const generateConsumerJourneyData = () => [
  { 
    stage: 'Awareness',
    touchpoints: ['Social Media', 'TV Ads', 'Word of Mouth'],
    engagement: 85,
    conversion: 15,
    dropoff: 85,
    avgTime: '2.3 days'
  },
  { 
    stage: 'Consideration',
    touchpoints: ['Website', 'Store Visit', 'Mobile App'],
    engagement: 72,
    conversion: 35,
    dropoff: 65,
    avgTime: '4.7 days'
  },
  { 
    stage: 'Purchase',
    touchpoints: ['In-Store', 'Online', 'Mobile'],
    engagement: 95,
    conversion: 78,
    dropoff: 22,
    avgTime: '1.2 days'
  },
  { 
    stage: 'Post-Purchase',
    touchpoints: ['Email', 'SMS', 'App Notifications'],
    engagement: 45,
    conversion: 68,
    dropoff: 32,
    avgTime: '7.5 days'
  },
  { 
    stage: 'Loyalty',
    touchpoints: ['Rewards Program', 'Personalized Offers', 'VIP Events'],
    engagement: 82,
    conversion: 85,
    dropoff: 15,
    avgTime: 'Ongoing'
  }
];

const generateSegmentPerformanceData = (days: number = 30) => {
  const segments = ['Young Professionals', 'Families', 'Millennials', 'Gen X', 'Seniors'];
  const data = [];
  
  for (let i = days; i >= 0; i--) {
    const date = new Date();
    date.setDate(date.getDate() - i);
    
    const entry: any = {
      date: date.toISOString().split('T')[0]
    };
    
    segments.forEach(segment => {
      const baseValue = Math.random() * 50000 + 20000;
      const weekendFactor = [0, 6].includes(date.getDay()) ? 1.2 : 1.0;
      entry[segment] = Math.round(baseValue * weekendFactor);
    });
    
    data.push(entry);
  }
  
  return data;
};

export const ConsumersTab: React.FC<ConsumersTabProps> = ({
  persona,
  className = ''
}) => {
  const filters = useGlobalFilters();
  const { insights, loading: insightsLoading, refreshInsights } = useAIInsights('consumers');
  
  const [demographicData, setDemographicData] = useState(generateDemographicBreakdownData());
  const [purchasePatterns, setPurchasePatterns] = useState(generatePurchasePatternsData());
  const [loyaltyData, setLoyaltyData] = useState(generateLoyaltyMetricsData());
  const [journeyData, setJourneyData] = useState(generateConsumerJourneyData());
  const [segmentTrends, setSegmentTrends] = useState(generateSegmentPerformanceData());
  const [loading, setLoading] = useState(false);
  const [selectedSegment, setSelectedSegment] = useState<string | null>(null);

  // Simulate data refresh when filters change
  useEffect(() => {
    setLoading(true);
    const timer = setTimeout(() => {
      setDemographicData(generateDemographicBreakdownData());
      setPurchasePatterns(generatePurchasePatternsData());
      setLoyaltyData(generateLoyaltyMetricsData());
      setJourneyData(generateConsumerJourneyData());
      setSegmentTrends(generateSegmentPerformanceData());
      setLoading(false);
    }, 800);

    return () => clearTimeout(timer);
  }, [filters]);

  const DemographicBreakdown = () => (
    <ChartContainer
      title="Customer Demographics"
      subtitle="Age and lifestyle segment distribution"
      loading={loading}
    >
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Demographic Pie Chart */}
        <div>
          <DonutChart
            data={demographicData.map(d => ({ 
              name: d.segment, 
              value: d.count,
              percentage: d.percentage 
            }))}
            height={300}
            showLegend={true}
            centerLabel="Total Customers"
            centerValue={demographicData.reduce((sum, d) => sum + d.count, 0).toLocaleString()}
            loading={loading}
          />
        </div>
        
        {/* Segment Details */}
        <div className="space-y-3">
          {demographicData.map((segment, index) => (
            <div 
              key={segment.segment} 
              className={`p-4 rounded-lg border cursor-pointer transition-colors ${
                selectedSegment === segment.segment 
                  ? 'border-blue-500 bg-blue-50' 
                  : 'border-gray-200 hover:border-gray-300'
              }`}
              onClick={() => setSelectedSegment(selectedSegment === segment.segment ? null : segment.segment)}
            >
              <div className="flex items-center justify-between mb-2">
                <h4 className="font-medium text-gray-900 text-sm">{segment.segment}</h4>
                <span className="text-sm font-medium text-blue-600">{segment.percentage}%</span>
              </div>
              <div className="grid grid-cols-3 gap-2 text-xs">
                <div>
                  <span className="text-gray-500">Customers:</span>
                  <div className="font-medium">{(segment.count / 1000).toFixed(0)}K</div>
                </div>
                <div>
                  <span className="text-gray-500">Avg Spend:</span>
                  <div className="font-medium">₱{segment.avgSpend}</div>
                </div>
                <div>
                  <span className="text-gray-500">Frequency:</span>
                  <div className="font-medium">{segment.frequency}/mo</div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </ChartContainer>
  );

  const PurchasePatternsAnalysis = () => (
    <ChartContainer
      title="Purchase Patterns"
      subtitle="Customer traffic and spending throughout the day"
      loading={loading}
    >
      <div className="space-y-6">
        {/* Hourly Traffic Chart */}
        <BarChart
          data={purchasePatterns.map(p => ({ 
            name: p.timeLabel, 
            value: p.traffic,
            transactions: p.transactions,
            avgSpend: p.avgSpend
          }))}
          height={300}
          color="#3b82f6"
          title="Hourly Customer Traffic"
          loading={loading}
        />
        
        {/* Peak Hours Summary */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {[
            { name: 'Morning Peak', time: '7:00-9:00 AM', traffic: 85, color: 'bg-yellow-500' },
            { name: 'Lunch Rush', time: '11:00 AM-1:00 PM', traffic: 72, color: 'bg-orange-500' },
            { name: 'Evening Peak', time: '5:00-8:00 PM', traffic: 95, color: 'bg-red-500' }
          ].map(peak => (
            <div key={peak.name} className="bg-gray-50 rounded-lg p-4">
              <div className="flex items-center space-x-2 mb-2">
                <div className={`w-3 h-3 rounded-full ${peak.color}`}></div>
                <h4 className="font-medium text-gray-900">{peak.name}</h4>
              </div>
              <p className="text-sm text-gray-600 mb-2">{peak.time}</p>
              <div className="flex items-center space-x-2">
                <div className="flex-1 bg-gray-200 rounded-full h-2">
                  <div 
                    className={`h-2 rounded-full ${peak.color}`}
                    style={{ width: `${peak.traffic}%` }}
                  />
                </div>
                <span className="text-sm font-medium text-gray-700">{peak.traffic}%</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </ChartContainer>
  );

  const LoyaltyProgram = () => (
    <ChartContainer
      title="Loyalty Program Performance"
      subtitle="Customer tiers and retention metrics"
      loading={loading}
    >
      <div className="space-y-6">
        {/* Loyalty Tier Distribution */}
        <div className="grid grid-cols-1 lg:grid-cols-5 gap-4">
          {loyaltyData.map(tier => (
            <div key={tier.tier} className={`p-4 rounded-lg border-2 ${
              tier.tier === 'Platinum' ? 'border-purple-300 bg-purple-50' :
              tier.tier === 'Gold' ? 'border-yellow-300 bg-yellow-50' :
              tier.tier === 'Silver' ? 'border-gray-300 bg-gray-50' :
              tier.tier === 'Bronze' ? 'border-orange-300 bg-orange-50' :
              'border-blue-300 bg-blue-50'
            }`}>
              <div className="text-center">
                <h4 className={`font-bold text-lg ${
                  tier.tier === 'Platinum' ? 'text-purple-700' :
                  tier.tier === 'Gold' ? 'text-yellow-700' :
                  tier.tier === 'Silver' ? 'text-gray-700' :
                  tier.tier === 'Bronze' ? 'text-orange-700' :
                  'text-blue-700'
                }`}>
                  {tier.tier}
                </h4>
                <p className="text-2xl font-bold text-gray-900 mt-1">
                  {(tier.customers / 1000).toFixed(0)}K
                </p>
                <p className="text-sm text-gray-600">{tier.percentage}% of customers</p>
              </div>
              <div className="mt-4 space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-600">Avg Spend:</span>
                  <span className="font-medium">₱{tier.avgSpend}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Visits/Month:</span>
                  <span className="font-medium">{tier.visits}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Retention:</span>
                  <span className="font-medium">{tier.retention}%</span>
                </div>
              </div>
            </div>
          ))}
        </div>
        
        {/* Loyalty Metrics Summary */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="bg-white border rounded-lg p-4">
            <h4 className="text-sm font-medium text-gray-600">Program Enrollment</h4>
            <p className="text-2xl font-bold text-gray-900 mt-1">73.2%</p>
            <p className="text-xs text-green-600 mt-1">↗ +2.3% vs last month</p>
          </div>
          <div className="bg-white border rounded-lg p-4">
            <h4 className="text-sm font-medium text-gray-600">Active Members</h4>
            <p className="text-2xl font-bold text-gray-900 mt-1">421K</p>
            <p className="text-xs text-green-600 mt-1">↗ +8.7% vs last month</p>
          </div>
          <div className="bg-white border rounded-lg p-4">
            <h4 className="text-sm font-medium text-gray-600">Avg Member Spend</h4>
            <p className="text-2xl font-bold text-gray-900 mt-1">₱785</p>
            <p className="text-xs text-green-600 mt-1">↗ +5.2% vs last month</p>
          </div>
          <div className="bg-white border rounded-lg p-4">
            <h4 className="text-sm font-medium text-gray-600">Redemption Rate</h4>
            <p className="text-2xl font-bold text-gray-900 mt-1">68.9%</p>
            <p className="text-xs text-red-600 mt-1">↘ -1.1% vs last month</p>
          </div>
        </div>
      </div>
    </ChartContainer>
  );

  const CustomerJourney = () => (
    <ChartContainer
      title="Customer Journey Analysis"
      subtitle="Touchpoint engagement and conversion funnel"
      loading={loading}
    >
      <div className="space-y-6">
        {/* Journey Stages */}
        <div className="relative">
          <div className="flex items-center justify-between">
            {journeyData.map((stage, index) => (
              <div key={stage.stage} className="flex-1 text-center relative">
                <div className={`inline-flex items-center justify-center w-12 h-12 rounded-full ${
                  stage.conversion > 70 ? 'bg-green-500' :
                  stage.conversion > 50 ? 'bg-yellow-500' : 'bg-red-500'
                } text-white font-bold mb-2`}>
                  {stage.conversion}%
                </div>
                <h4 className="font-medium text-gray-900 text-sm">{stage.stage}</h4>
                <p className="text-xs text-gray-500 mt-1">Avg Time: {stage.avgTime}</p>
                
                {/* Connection Arrow */}
                {index < journeyData.length - 1 && (
                  <div className="absolute top-6 right-0 transform translate-x-1/2 text-gray-400">
                    →
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
        
        {/* Stage Details */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div>
            <h4 className="font-medium text-gray-900 mb-4">Engagement by Stage</h4>
            <BarChart
              data={journeyData.map(stage => ({ 
                name: stage.stage, 
                value: stage.engagement 
              }))}
              height={250}
              color="#8b5cf6"
              loading={loading}
            />
          </div>
          
          <div>
            <h4 className="font-medium text-gray-900 mb-4">Top Touchpoints</h4>
            <div className="space-y-3">
              {journeyData.map(stage => (
                <div key={stage.stage} className="border rounded-lg p-3">
                  <h5 className="font-medium text-sm text-gray-900 mb-2">{stage.stage}</h5>
                  <div className="flex flex-wrap gap-1">
                    {stage.touchpoints.map(touchpoint => (
                      <span 
                        key={touchpoint} 
                        className="inline-block px-2 py-1 bg-blue-100 text-blue-800 text-xs rounded-full"
                      >
                        {touchpoint}
                      </span>
                    ))}
                  </div>
                  <div className="mt-2 flex items-center justify-between text-xs text-gray-600">
                    <span>Engagement: {stage.engagement}%</span>
                    <span>Conversion: {stage.conversion}%</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </ChartContainer>
  );

  const SegmentTrendAnalysis = () => (
    <ChartContainer
      title="Segment Performance Trends"
      subtitle="Customer segment revenue trends over time"
      loading={loading}
    >
      <LineChart
        data={segmentTrends}
        height={350}
        lines={[
          { dataKey: 'Young Professionals', color: '#3b82f6' },
          { dataKey: 'Families', color: '#10b981' },
          { dataKey: 'Millennials', color: '#f59e0b' },
          { dataKey: 'Gen X', color: '#ef4444' },
          { dataKey: 'Seniors', color: '#8b5cf6' }
        ]}
        showLegend={true}
        loading={loading}
      />
    </ChartContainer>
  );

  return (
    <div className={`space-y-6 p-6 ${className}`}>
      {/* Demographic Breakdown */}
      <DemographicBreakdown />
      
      {/* Purchase Patterns */}
      <PurchasePatternsAnalysis />
      
      {/* Loyalty Program */}
      <LoyaltyProgram />
      
      {/* Customer Journey */}
      <CustomerJourney />
      
      {/* Segment Trends */}
      <SegmentTrendAnalysis />
    </div>
  );
};

export default ConsumersTab;