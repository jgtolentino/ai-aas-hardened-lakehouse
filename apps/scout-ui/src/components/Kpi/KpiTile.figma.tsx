import { KpiTile, type KpiTileProps } from './KpiTile'
export default {
  component: KpiTile,
  props: {
    label: 'Revenue',
    value: '₱ 12.4M',
    hint: 'Last 28 days',
  } satisfies KpiTileProps,
}