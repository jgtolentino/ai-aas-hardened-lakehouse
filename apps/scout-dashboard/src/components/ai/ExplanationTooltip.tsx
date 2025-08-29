import React from 'react';
import { Tooltip } from '@/components/ui/tooltip';
import { Info, Brain, TrendingUp, AlertTriangle, Target } from 'lucide-react';
import { Recommendation } from './RecommendationPanel';

type ExplanationType = 
  | 'confidence' 
  | 'priority' 
  | 'impact' 
  | 'recommendation_type'
  | 'data_freshness'
  | 'action_execution';

interface ExplanationTooltipProps {
  type: ExplanationType;
  value?: string | number;
  recommendation?: Recommendation;
  children: React.ReactNode;
  side?: 'top' | 'bottom' | 'left' | 'right';
}

const getExplanationContent = (
  type: ExplanationType, 
  value?: string | number, 
  recommendation?: Recommendation
): React.ReactNode => {
  switch (type) {
    case 'confidence':
      const confidence = typeof value === 'number' ? value : 0;
      return (
        <div className="space-y-2">
          <div className="flex items-center space-x-2">
            <Brain className="h-4 w-4" />
            <span className="font-medium">Confidence Score</span>
          </div>
          <div className="text-sm space-y-1">
            <p><strong>{confidence}%</strong> confidence level</p>
            <div className="space-y-1 text-xs text-gray-300">
              {confidence >= 90 && (
                <>
                  <p>• High confidence based on strong data patterns</p>
                  <p>• Multiple data sources confirm this insight</p>
                  <p>• Historical accuracy: 92-97%</p>
                </>
              )}
              {confidence >= 70 && confidence < 90 && (
                <>
                  <p>• Good confidence with solid data backing</p>
                  <p>• Some minor uncertainties in projections</p>
                  <p>• Historical accuracy: 78-85%</p>
                </>
              )}
              {confidence >= 50 && confidence < 70 && (
                <>
                  <p>• Moderate confidence, worth considering</p>
                  <p>• Limited data or mixed signals</p>
                  <p>• Historical accuracy: 62-72%</p>
                </>
              )}
              {confidence < 50 && (
                <>
                  <p>• Low confidence, preliminary insight</p>
                  <p>• Insufficient data for strong conclusions</p>
                  <p>• Consider as exploratory hypothesis</p>
                </>
              )}
            </div>
          </div>
        </div>
      );

    case 'priority':
      return (
        <div className="space-y-2">
          <div className="flex items-center space-x-2">
            <AlertTriangle className="h-4 w-4" />
            <span className="font-medium">Priority Level</span>
          </div>
          <div className="text-sm space-y-1">
            <p><strong className="capitalize">{value}</strong> priority recommendation</p>
            <div className="text-xs text-gray-300">
              {value === 'critical' && (
                <>
                  <p>• Immediate attention required</p>
                  <p>• High business impact or risk</p>
                  <p>• Action needed within 24-48 hours</p>
                </>
              )}
              {value === 'high' && (
                <>
                  <p>• Important for business goals</p>
                  <p>• Significant potential impact</p>
                  <p>• Action recommended within 1 week</p>
                </>
              )}
              {value === 'medium' && (
                <>
                  <p>• Valuable optimization opportunity</p>
                  <p>• Moderate business impact</p>
                  <p>• Action recommended within 2-4 weeks</p>
                </>
              )}
              {value === 'low' && (
                <>
                  <p>• Nice-to-have improvement</p>
                  <p>• Minor but positive impact</p>
                  <p>• Action when resources allow</p>
                </>
              )}
            </div>
          </div>
        </div>
      );

    case 'impact':
      if (!recommendation?.impact) return <p>Impact data unavailable</p>;
      
      const { impact } = recommendation;
      return (
        <div className="space-y-2">
          <div className="flex items-center space-x-2">
            <TrendingUp className="h-4 w-4" />
            <span className="font-medium">Impact Analysis</span>
          </div>
          <div className="text-sm space-y-1">
            <p><strong className="capitalize">{impact.type.replace('_', ' ')}</strong> impact</p>
            {impact.estimated_value && (
              <p>
                <strong>
                  {impact.type === 'revenue' ? '₱' : '+'}
                  {impact.estimated_value.toLocaleString()}
                  {impact.type === 'efficiency' ? '%' : ''}
                </strong>
                {impact.timeframe && ` over ${impact.timeframe.toLowerCase()}`}
              </p>
            )}
            <div className="text-xs text-gray-300 space-y-1">
              <p><strong>Calculation method:</strong></p>
              {impact.type === 'revenue' && (
                <>
                  <p>• Based on historical conversion rates</p>
                  <p>• Market size and penetration analysis</p>
                  <p>• Adjusted for seasonality patterns</p>
                </>
              )}
              {impact.type === 'efficiency' && (
                <>
                  <p>• Process optimization analysis</p>
                  <p>• Time and resource savings</p>
                  <p>• Automation potential assessment</p>
                </>
              )}
              {impact.type === 'risk' && (
                <>
                  <p>• Risk probability assessment</p>
                  <p>• Potential downside mitigation</p>
                  <p>• Compliance and security factors</p>
                </>
              )}
              {impact.type === 'customer_satisfaction' && (
                <>
                  <p>• Customer feedback analysis</p>
                  <p>• Net Promoter Score trends</p>
                  <p>• Retention rate improvements</p>
                </>
              )}
            </div>
          </div>
        </div>
      );

    case 'recommendation_type':
      return (
        <div className="space-y-2">
          <div className="flex items-center space-x-2">
            {value === 'insight' && <Brain className="h-4 w-4" />}
            {value === 'optimization' && <TrendingUp className="h-4 w-4" />}
            {value === 'alert' && <AlertTriangle className="h-4 w-4" />}
            {value === 'opportunity' && <Target className="h-4 w-4" />}
            <span className="font-medium capitalize">{value} Recommendation</span>
          </div>
          <div className="text-sm space-y-1">
            <div className="text-xs text-gray-300">
              {value === 'insight' && (
                <>
                  <p>• Data-driven business intelligence</p>
                  <p>• Patterns identified in your data</p>
                  <p>• Actionable information for decisions</p>
                </>
              )}
              {value === 'optimization' && (
                <>
                  <p>• Performance improvement opportunity</p>
                  <p>• Based on efficiency analysis</p>
                  <p>• Specific actions to enhance results</p>
                </>
              )}
              {value === 'alert' && (
                <>
                  <p>• Important issue requiring attention</p>
                  <p>• Risk or problem identification</p>
                  <p>• Proactive monitoring triggered</p>
                </>
              )}
              {value === 'opportunity' && (
                <>
                  <p>• Growth or expansion possibility</p>
                  <p>• Market conditions analysis</p>
                  <p>• Strategic advantage potential</p>
                </>
              )}
            </div>
          </div>
        </div>
      );

    case 'data_freshness':
      return (
        <div className="space-y-2">
          <div className="flex items-center space-x-2">
            <Info className="h-4 w-4" />
            <span className="font-medium">Data Freshness</span>
          </div>
          <div className="text-sm space-y-1">
            {recommendation?.metadata?.last_updated && (
              <p><strong>Last updated:</strong> {new Date(recommendation.metadata.last_updated).toLocaleString()}</p>
            )}
            <div className="text-xs text-gray-300">
              <p>• Data sources: {recommendation?.metadata?.data_sources?.join(', ') || 'Various'}</p>
              <p>• AI model: ScoutAnalytics v2.1</p>
              <p>• Processing: Real-time with 5min refresh</p>
              {recommendation?.metadata?.expires_at && (
                <p>• Expires: {new Date(recommendation.metadata.expires_at).toLocaleString()}</p>
              )}
            </div>
          </div>
        </div>
      );

    case 'action_execution':
      return (
        <div className="space-y-2">
          <div className="flex items-center space-x-2">
            <Target className="h-4 w-4" />
            <span className="font-medium">Action Execution</span>
          </div>
          <div className="text-sm space-y-1">
            <p>Click to execute this recommended action</p>
            <div className="text-xs text-gray-300 space-y-1">
              <p>• Actions are logged and tracked</p>
              <p>• Results will be monitored</p>
              <p>• Can be reversed if needed</p>
              <p>• Impact will be measured automatically</p>
            </div>
          </div>
        </div>
      );

    default:
      return <p>Additional context unavailable</p>;
  }
};

export const ExplanationTooltip: React.FC<ExplanationTooltipProps> = ({
  type,
  value,
  recommendation,
  children,
  side = 'top'
}) => {
  const content = getExplanationContent(type, value, recommendation);

  return (
    <Tooltip content={content} side={side} delay={300}>
      <div className="inline-flex items-center">
        {children}
      </div>
    </Tooltip>
  );
};

export default ExplanationTooltip;