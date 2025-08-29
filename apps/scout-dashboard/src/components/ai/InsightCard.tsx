import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { 
  Lightbulb, 
  Brain, 
  TrendingUp, 
  AlertTriangle, 
  RefreshCw,
  ExternalLink,
  ChevronDown,
  ChevronUp
} from 'lucide-react';
import { cn } from '@/lib/utils';

export interface Insight {
  id: string;
  title: string;
  summary: string;
  fullExplanation?: string;
  confidence: number; // 0-100
  priority: 'low' | 'medium' | 'high' | 'critical';
  category: string;
  actionItems?: string[];
  sources?: Array<{
    title: string;
    url?: string;
    relevance: number;
  }>;
  metadata?: {
    generated_at: string;
    model_version: string;
    context_tokens: number;
  };
}

interface InsightCardProps {
  title: string;
  context: Record<string, any>; // KPI data, filters, etc.
  contextQuery?: string; // Custom query for RAG system
  className?: string;
  showSources?: boolean;
  autoRefresh?: boolean;
  refreshInterval?: number; // milliseconds
  onInsightClick?: (insight: Insight) => void;
}

const InsightSkeleton: React.FC = () => (
  <div className="space-y-3">
    <div className="flex items-center space-x-2">
      <Skeleton className="h-4 w-4" />
      <Skeleton className="h-4 w-24" />
    </div>
    <Skeleton className="h-4 w-full" />
    <Skeleton className="h-4 w-3/4" />
  </div>
);

const getInsightIcon = (insight: Insight) => {
  switch (insight.category.toLowerCase()) {
    case 'trend':
      return <TrendingUp className="h-4 w-4" />;
    case 'alert':
    case 'warning':
      return <AlertTriangle className="h-4 w-4" />;
    case 'opportunity':
    case 'recommendation':
      return <Lightbulb className="h-4 w-4" />;
    default:
      return <Brain className="h-4 w-4" />;
  }
};

const getPriorityColor = (priority: Insight['priority']) => {
  switch (priority) {
    case 'critical':
      return 'bg-red-100 text-red-800 border-red-200';
    case 'high':
      return 'bg-orange-100 text-orange-800 border-orange-200';
    case 'medium':
      return 'bg-blue-100 text-blue-800 border-blue-200';
    case 'low':
      return 'bg-gray-100 text-gray-800 border-gray-200';
  }
};

const getConfidenceColor = (confidence: number) => {
  if (confidence >= 90) return 'bg-green-100 text-green-800 border-green-200';
  if (confidence >= 70) return 'bg-blue-100 text-blue-800 border-blue-200';
  if (confidence >= 50) return 'bg-yellow-100 text-yellow-800 border-yellow-200';
  return 'bg-red-100 text-red-800 border-red-200';
};

