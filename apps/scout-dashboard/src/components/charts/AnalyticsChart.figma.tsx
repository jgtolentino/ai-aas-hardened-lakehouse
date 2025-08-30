import figma from '@figma/code-connect';
import { AnalyticsChart } from './AnalyticsChart';

/**
 * Analytics Chart Component
 * Flexible charting component that supports multiple chart types
 */
figma.connect(AnalyticsChart, 'https://www.figma.com/design/Rjh4xxbrZr8otmfpPqiVPC/Scout-Analytics-Chart', {
  example: ({ chartType, title, showLegend, showGrid, theme }) => (
    <AnalyticsChart
      type={figma.enum('Chart Type', {
        'Line': 'line',
        'Bar': 'bar',
        'Area': 'area',
        'Scatter': 'scatter',
        'Pie': 'pie',
        'Donut': 'donut',
        'Radar': 'radar',
        'Heatmap': 'heatmap',
        'Funnel': 'funnel',
        'Sankey': 'sankey'
      })}
      title={figma.string('Chart Title')}
      showLegend={figma.boolean('Show Legend', true)}
      showGrid={figma.boolean('Show Grid', true)}
      showTooltip={figma.boolean('Show Tooltip', true)}
      theme={figma.enum('Theme', {
        'Light': 'light',
        'Dark': 'dark',
        'Auto': 'auto'
      })}
      height={figma.number('Height', 400)}
      responsive={figma.boolean('Responsive', true)}
      exportable={figma.boolean('Exportable', true)}
    />
  ),
  props: {
    type: figma.enum('Chart Type', {
      'Line': 'line',
      'Bar': 'bar',
      'Area': 'area',
      'Scatter': 'scatter',
      'Pie': 'pie',
      'Donut': 'donut',
      'Radar': 'radar',
      'Heatmap': 'heatmap',
      'Funnel': 'funnel',
      'Sankey': 'sankey'
    }),
    title: figma.string('Chart Title'),
    showLegend: figma.boolean('Show Legend'),
    showGrid: figma.boolean('Show Grid'),
    showTooltip: figma.boolean('Show Tooltip'),
    theme: figma.enum('Theme', {
      'Light': 'light',
      'Dark': 'dark',
      'Auto': 'auto'
    }),
    height: figma.number('Height'),
    responsive: figma.boolean('Responsive'),
    exportable: figma.boolean('Exportable')
  },
  imports: [
    "import { AnalyticsChart } from '@/components/charts/AnalyticsChart';",
    "import { useTheme } from '@/hooks/useTheme';",
    "import { formatNumber, formatCurrency } from '@/utils/format';"
  ]
});
