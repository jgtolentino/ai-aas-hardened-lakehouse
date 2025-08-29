import figma from '@figma/code-connect';
import { KpiCard } from './index';

/**
 * KPI Card component for displaying key performance indicators
 * Maps to Figma KPI Card component with dynamic states and variants
 */
figma.connect(KpiCard, 'https://www.figma.com/design/Rjh4xxbrZr8otmfpPqiVPC/Finebank---Financial-Management-Dashboard-UI-Kits--Community-?node-id=66-1754', {
  example: ({ title, value, changeType, icon, state }) => (
    <KpiCard 
      title={title}
      value={value}
      change={figma.enum('Change Direction', {
        'Positive': 12.5,
        'Negative': -8.2,
        'None': undefined
      })}
      changeType={figma.enum('Change Direction', {
        'Positive': 'increase',
        'Negative': 'decrease',
        'None': undefined
      })}
      icon={figma.enum('Icon', {
        'Revenue': 'gmv',
        'Transactions': 'transactions', 
        'Basket Size': 'basket',
        'Items': 'items',
        'None': undefined
      })}
      state={figma.enum('State', {
        'Ready': 'ready',
        'Loading': 'loading', 
        'Error': 'error',
        'Empty': 'empty'
      })}
      prefix={figma.boolean('Has Prefix') ? '₱' : ''}
      suffix={figma.boolean('Has Suffix') ? '%' : ''}
    />
  ),
  props: {
    title: figma.string('Title'),
    value: figma.string('Value'),
    state: figma.enum('State', {
      'Ready': 'ready',
      'Loading': 'loading',
      'Error': 'error', 
      'Empty': 'empty'
    }),
    changeType: figma.enum('Change Direction', {
      'Positive': 'increase',
      'Negative': 'decrease'
    }),
    icon: figma.enum('Icon', {
      'Revenue': 'gmv',
      'Transactions': 'transactions',
      'Basket Size': 'basket', 
      'Items': 'items'
    })
  }
});