import type { Meta, StoryObj } from '@storybook/react';
import { action } from '@storybook/addon-actions';
import { RecommendationPanel, Recommendation } from './RecommendationPanel';

const meta: Meta<typeof RecommendationPanel> = {
  title: 'AI/RecommendationPanel',
  component: RecommendationPanel,
  parameters: {
    layout: 'padded',
    docs: {
      description: {
        component: 'AI-powered recommendation panel that displays actionable insights, optimizations, alerts, and opportunities for the Scout Dashboard.'
      }
    }
  },
  argTypes: {
    maxRecommendations: {
      control: { type: 'number', min: 1, max: 20 },
      description: 'Maximum number of recommendations to display'
    },
    showConfidenceThreshold: {
      control: { type: 'number', min: 0, max: 100, step: 5 },
      description: 'Minimum confidence threshold to display recommendations'
    },
    enableFeatureFlag: {
      control: 'boolean',
      description: 'Enable/disable the entire recommendation feature'
    },
    onRecommendationClick: { action: 'recommendation-clicked' },
    onActionClick: { action: 'action-clicked' },
    onDismiss: { action: 'dismissed' }
  }
};

export default meta;
type Story = StoryObj<typeof RecommendationPanel>;

// Sample recommendations for stories
const sampleRecommendations: Recommendation[] = [
  {
    id: 'rec-001',
    type: 'optimization',
    title: 'Optimize Manila Branch Performance',
    description: 'Based on recent data analysis, the Manila branch shows significant potential for a 15% revenue increase through targeted campaign adjustments and resource reallocation.',
    confidence: 87,
    priority: 'high',
    category: 'Revenue Optimization',
    impact: {
      type: 'revenue',
      estimated_value: 2500000,
      timeframe: 'Next 3 months'
    },
    actions: [
      { id: 'act-001', label: 'View Details', type: 'primary', action: 'view_details' },
      { id: 'act-002', label: 'Apply Changes', type: 'secondary', action: 'apply_optimization' }
    ],
    metadata: {
      data_sources: ['sales_data', 'customer_analytics'],
      last_updated: new Date().toISOString(),
      expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString()
    }
  },
  {
    id: 'rec-002',
    type: 'alert',
    title: 'Customer Satisfaction Risk Detected',
    description: 'Multiple indicators suggest declining customer satisfaction in the Cebu region. Immediate attention and intervention are recommended to prevent churn.',
    confidence: 92,
    priority: 'critical',
    category: 'Customer Experience',
    impact: {
      type: 'customer_satisfaction',
      timeframe: 'Immediate'
    },
    actions: [
      { id: 'act-003', label: 'Investigate', type: 'primary', action: 'investigate_issue' },
      { id: 'act-004', label: 'Create Action Plan', type: 'secondary', action: 'create_action_plan' }
    ],
    metadata: {
      data_sources: ['feedback_data', 'nps_scores'],
      last_updated: new Date().toISOString()
    }
  },
  {
    id: 'rec-003',
    type: 'opportunity',
    title: 'New Market Expansion Opportunity',
    description: 'Comprehensive market analysis reveals significant untapped potential in Davao City with projected 30% market share opportunity in the digital marketing sector.',
    confidence: 74,
    priority: 'medium',
    category: 'Market Expansion',
    impact: {
      type: 'revenue',
      estimated_value: 5000000,
      timeframe: '6-12 months'
    },
    actions: [
      { id: 'act-005', label: 'Detailed Analysis', type: 'primary', action: 'detailed_analysis' },
      { id: 'act-006', label: 'Feasibility Study', type: 'secondary', action: 'feasibility_study' }
    ],
    metadata: {
      data_sources: ['market_research', 'competitor_analysis'],
      last_updated: new Date().toISOString()
    }
  },
  {
    id: 'rec-004',
    type: 'insight',
    title: 'Seasonal Sales Pattern Identified',
    description: 'Historical data analysis reveals a consistent 25% sales spike during Q4. This pattern provides an opportunity to optimize inventory and marketing strategies.',
    confidence: 95,
    priority: 'medium',
    category: 'Sales Intelligence',
    impact: {
      type: 'efficiency',
      estimated_value: 25,
      timeframe: 'Q4 2024'
    },
    actions: [
      { id: 'act-007', label: 'View Pattern Details', type: 'primary', action: 'view_pattern' },
      { id: 'act-008', label: 'Schedule Planning', type: 'secondary', action: 'schedule_planning' }
    ],
    metadata: {
      data_sources: ['historical_sales', 'seasonal_trends'],
      last_updated: new Date().toISOString()
    }
  },
  {
    id: 'rec-005',
    type: 'optimization',
    title: 'Resource Allocation Improvement',
    description: 'AI analysis suggests reallocating 20% of creative resources from underperforming campaigns to high-ROI initiatives could boost overall efficiency.',
    confidence: 68,
    priority: 'low',
    category: 'Resource Management',
    impact: {
      type: 'efficiency',
      estimated_value: 18,
      timeframe: '1-2 months'
    },
    actions: [
      { id: 'act-009', label: 'Review Allocation', type: 'primary', action: 'review_allocation' }
    ],
    metadata: {
      data_sources: ['project_data', 'resource_utilization'],
      last_updated: new Date().toISOString()
    }
  }
];

