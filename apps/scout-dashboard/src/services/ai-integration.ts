import { useFiltersStore } from '../store/filters';

// AI Insight types
export interface AIInsight {
  id: string;
  type: 'trend_analysis' | 'anomaly_detection' | 'recommendation' | 'prediction' | 'optimization';
  category: 'overview' | 'mix' | 'competitive' | 'geography' | 'consumers';
  title: string;
  description: string;
  confidence: 'high' | 'medium' | 'low';
  impact: 'high' | 'medium' | 'low';
  actionable: boolean;
  metadata: {
    dataPoints: string[];
    timeframe: string;
    affectedMetrics: string[];
    relatedFilters?: any;
  };
  recommendation?: {
    action: string;
    expectedImpact: string;
    priority: 'urgent' | 'high' | 'medium' | 'low';
    effort: 'low' | 'medium' | 'high';
  };
  generatedAt: string;
}

export interface AIAnalysisRequest {
  tabId: string;
  filters: any;
  metrics: string[];
  analysisType: 'realtime' | 'historical' | 'predictive';
  context?: {
    persona: string;
    timeframe: string;
    businessGoals: string[];
  };
}

export interface AIAnalysisResponse {
  insights: AIInsight[];
  summary: {
    totalInsights: number;
    highConfidenceCount: number;
    actionableCount: number;
    criticalAnomalies: number;
  };
  processingTime: number;
  dataFreshness: string;
}

// MCP Dev Mode AI Service
export class MCPAIService {
  private static instance: MCPAIService;
  private isDevMode: boolean = true; // Token-free mode
  private claudeDesktopRouting: boolean = true;

  private constructor() {
    this.initializeMCPConnection();
  }

  public static getInstance(): MCPAIService {
    if (!MCPAIService.instance) {
      MCPAIService.instance = new MCPAIService();
    }
    return MCPAIService.instance;
  }

  private async initializeMCPConnection(): Promise<void> {
    try {
      // In dev mode, we route through Claude Desktop MCP without tokens
      if (this.isDevMode && this.claudeDesktopRouting) {
        console.log('🤖 MCP AI Service initialized in dev mode with Claude Desktop routing');
        return;
      }

      // Production mode would require proper MCP server setup
      console.log('🤖 MCP AI Service initialized in production mode');
    } catch (error) {
      console.error('Failed to initialize MCP connection:', error);
    }
  }

  // Generate AI insights for current tab and filters
  public async generateInsights(request: AIAnalysisRequest): Promise<AIAnalysisResponse> {
    const startTime = Date.now();

    try {
      // In dev mode, generate mock insights based on current context
      if (this.isDevMode) {
        const insights = this.generateMockInsights(request);
        const processingTime = Date.now() - startTime;
        
        return {
          insights,
          summary: {
            totalInsights: insights.length,
            highConfidenceCount: insights.filter(i => i.confidence === 'high').length,
            actionableCount: insights.filter(i => i.actionable).length,
            criticalAnomalies: insights.filter(i => i.type === 'anomaly_detection').length
          },
          processingTime,
          dataFreshness: 'live'
        };
      }

      // Production implementation would make actual MCP calls
      return await this.callMCPAIService(request);

    } catch (error) {
      console.error('AI insight generation failed:', error);
      throw new Error('Failed to generate AI insights');
    }
  }

