import type { Meta, StoryObj } from '@storybook/react';
import { KpiCard } from './index';

const meta: Meta<typeof KpiCard> = {
  title: 'Scout/KpiCard',
  component: KpiCard,
  parameters: {
    layout: 'centered',
    docs: {
      description: {
        component: 'KPI Card component for displaying key performance indicators with trend visualization.',
      },
    },
  },
  tags: ['autodocs'],
  argTypes: {
    title: { control: 'text' },
    value: { control: 'text' },
    change: { control: 'number' },
    changeType: {
      control: 'radio',
      options: ['increase', 'decrease'],
    },
    prefix: { control: 'text' },
    suffix: { control: 'text' },
    icon: {
      control: 'select',
      options: ['gmv', 'transactions', 'basket', 'items', undefined],
    },
    state: {
      control: 'radio',
      options: ['loading', 'empty', 'error', 'ready'],
    },
    errorMessage: { control: 'text' },
  },
};

export default meta;
type Story = StoryObj<typeof meta>;

// GMV Card
export const GMV: Story = {
  args: {
    title: 'GMV',
    value: '₱0',
    change: 12.5,
    changeType: 'increase',
    icon: 'gmv',
    state: 'ready',
  },
};

// Transactions Card
export const Transactions: Story = {
  args: {
    title: 'Transactions',
    value: '0',
    change: 6.3,
    changeType: 'increase',
    icon: 'transactions',
    state: 'ready',
  },
};

// Average Basket Card
export const AverageBasket: Story = {
  args: {
    title: 'Avg Basket',
    value: '₱0',
    change: 2.1,
    changeType: 'decrease',
    icon: 'basket',
    state: 'ready',
  },
};

// Items per Transaction Card
export const ItemsPerTransaction: Story = {
  args: {
    title: 'Items/Tx',
    value: '0',
    change: 5.7,
    changeType: 'increase',
    icon: 'items',
    state: 'ready',
  },
};

// Loading State
export const Loading: Story = {
  args: {
    title: 'GMV',
    state: 'loading',
  },
};

// Empty State
export const Empty: Story = {
  args: {
    title: 'GMV',
    state: 'empty',
    icon: 'gmv',
  },
};

// Error State
export const Error: Story = {
  args: {
    title: 'GMV',
    state: 'error',
    errorMessage: 'Unable to fetch data. Please try again.',
  },
};

// Ready State with Data
export const ReadyWithData: Story = {
  args: {
    title: 'Revenue',
    value: '125.4K',
    prefix: '$',
    change: 23.5,
    changeType: 'increase',
    icon: 'gmv',
    state: 'ready',
  },
};

// Grid Layout Example
export const GridLayout: Story = {
  render: () => (
    <div className="grid grid-cols-4 gap-4 p-4 bg-gray-50">
      <KpiCard
        title="GMV"
        value="₱0"
        change={12.5}
        changeType="increase"
        icon="gmv"
      />
      <KpiCard
        title="Transactions"
        value="0"
        change={6.3}
        changeType="increase"
        icon="transactions"
      />
      <KpiCard
        title="Avg Basket"
        value="₱0"
        change={2.1}
        changeType="decrease"
        icon="basket"
      />
      <KpiCard
        title="Items/Tx"
        value="0"
        change={5.7}
        changeType="increase"
        icon="items"
      />
    </div>
  ),
};

// All States Showcase
export const AllStates: Story = {
  render: () => (
    <div className="space-y-4">
      <h3 className="text-lg font-semibold">All KPI Card States</h3>
      <div className="grid grid-cols-4 gap-4">
        <KpiCard title="Ready" value="100K" change={15} state="ready" icon="gmv" />
        <KpiCard title="Loading" state="loading" />
        <KpiCard title="Empty" state="empty" icon="transactions" />
        <KpiCard title="Error" state="error" />
      </div>
    </div>
  ),
};
