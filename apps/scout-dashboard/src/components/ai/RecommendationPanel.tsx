import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { Alert, AlertCircle, Brain, TrendingUp, Target, AlertTriangle, CheckCircle, Info, HelpCircle } from 'lucide-react';
import { cn } from '@/lib/utils';
import { useRecommendationFeatures } from '@/hooks/useRecommendations';
import { ExplanationTooltip } from './ExplanationTooltip';
import { RecommendationExportButton } from '@/components/ui/export-button';

export interface Recommendation {
  id: string;
  type: 'insight' | 'optimization' | 'alert' | 'opportunity';
  title: string;
  description: string;
  confidence: number; // 0-100
  priority: 'low' | 'medium' | 'high' | 'critical';
  category: string;
  impact: {
    type: 'revenue' | 'efficiency' | 'risk' | 'customer_satisfaction';
    estimated_value?: number;
    timeframe?: string;
  };
  actions?: Array<{
    id: string;
    label: string;
    type: 'primary' | 'secondary';
    action: string;
  }>;
  metadata?: {
    data_sources?: string[];
    last_updated?: string;
    expires_at?: string;
  };
}

interface RecommendationPanelProps {
  className?: string;
  recommendations?: Recommendation[];
  isLoading?: boolean;
  error?: string | null;
  maxRecommendations?: number;
  showConfidenceThreshold?: number;
  enableFeatureFlag?: boolean;
  onRecommendationClick?: (recommendation: Recommendation) => void;
  onActionClick?: (recommendation: Recommendation, actionId: string) => void;
  onDismiss?: (recommendationId: string) => void;
}

const RecommendationSkeleton: React.FC = () => (
  <div className="space-y-4">
    {[1, 2, 3].map((i) => (
      <Card key={i} className="w-full">
        <CardHeader className="pb-2">
          <div className="flex items-center justify-between">
            <Skeleton className="h-4 w-24" />
            <Skeleton className="h-6 w-16" />
          </div>
          <Skeleton className="h-5 w-3/4" />
        </CardHeader>
        <CardContent>
          <Skeleton className="h-4 w-full mb-2" />
          <Skeleton className="h-4 w-2/3" />
          <div className="flex justify-between mt-4">
            <Skeleton className="h-8 w-20" />
            <Skeleton className="h-8 w-16" />
          </div>
        </CardContent>
      </Card>
    ))}
  </div>
);

const EmptyState: React.FC<{ message?: string }> = ({ message = "No recommendations available at this time." }) => (
  <div className="flex flex-col items-center justify-center py-12 text-center">
    <Brain className="h-12 w-12 text-gray-400 mb-4" />
    <h3 className="text-lg font-medium text-gray-900 mb-2">No AI Recommendations</h3>
    <p className="text-gray-500 max-w-sm">{message}</p>
  </div>
);

const ErrorState: React.FC<{ error: string; onRetry?: () => void }> = ({ error, onRetry }) => (
  <Card className="border-red-200 bg-red-50">
    <CardContent className="pt-6">
      <div className="flex items-center">
        <AlertCircle className="h-5 w-5 text-red-600 mr-3" />
        <div className="flex-1">
          <h3 className="text-sm font-medium text-red-800">Failed to load recommendations</h3>
          <p className="text-sm text-red-600 mt-1">{error}</p>
        </div>
        {onRetry && (
          <Button variant="outline" size="sm" onClick={onRetry} className="ml-4">
            Retry
          </Button>
        )}
      </div>
    </CardContent>
  </Card>
);

const getRecommendationIcon = (type: Recommendation['type']) => {
  switch (type) {
    case 'insight':
      return <Brain className="h-4 w-4" />;
    case 'optimization':
      return <TrendingUp className="h-4 w-4" />;
    case 'alert':
      return <AlertTriangle className="h-4 w-4" />;
    case 'opportunity':
      return <Target className="h-4 w-4" />;
    default:
      return <Info className="h-4 w-4" />;
  }
};

const getConfidenceBadgeColor = (confidence: number) => {
  if (confidence >= 90) return 'bg-green-100 text-green-800 border-green-200';
  if (confidence >= 70) return 'bg-blue-100 text-blue-800 border-blue-200';
  if (confidence >= 50) return 'bg-yellow-100 text-yellow-800 border-yellow-200';
  return 'bg-red-100 text-red-800 border-red-200';
};

