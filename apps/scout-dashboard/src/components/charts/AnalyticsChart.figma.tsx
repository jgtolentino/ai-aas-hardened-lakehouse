import figma from '@figma/code-connect';
import { AnalyticsChart } from './AnalyticsChart';

/**
 * Analytics Chart component for financial/retail metrics visualization
 * Maps to Figma Finebank chart components with financial styling
 */
figma.connect(AnalyticsChart, 'https://www.figma.com/design/Rjh4xxbrZr8otmfpPqiVPC/Finebank---Financial-Management-Dashboard-UI-Kits--Community-?node-id=66-1754', {
  example: ({ chartType, data, theme }) => (
    <AnalyticsChart 
      type={figma.enum('Chart Type', {
        'Line': 'line',
        'Bar': 'bar',
        'Area': 'area',
        'Composed': 'composed'
      })}
      data={figma.instance('Chart Data')}
      title={figma.string('Chart Title')}
      color={figma.enum('Chart Color', {
        'Primary': '#0ea5e9',
        'Success': '#10b981', 
        'Warning': '#f59e0b',
        'Danger': '#ef4444'
      })}
      showGrid={figma.boolean('Show Grid')}
      showLegend={figma.boolean('Show Legend')}
      responsive={figma.boolean('Responsive')}
    />
  ),
  props: {
    type: figma.enum('Chart Type', {
      'Line': 'line',
      'Bar': 'bar', 
      'Area': 'area',
      'Composed': 'composed'
    }),
    title: figma.string('Chart Title'),
    theme: figma.enum('Theme', {
      'Light': 'light',
      'Dark': 'dark'
    })
  }
});