export const InsightCard: React.FC<InsightCardProps> = ({
  title,
  context,
  contextQuery,
  className,
  showSources = true,
  autoRefresh = false,
  refreshInterval = 300000, // 5 minutes
  onInsightClick
}) => {
  const [insight, setInsight] = useState<Insight | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isExpanded, setIsExpanded] = useState(false);
  const [lastRefresh, setLastRefresh] = useState<Date>(new Date());

  // Generate insight from RAG system
  const generateInsight = async () => {
    try {
      setIsLoading(true);
      setError(null);

      // Build query from context and custom query
      const query = contextQuery || generateContextQuery(context);
      
      // Call RAG-powered insight generation endpoint
      const response = await fetch('/api/ai/generate-insight', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('supabase.auth.token')}`,
        },
        body: JSON.stringify({
          query,
          context,
          options: {
            maxSources: showSources ? 3 : 0,
            includeActionItems: true,
            confidenceThreshold: 0.3
          }
        }),
      });

      if (!response.ok) {
        throw new Error(`Failed to generate insight: ${response.statusText}`);
      }

      const data = await response.json();
      setInsight(data.insight);
      setLastRefresh(new Date());
      
    } catch (err) {
      console.error('Insight generation error:', err);
      setError(err instanceof Error ? err.message : 'Failed to generate insight');
    } finally {
      setIsLoading(false);
    }
  };

  // Generate context-aware query for RAG system
  const generateContextQuery = (context: Record<string, any>): string => {
    const contextParts: string[] = [];
    
    // Extract key metrics and build query
    if (context.metric) {
      contextParts.push(`${context.metric} performance`);
    }
    
    if (context.timeRange) {
      contextParts.push(`in ${context.timeRange}`);
    }
    
    if (context.region || context.location) {
      contextParts.push(`for ${context.region || context.location}`);
    }
    
    if (context.category || context.segment) {
      contextParts.push(`${context.category || context.segment} segment`);
    }
    
    // Add value context for better insights
    if (context.value || context.change) {
      if (context.change && context.change < 0) {
        contextParts.push('showing decline');
      } else if (context.change && context.change > 0) {
        contextParts.push('showing growth');
      }
    }

    return contextParts.length > 0 
      ? `Why ${contextParts.join(' ')}? What actions should be taken?`
      : 'Provide business insights and recommendations';
  };

  // Initial load and auto-refresh setup
  useEffect(() => {
    generateInsight();
    
    if (autoRefresh) {
      const interval = setInterval(generateInsight, refreshInterval);
      return () => clearInterval(interval);
    }
  }, [context, contextQuery, autoRefresh, refreshInterval]);

  const handleRefresh = () => {
    generateInsight();
  };

  const handleInsightClick = () => {
    if (insight && onInsightClick) {
      onInsightClick(insight);
    }
  };

  if (isLoading && !insight) {
    return (
      <Card className={cn('w-full', className)}>
        <CardHeader className="pb-2">
          <CardTitle className="flex items-center space-x-2 text-sm font-medium">
            <Brain className="h-4 w-4 text-blue-600" />
            <span>{title}</span>
          </CardTitle>
        </CardHeader>
        <CardContent>
          <InsightSkeleton />
        </CardContent>
      </Card>
    );
  }

  if (error) {
    return (
      <Card className={cn('w-full border-red-200', className)}>
        <CardHeader className="pb-2">
          <CardTitle className="flex items-center justify-between text-sm font-medium">
            <div className="flex items-center space-x-2">
              <AlertTriangle className="h-4 w-4 text-red-600" />
              <span>{title}</span>
            </div>
            <Button
              variant="ghost"
              size="sm"
              onClick={handleRefresh}
              disabled={isLoading}
              className="h-6 w-6 p-0"
            >
              <RefreshCw className={cn('h-3 w-3', isLoading && 'animate-spin')} />
            </Button>
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-red-600">{error}</p>
          <Button 
            variant="outline" 
            size="sm" 
            onClick={handleRefresh}
            disabled={isLoading}
            className="mt-2"
          >
            Try Again
          </Button>
        </CardContent>
      </Card>
    );
  }

  if (!insight) {
    return (
      <Card className={cn('w-full', className)}>
        <CardHeader className="pb-2">
          <CardTitle className="flex items-center space-x-2 text-sm font-medium">
            <Brain className="h-4 w-4 text-gray-400" />
            <span>{title}</span>
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-gray-500">No insights available</p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className={cn('w-full cursor-pointer hover:shadow-sm transition-shadow', className)}>
      <CardHeader className="pb-2">
        <CardTitle className="flex items-center justify-between text-sm font-medium">
          <div className="flex items-center space-x-2">
            {getInsightIcon(insight)}
            <span>{title}</span>
            <Badge 
              variant="outline" 
              className={cn('text-xs', getPriorityColor(insight.priority))}
            >
              {insight.priority}
            </Badge>
          </div>
          <div className="flex items-center space-x-2">
            <Badge 
              variant="outline" 
              className={cn('text-xs', getConfidenceColor(insight.confidence))}
              title={`${insight.confidence}% confidence`}
            >
              {insight.confidence}%
            </Badge>
            <Button
              variant="ghost"
              size="sm"
              onClick={handleRefresh}
              disabled={isLoading}
              className="h-6 w-6 p-0"
            >
              <RefreshCw className={cn('h-3 w-3', isLoading && 'animate-spin')} />
            </Button>
          </div>
        </CardTitle>
      </CardHeader>
      
      <CardContent onClick={handleInsightClick}>
        <div className="space-y-3">
          <div>
            <h4 className="font-medium text-sm mb-1">{insight.title}</h4>
            <p className="text-sm text-gray-600 leading-relaxed">{insight.summary}</p>
          </div>
          
          {/* Action Items */}
          {insight.actionItems && insight.actionItems.length > 0 && (
            <div className="bg-blue-50 rounded-lg p-3">
              <h5 className="font-medium text-xs text-blue-800 mb-2">Recommended Actions:</h5>
              <ul className="space-y-1">
                {insight.actionItems.slice(0, isExpanded ? undefined : 2).map((action, index) => (
                  <li key={index} className="text-xs text-blue-700 flex items-start">
                    <span className="mr-2">•</span>
                    <span>{action}</span>
                  </li>
                ))}
              </ul>
              {insight.actionItems.length > 2 && (
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={(e) => {
                    e.stopPropagation();
                    setIsExpanded(!isExpanded);
                  }}
                  className="h-auto p-0 mt-2 text-xs text-blue-600 font-medium"
                >
                  {isExpanded ? (
                    <>
                      <ChevronUp className="h-3 w-3 mr-1" />
                      Show Less
                    </>
                  ) : (
                    <>
                      <ChevronDown className="h-3 w-3 mr-1" />
                      Show {insight.actionItems.length - 2} More
                    </>
                  )}
                </Button>
              )}
            </div>
          )}

          {/* Sources */}
          {showSources && insight.sources && insight.sources.length > 0 && (
            <div className="border-t pt-3">
              <h5 className="font-medium text-xs text-gray-500 mb-2">Sources:</h5>
              <div className="space-y-1">
                {insight.sources.map((source, index) => (
                  <div key={index} className="flex items-center justify-between text-xs">
                    <div className="flex items-center space-x-1 flex-1 min-w-0">
                      <span className="text-gray-600 truncate">{source.title}</span>
                      {source.url && (
                        <ExternalLink 
                          className="h-3 w-3 text-gray-400 flex-shrink-0 cursor-pointer"
                          onClick={(e) => {
                            e.stopPropagation();
                            window.open(source.url, '_blank');
                          }}
                        />
                      )}
                    </div>
                    <span className="text-gray-400 ml-2 flex-shrink-0">
                      {Math.round(source.relevance * 100)}%
                    </span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Last updated */}
          <div className="flex items-center justify-between text-xs text-gray-400 border-t pt-2">
            <span>Updated {lastRefresh.toLocaleTimeString()}</span>
            {insight.metadata && (
              <span>{insight.metadata.model_version}</span>
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  );
};

export default InsightCard;