const getPriorityColor = (priority: Recommendation['priority']) => {
  switch (priority) {
    case 'critical':
      return 'border-red-500 bg-red-50';
    case 'high':
      return 'border-orange-500 bg-orange-50';
    case 'medium':
      return 'border-blue-500 bg-blue-50';
    case 'low':
      return 'border-gray-500 bg-gray-50';
    default:
      return 'border-gray-200';
  }
};

const RecommendationCard: React.FC<{
  recommendation: Recommendation;
  features: any;
  onRecommendationClick?: (recommendation: Recommendation) => void;
  onActionClick?: (recommendation: Recommendation, actionId: string) => void;
  onDismiss?: (recommendationId: string) => void;
}> = ({ recommendation, features, onRecommendationClick, onActionClick, onDismiss }) => {
  const [isDismissed, setIsDismissed] = useState(false);

  const handleDismiss = () => {
    setIsDismissed(true);
    onDismiss?.(recommendation.id);
  };

  if (isDismissed) return null;

  return (
    <Card 
      className={cn(
        'w-full cursor-pointer hover:shadow-md transition-shadow',
        getPriorityColor(recommendation.priority)
      )}
      onClick={() => onRecommendationClick?.(recommendation)}
    >
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <ExplanationTooltip type="recommendation_type" value={recommendation.type} recommendation={recommendation}>
              <div className="flex items-center space-x-1">
                {getRecommendationIcon(recommendation.type)}
                <HelpCircle className="h-3 w-3 text-gray-400" />
              </div>
            </ExplanationTooltip>
            <Badge variant="outline" className="text-xs">
              {recommendation.category}
            </Badge>
          </div>
          <div className="flex items-center space-x-2">
            {features.showConfidence && (
              <ExplanationTooltip type="confidence" value={recommendation.confidence} recommendation={recommendation}>
                <Badge 
                  className={cn(
                    'text-xs border cursor-help',
                    getConfidenceBadgeColor(recommendation.confidence)
                  )}
                >
                  {recommendation.confidence}% confidence
                </Badge>
              </ExplanationTooltip>
            )}
            {features.allowDismiss && (
              <Button
                variant="ghost"
                size="sm"
                onClick={(e) => {
                  e.stopPropagation();
                  handleDismiss();
                }}
                className="h-6 w-6 p-0 hover:bg-gray-100"
              >
                ×
              </Button>
            )}
          </div>
        </div>
        <div className="flex items-center space-x-2">
          <CardTitle className="text-base font-medium">{recommendation.title}</CardTitle>
          <ExplanationTooltip type="priority" value={recommendation.priority} recommendation={recommendation}>
            <Badge 
              variant="outline" 
              className={cn(
                "text-xs cursor-help",
                recommendation.priority === 'critical' && "border-red-500 text-red-700",
                recommendation.priority === 'high' && "border-orange-500 text-orange-700",
                recommendation.priority === 'medium' && "border-blue-500 text-blue-700",
                recommendation.priority === 'low' && "border-gray-500 text-gray-700"
              )}
            >
              {recommendation.priority}
            </Badge>
          </ExplanationTooltip>
        </div>
      </CardHeader>
      
      <CardContent>
        <p className="text-sm text-gray-600 mb-4">{recommendation.description}</p>
        
        {/* Impact Information */}
        <div className="bg-gray-50 rounded-lg p-3 mb-4">
          <div className="flex items-center justify-between text-sm">
            <div className="flex items-center space-x-1">
              <span className="text-gray-500">Estimated Impact:</span>
              <ExplanationTooltip type="impact" recommendation={recommendation} side="top">
                <HelpCircle className="h-3 w-3 text-gray-400 cursor-help" />
              </ExplanationTooltip>
            </div>
            <div className="text-right">
              <span className="font-medium capitalize">
                {recommendation.impact.type.replace('_', ' ')}
              </span>
              {recommendation.impact.estimated_value && (
                <div className="text-green-600 font-semibold">
                  {recommendation.impact.type === 'revenue' ? '₱' : '+'}
                  {recommendation.impact.estimated_value.toLocaleString()}
                  {recommendation.impact.type === 'efficiency' ? '%' : ''}
                </div>
              )}
              {recommendation.impact.timeframe && (
                <div className="text-gray-500 text-xs">
                  {recommendation.impact.timeframe}
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Actions */}
        {features.actionExecution && recommendation.actions && recommendation.actions.length > 0 && (
          <div className="space-y-2 mt-4">
            <div className="flex items-center space-x-1">
              <span className="text-xs text-gray-500 font-medium">Available Actions:</span>
              <ExplanationTooltip type="action_execution" recommendation={recommendation} side="top">
                <HelpCircle className="h-3 w-3 text-gray-400 cursor-help" />
              </ExplanationTooltip>
            </div>
            <div className="flex flex-wrap gap-2">
              {recommendation.actions.map((action) => (
                <Button
                  key={action.id}
                  variant={action.type === 'primary' ? 'default' : 'outline'}
                  size="sm"
                  onClick={(e) => {
                    e.stopPropagation();
                    onActionClick?.(recommendation, action.id);
                  }}
                  className="text-xs"
                >
                  {action.label}
                </Button>
              ))}
            </div>
          </div>
        )}

        {/* Metadata */}
        {recommendation.metadata?.last_updated && (
          <div className="flex items-center space-x-1 text-xs text-gray-400 mt-3 pt-3 border-t">
            <span>Updated {new Date(recommendation.metadata.last_updated).toLocaleDateString()}</span>
            <ExplanationTooltip type="data_freshness" recommendation={recommendation} side="top">
              <Info className="h-3 w-3 cursor-help" />
            </ExplanationTooltip>
          </div>
        )}
      </CardContent>
    </Card>
  );
};

export const RecommendationPanel: React.FC<RecommendationPanelProps> = ({
  className,
  recommendations = [],
  isLoading = false,
  error = null,
  maxRecommendations = 5,
  showConfidenceThreshold = 50,
  enableFeatureFlag = true,
  onRecommendationClick,
  onActionClick,
  onDismiss,
}) => {
  const [filteredRecommendations, setFilteredRecommendations] = useState<Recommendation[]>([]);
  const { features } = useRecommendationFeatures();

  useEffect(() => {
    if (!recommendations) return;

    const filtered = recommendations
      .filter(rec => rec.confidence >= showConfidenceThreshold)
      .sort((a, b) => {
        // Sort by priority, then confidence
        const priorityOrder = { critical: 4, high: 3, medium: 2, low: 1 };
        const priorityDiff = priorityOrder[b.priority] - priorityOrder[a.priority];
        if (priorityDiff !== 0) return priorityDiff;
        return b.confidence - a.confidence;
      })
      .slice(0, maxRecommendations);

    setFilteredRecommendations(filtered);
  }, [recommendations, showConfidenceThreshold, maxRecommendations]);

  // Feature flag check - use both prop and hook
  if (!enableFeatureFlag || !features.enabled) {
    return null;
  }

  return (
    <div className={cn('w-full recommendation-panel', className)} data-export-container="recommendation-panel">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center space-x-2">
          <Brain className="h-5 w-5 text-blue-600" />
          <h2 className="text-lg font-semibold text-gray-900">AI Recommendations</h2>
          {filteredRecommendations.length > 0 && (
            <Badge variant="secondary" className="ml-2">
              {filteredRecommendations.length} active
            </Badge>
          )}
        </div>
        <div className="flex items-center space-x-3">
          {filteredRecommendations.length > 0 && (
            <RecommendationExportButton 
              recommendations={filteredRecommendations}
              className="text-xs"
              enablePNGExport={true}
              enablePDFExport={true}
              pngTargetSelector=".recommendation-panel"
            />
          )}
          {filteredRecommendations.length > 0 && features.autoRefresh && (
            <div className="flex items-center space-x-1 text-xs text-gray-500">
              <CheckCircle className="h-3 w-3" />
              <span>Auto-refreshing</span>
            </div>
          )}
        </div>
      </div>

      {/* Loading State */}
      {isLoading && <RecommendationSkeleton />}

      {/* Error State */}
      {error && !isLoading && <ErrorState error={error} />}

      {/* Empty State */}
      {!isLoading && !error && filteredRecommendations.length === 0 && <EmptyState />}

      {/* Recommendations List */}
      {!isLoading && !error && filteredRecommendations.length > 0 && (
        <div className="space-y-4">
          {filteredRecommendations.map((recommendation) => (
            <RecommendationCard
              key={recommendation.id}
              recommendation={recommendation}
              features={features}
              onRecommendationClick={onRecommendationClick}
              onActionClick={onActionClick}
              onDismiss={onDismiss}
            />
          ))}
          
          {recommendations.length > maxRecommendations && (
            <div className="text-center pt-4">
              <Button variant="outline" size="sm">
                View All Recommendations ({recommendations.length - maxRecommendations} more)
              </Button>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default RecommendationPanel;