export const Default: Story = {
  args: {
    recommendations: sampleRecommendations,
    isLoading: false,
    error: null,
    maxRecommendations: 5,
    showConfidenceThreshold: 50,
    enableFeatureFlag: true,
    onRecommendationClick: action('recommendation-clicked'),
    onActionClick: action('action-clicked'),
    onDismiss: action('dismissed')
  }
};

export const Loading: Story = {
  args: {
    isLoading: true,
    enableFeatureFlag: true
  }
};

export const Error: Story = {
  args: {
    isLoading: false,
    error: 'Failed to connect to AI recommendations service. Please check your network connection and try again.',
    recommendations: [],
    enableFeatureFlag: true
  }
};

export const Empty: Story = {
  args: {
    isLoading: false,
    error: null,
    recommendations: [],
    enableFeatureFlag: true
  }
};

export const HighConfidenceOnly: Story = {
  args: {
    recommendations: sampleRecommendations,
    isLoading: false,
    error: null,
    showConfidenceThreshold: 85,
    maxRecommendations: 10,
    enableFeatureFlag: true,
    onRecommendationClick: action('recommendation-clicked'),
    onActionClick: action('action-clicked'),
    onDismiss: action('dismissed')
  },
  parameters: {
    docs: {
      description: {
        story: 'Shows only recommendations with confidence score >= 85%. Only the Manila optimization and customer satisfaction alert should be visible.'
      }
    }
  }
};

export const LimitedRecommendations: Story = {
  args: {
    recommendations: sampleRecommendations,
    isLoading: false,
    error: null,
    maxRecommendations: 2,
    showConfidenceThreshold: 50,
    enableFeatureFlag: true,
    onRecommendationClick: action('recommendation-clicked'),
    onActionClick: action('action-clicked'),
    onDismiss: action('dismissed')
  },
  parameters: {
    docs: {
      description: {
        story: 'Displays only the top 2 recommendations based on priority and confidence scoring.'
      }
    }
  }
};

export const FeatureDisabled: Story = {
  args: {
    recommendations: sampleRecommendations,
    isLoading: false,
    error: null,
    enableFeatureFlag: false
  },
  parameters: {
    docs: {
      description: {
        story: 'When feature flag is disabled, the component renders nothing. Useful for A/B testing or gradual rollouts.'
      }
    }
  }
};

export const CriticalOnly: Story = {
  args: {
    recommendations: sampleRecommendations.filter(rec => rec.priority === 'critical'),
    isLoading: false,
    error: null,
    maxRecommendations: 10,
    showConfidenceThreshold: 0,
    enableFeatureFlag: true,
    onRecommendationClick: action('recommendation-clicked'),
    onActionClick: action('action-clicked'),
    onDismiss: action('dismissed')
  },
  parameters: {
    docs: {
      description: {
        story: 'Shows only critical priority recommendations, useful for alerting interfaces.'
      }
    }
  }
};

export const SingleRecommendation: Story = {
  args: {
    recommendations: [sampleRecommendations[0]],
    isLoading: false,
    error: null,
    maxRecommendations: 5,
    showConfidenceThreshold: 50,
    enableFeatureFlag: true,
    onRecommendationClick: action('recommendation-clicked'),
    onActionClick: action('action-clicked'),
    onDismiss: action('dismissed')
  },
  parameters: {
    docs: {
      description: {
        story: 'Display when only one recommendation is available or applicable.'
      }
    }
  }
};

export const NoActions: Story = {
  args: {
    recommendations: [
      {
        ...sampleRecommendations[0],
        actions: undefined
      }
    ],
    isLoading: false,
    error: null,
    enableFeatureFlag: true,
    onRecommendationClick: action('recommendation-clicked')
  },
  parameters: {
    docs: {
      description: {
        story: 'Recommendation without any available actions - shows information only.'
      }
    }
  }
};

export const Interactive: Story = {
  args: {
    recommendations: sampleRecommendations,
    isLoading: false,
    error: null,
    maxRecommendations: 5,
    showConfidenceThreshold: 50,
    enableFeatureFlag: true,
    onRecommendationClick: (recommendation) => {
      console.log('Clicked recommendation:', recommendation.title);
      alert(`Viewing details for: ${recommendation.title}`);
    },
    onActionClick: (recommendation, actionId) => {
      const action = recommendation.actions?.find(a => a.id === actionId);
      console.log('Executing action:', action?.label, 'on', recommendation.title);
      alert(`Executing "${action?.label}" for "${recommendation.title}"`);
    },
    onDismiss: (recommendationId) => {
      const rec = sampleRecommendations.find(r => r.id === recommendationId);
      console.log('Dismissed recommendation:', rec?.title);
      alert(`Dismissed: ${rec?.title}`);
    }
  },
  parameters: {
    docs: {
      description: {
        story: 'Interactive version with working click handlers that show alerts. Try clicking recommendations, actions, and dismiss buttons.'
      }
    }
  }
};