import figma from '@figma/code-connect';
import { RecommendationPanel } from './RecommendationPanel';

/**
 * AI Recommendation Panel - Financial insights and recommendations
 * Maps to Figma Finebank AI/insights component with financial context
 */
figma.connect(RecommendationPanel, 'https://www.figma.com/design/Rjh4xxbrZr8otmfpPqiVPC/Finebank---Financial-Management-Dashboard-UI-Kits--Community-?node-id=66-1754', {
  example: ({ recommendations, isLoading }) => (
    <RecommendationPanel 
      recommendations={figma.instance('Recommendations List')}
      isLoading={figma.boolean('Loading State')}
      maxRecommendations={figma.enum('Max Items', {
        '3': 3,
        '5': 5,
        '10': 10
      })}
      showConfidenceThreshold={figma.enum('Confidence Filter', {
        'All': 0,
        'Medium': 60,
        'High': 80
      })}
      enableFeatureFlag={figma.boolean('Feature Enabled')}
    />
  ),
  props: {
    isLoading: figma.boolean('Loading State'),
    maxRecommendations: figma.enum('Max Items', {
      '3': 3,
      '5': 5, 
      '10': 10
    }),
    enableFeatureFlag: figma.boolean('Feature Enabled')
  }
});

/**
 * Individual Recommendation Card mapping
 */
figma.connect(RecommendationPanel, 'https://www.figma.com/design/Rjh4xxbrZr8otmfpPqiVPC/Finebank---Financial-Management-Dashboard-UI-Kits--Community-?node-id=66-1754', {
  variant: { 'Component': 'Recommendation Card' },
  example: () => (
    <RecommendationPanel 
      recommendations={[{
        id: '1',
        type: figma.enum('Recommendation Type', {
          'Insight': 'insight',
          'Optimization': 'optimization',
          'Alert': 'alert',
          'Opportunity': 'opportunity'
        }),
        title: figma.string('Title'),
        description: figma.string('Description'),
        confidence: figma.enum('Confidence', {
          'Low': 45,
          'Medium': 75,
          'High': 90
        }),
        priority: figma.enum('Priority', {
          'Low': 'low',
          'Medium': 'medium', 
          'High': 'high',
          'Critical': 'critical'
        }),
        category: figma.string('Category'),
        impact: {
          type: figma.enum('Impact Type', {
            'Revenue': 'revenue',
            'Efficiency': 'efficiency',
            'Risk': 'risk',
            'Customer Satisfaction': 'customer_satisfaction'
          }),
          estimated_value: figma.number('Impact Value'),
          timeframe: figma.string('Timeframe')
        }
      }]}
    />
  )
});