  // Mock insight generation for dev mode
  private generateMockInsights(request: AIAnalysisRequest): AIInsight[] {
    const insights: AIInsight[] = [];
    const currentTime = new Date().toISOString();

    // Tab-specific insights
    switch (request.tabId) {
      case 'overview':
        insights.push(
          {
            id: 'insight_overview_1',
            type: 'trend_analysis',
            category: 'overview',
            title: 'Revenue Growth Acceleration Detected',
            description: 'Revenue has grown 15.3% compared to the same period last year, outpacing industry average by 4.2 percentage points.',
            confidence: 'high',
            impact: 'high',
            actionable: true,
            metadata: {
              dataPoints: ['revenue', 'yoy_growth', 'industry_benchmark'],
              timeframe: 'last_30_days',
              affectedMetrics: ['total_revenue', 'growth_rate']
            },
            recommendation: {
              action: 'Increase marketing spend in top-performing regions',
              expectedImpact: 'Additional 8-12% revenue growth',
              priority: 'high',
              effort: 'medium'
            },
            generatedAt: currentTime
          },
          {
            id: 'insight_overview_2',
            type: 'anomaly_detection',
            category: 'overview',
            title: 'Unusual Weekend Sales Spike',
            description: 'Weekend sales have increased by 23% compared to typical weekend patterns, suggesting changing consumer behavior.',
            confidence: 'medium',
            impact: 'medium',
            actionable: true,
            metadata: {
              dataPoints: ['weekend_sales', 'historical_patterns'],
              timeframe: 'last_7_days',
              affectedMetrics: ['daily_revenue', 'transaction_count']
            },
            recommendation: {
              action: 'Optimize weekend staffing and inventory',
              expectedImpact: 'Improved customer experience and sales capture',
              priority: 'medium',
              effort: 'low'
            },
            generatedAt: currentTime
          }
        );
        break;

      case 'mix':
        insights.push(
          {
            id: 'insight_mix_1',
            type: 'optimization',
            category: 'mix',
            title: 'FMCG Category Underperforming',
            description: 'FMCG category sales are 8.2% below target despite increased foot traffic, indicating potential pricing or assortment issues.',
            confidence: 'high',
            impact: 'high',
            actionable: true,
            metadata: {
              dataPoints: ['fmcg_sales', 'category_targets', 'foot_traffic'],
              timeframe: 'last_30_days',
              affectedMetrics: ['category_performance', 'margin_contribution']
            },
            recommendation: {
              action: 'Review FMCG pricing strategy and product assortment',
              expectedImpact: '5-8% improvement in category performance',
              priority: 'urgent',
              effort: 'high'
            },
            generatedAt: currentTime
          }
        );
        break;

      case 'competitive':
        insights.push(
          {
            id: 'insight_competitive_1',
            type: 'recommendation',
            category: 'competitive',
            title: 'Market Share Opportunity in Electronics',
            description: 'Competitor A has reduced their electronics inventory by 15%, creating an opportunity to capture additional market share.',
            confidence: 'medium',
            impact: 'high',
            actionable: true,
            metadata: {
              dataPoints: ['competitor_inventory', 'market_share', 'electronics_demand'],
              timeframe: 'last_14_days',
              affectedMetrics: ['market_share', 'electronics_revenue']
            },
            recommendation: {
              action: 'Increase electronics inventory and promotional activity',
              expectedImpact: '2-3 percentage point market share gain',
              priority: 'high',
              effort: 'medium'
            },
            generatedAt: currentTime
          }
        );
        break;

      case 'geography':
        insights.push(
          {
            id: 'insight_geography_1',
            type: 'prediction',
            category: 'geography',
            title: 'Cebu Region Growth Potential',
            description: 'Based on demographic trends and competitor gaps, Cebu region shows 35% growth potential in the next quarter.',
            confidence: 'high',
            impact: 'high',
            actionable: true,
            metadata: {
              dataPoints: ['demographic_data', 'competitor_presence', 'economic_indicators'],
              timeframe: 'next_90_days',
              affectedMetrics: ['regional_revenue', 'store_expansion']
            },
            recommendation: {
              action: 'Fast-track Cebu expansion plan',
              expectedImpact: '₱12-18M additional quarterly revenue',
              priority: 'high',
              effort: 'high'
            },
            generatedAt: currentTime
          }
        );
        break;

      case 'consumers':
        insights.push(
          {
            id: 'insight_consumers_1',
            type: 'trend_analysis',
            category: 'consumers',
            title: 'Millennial Shopping Pattern Shift',
            description: 'Millennial customers are shifting from weekend to weekday evening shopping, with 28% increase in Monday-Thursday 6-8pm transactions.',
            confidence: 'high',
            impact: 'medium',
            actionable: true,
            metadata: {
              dataPoints: ['demographic_transactions', 'time_patterns', 'generational_behavior'],
              timeframe: 'last_60_days',
              affectedMetrics: ['hourly_traffic', 'demographic_revenue']
            },
            recommendation: {
              action: 'Adjust staffing and promotional timing for weekday evenings',
              expectedImpact: 'Improved conversion rates and customer satisfaction',
              priority: 'medium',
              effort: 'low'
            },
            generatedAt: currentTime
          }
        );
        break;
    }

    return insights;
  }

  // Production MCP service call
  private async callMCPAIService(request: AIAnalysisRequest): Promise<AIAnalysisResponse> {
    // This would be the actual MCP service call in production
    const response = await fetch('/api/mcp/ai-analysis', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(request)
    });

    if (!response.ok) {
      throw new Error(`MCP AI service error: ${response.statusText}`);
    }

