import figma from '@figma/code-connect';
import { OverviewTab } from './OverviewTab';

/**
 * Overview Tab - Main Dashboard View
 * Maps to Figma's overview dashboard with KPIs, charts, and insights
 */
figma.connect(OverviewTab, 'https://www.figma.com/design/Rjh4xxbrZr8otmfpPqiVPC/Scout-Dashboard-Overview', {
  example: ({ period, viewMode, showInsights }) => (
    <OverviewTab
      period={figma.enum('Time Period', {
        'Today': 'today',
        'Yesterday': 'yesterday',
        'Last 7 Days': '7d',
        'Last 30 Days': '30d',
        'Last Quarter': 'quarter',
        'Year to Date': 'ytd',
        'Custom': 'custom'
      })}
      viewMode={figma.enum('View Mode', {
        'Executive Summary': 'executive',
        'Detailed Analytics': 'detailed',
        'Comparison': 'comparison'
      })}
      showInsights={figma.boolean('Show AI Insights', true)}
      layout={figma.enum('Layout', {
        'Grid': 'grid',
        'List': 'list',
        'Dashboard': 'dashboard'
      })}
    />
  ),
  props: {
    period: figma.string('Time Period'),
    viewMode: figma.enum('View Mode', {
      'Executive Summary': 'executive',
      'Detailed Analytics': 'detailed',
      'Comparison': 'comparison'
    }),
    showInsights: figma.boolean('Show AI Insights'),
    layout: figma.enum('Layout', {
      'Grid': 'grid',
      'List': 'list',
      'Dashboard': 'dashboard'
    })
  },
  imports: [
    "import { OverviewTab } from '@/components/tabs/OverviewTab';",
    "import { KpiCard } from '@/components/scout/KpiCard';",
    "import { AnalyticsChart } from '@/components/charts/AnalyticsChart';",
    "import { RecommendationPanel } from '@/components/ai/RecommendationPanel';"
  ]
});
