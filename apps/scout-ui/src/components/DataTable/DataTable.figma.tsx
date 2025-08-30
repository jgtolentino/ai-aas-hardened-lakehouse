import { DataTable } from './DataTable'

export default {
  component: DataTable,
  props: {
    data: [
      { id: 1, name: 'Item 1', value: 100 },
      { id: 2, name: 'Item 2', value: 200 }
    ],
    columns: [
      { key: 'id', label: 'ID' },
      { key: 'name', label: 'Name' },
      { key: 'value', label: 'Value' }
    ]
  }
}