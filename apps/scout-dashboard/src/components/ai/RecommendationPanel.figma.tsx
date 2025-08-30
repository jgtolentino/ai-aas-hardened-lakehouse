import figma from '@figma/code-connect';
import { RecommendationPanel } from './RecommendationPanel';

/**
 * AI Recommendation Panel
 * Displays AI-powered insights and recommendations
 */
figma.connect(RecommendationPanel, 'https://www.figma.com/design/Rjh4xxbrZr8otmfpPqiVPC/Scout-AI-Recommendations', {
  example: ({ priority, category, expanded, interactive }) => (
    <RecommendationPanel
      priority={figma.enum('Priority', {
        'Critical': 'critical',
        'High': 'high',
        'Medium': 'medium',
        'Low': 'low'
      })}
      category={figma.enum('Category', {
        'Revenue Opportunity': 'revenue',
        'Cost Optimization': 'cost',
        'Customer Experience': 'cx',
        'Operational Efficiency': 'efficiency',
        'Risk Mitigation': 'risk',
        'Growth Strategy': 'growth'
      })}
      expanded={figma.boolean('Expanded', false)}
      interactive={figma.boolean('Interactive', true)}
      showConfidence={figma.boolean('Show Confidence Score', true)}
      showImpact={figma.boolean('Show Impact Analysis', true)}
      showActions={figma.boolean('Show Action Buttons', true)}
    />
  ),
  props: {
    priority: figma.enum('Priority', {
      'Critical': 'critical',
      'High': 'high',
      'Medium': 'medium',
      'Low': 'low'
    }),
    category: figma.enum('Category', {
      'Revenue Opportunity': 'revenue',
      'Cost Optimization': 'cost',
      'Customer Experience': 'cx',
      'Operational Efficiency': 'efficiency',
      'Risk Mitigation': 'risk',
      'Growth Strategy': 'growth'
    }),
    expanded: figma.boolean('Expanded'),
    interactive: figma.boolean('Interactive'),
    showConfidence: figma.boolean('Show Confidence Score'),
    showImpact: figma.boolean('Show Impact Analysis'),
    showActions: figma.boolean('Show Action Buttons')
  },
  imports: [
    "import { RecommendationPanel } from '@/components/ai/RecommendationPanel';",
    "import { useRecommendations } from '@/hooks/useRecommendations';",
    "import { InsightCard } from '@/components/ai/InsightCard';"
  ]
});