    return response.json();
  }

  // Natural language query processing
  public async processNaturalLanguageQuery(query: string, context: any): Promise<any> {
    try {
      if (this.isDevMode) {
        return this.mockNaturalLanguageResponse(query, context);
      }

      // Production implementation
      const response = await fetch('/api/mcp/nl-query', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ query, context })
      });

      return response.json();
    } catch (error) {
      console.error('Natural language query processing failed:', error);
      throw error;
    }
  }

  private mockNaturalLanguageResponse(query: string, context: any): any {
    // Mock responses for common queries
    const lowercaseQuery = query.toLowerCase();
    
    if (lowercaseQuery.includes('revenue') && lowercaseQuery.includes('last month')) {
      return {
        type: 'data_query',
        result: {
          value: '₱45,234,567',
          change: '+12.3%',
          comparison: 'vs last month'
        },
        visualization: 'revenue_trend',
        confidence: 'high'
      };
    }

    if (lowercaseQuery.includes('best performing') && lowercaseQuery.includes('category')) {
      return {
        type: 'ranking_query',
        result: [
          { category: 'Electronics', performance: 95.2 },
          { category: 'Fresh Products', performance: 87.8 },
          { category: 'FMCG', performance: 82.1 }
        ],
        visualization: 'category_performance',
        confidence: 'high'
      };
    }

    return {
      type: 'general_response',
      result: 'I can help you analyze retail performance data. Try asking about revenue trends, category performance, or regional insights.',
      suggestions: [
        'What is our revenue growth this month?',
        'Which category is performing best?',
        'Show me regional sales comparison'
      ],
      confidence: 'medium'
    };
  }

  // Real-time anomaly detection
  public subscribeToAnomalies(callback: (anomalies: AIInsight[]) => void): () => void {
    if (this.isDevMode) {
      // Mock real-time anomaly detection
      const interval = setInterval(() => {
        if (Math.random() > 0.8) { // 20% chance of anomaly
          const anomaly: AIInsight = {
            id: `anomaly_${Date.now()}`,
            type: 'anomaly_detection',
            category: 'overview',
            title: 'Real-time Sales Anomaly',
            description: `Unusual sales pattern detected: ${Math.random() > 0.5 ? 'spike' : 'dip'} of ${(Math.random() * 30 + 10).toFixed(1)}%`,
            confidence: 'high',
            impact: 'medium',
            actionable: true,
            metadata: {
              dataPoints: ['real_time_sales'],
              timeframe: 'last_15_minutes',
              affectedMetrics: ['hourly_revenue']
            },
            generatedAt: new Date().toISOString()
          };
          callback([anomaly]);
        }
      }, 30000); // Check every 30 seconds

      return () => clearInterval(interval);
    }

    // Production websocket connection
    return () => {};
  }
}

// React hooks for AI integration
export const useAIInsights = (tabId: string) => {
  const filters = useFiltersStore(state => ({
    dateRange: state.dateRange,
    region: state.region,
    storeFormat: state.storeFormat,
    category: state.category,
    contextualFilters: state.contextualFilters[tabId as keyof typeof state.contextualFilters]
  }));

  const [insights, setInsights] = React.useState<AIInsight[]>([]);
  const [loading, setLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  const generateInsights = React.useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const aiService = MCPAIService.getInstance();
      const request: AIAnalysisRequest = {
        tabId,
        filters,
        metrics: ['revenue', 'transactions', 'market_share'],
        analysisType: 'realtime',
        context: {
          persona: 'regional_manager',
          timeframe: filters.dateRange.preset || 'custom',
          businessGoals: ['growth', 'market_share', 'efficiency']
        }
      };

      const response = await aiService.generateInsights(request);
      setInsights(response.insights);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to generate insights');
    } finally {
      setLoading(false);
    }
  }, [tabId, filters]);

  React.useEffect(() => {
    generateInsights();
  }, [generateInsights]);

  return { insights, loading, error, refreshInsights: generateInsights };
};

// Natural language query hook
export const useNaturalLanguageQuery = () => {
  const [isProcessing, setIsProcessing] = React.useState(false);

  const processQuery = React.useCallback(async (query: string, context?: any) => {
    setIsProcessing(true);
    try {
      const aiService = MCPAIService.getInstance();
      return await aiService.processNaturalLanguageQuery(query, context);
    } catch (error) {
      console.error('Query processing failed:', error);
      throw error;
    } finally {
      setIsProcessing(false);
    }
  }, []);

  return { processQuery, isProcessing };
};

// Real-time anomaly detection hook
export const useAnomalyDetection = () => {
  const [anomalies, setAnomalies] = React.useState<AIInsight[]>([]);

  React.useEffect(() => {
    const aiService = MCPAIService.getInstance();
    const unsubscribe = aiService.subscribeToAnomalies((newAnomalies) => {
      setAnomalies(prev => [...newAnomalies, ...prev].slice(0, 10)); // Keep last 10 anomalies
    });

    return unsubscribe;
  }, []);

  return { anomalies, clearAnomalies: () => setAnomalies([]) };
};

export default MCPAIService;