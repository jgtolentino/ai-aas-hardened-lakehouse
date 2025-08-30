import { ChartCard } from './ChartCard'

export default {
  component: ChartCard,
  props: {
    title: 'Revenue Trend',
    subtitle: 'Weekly performance',
    data: [
      { x: 'W1', y: 100 },
      { x: 'W2', y: 120 },
      { x: 'W3', y: 115 },
      { x: 'W4', y: 135 }
    ]
  }
}