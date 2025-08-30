import { FilterPanel } from './FilterPanel'

export default {
  component: FilterPanel,
  props: {
    filters: [
      {
        key: 'status',
        label: 'Status',
        type: 'select',
        options: [
          { value: 'active', label: 'Active' },
          { value: 'inactive', label: 'Inactive' }
        ]
      }
    ],
    values: {},
    onFilterChange: () => {},
    onApply: () => {}
  }
}