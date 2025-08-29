// Type definitions for the Financial Dashboard
export interface DashboardProps {
  theme?: 'light' | 'dark';
  period?: 'hourly' | 'daily' | 'weekly' | 'monthly' | 'yearly';
  storeId?: string;
}

export type TimeRange = 'today' | 'yesterday' | 'last7days' | 'last30days' | 'last90days' | 'custom';

export interface Metric {
  value: number;
  change: number;
  trend: 'up' | 'down' | 'stable';
  target?: number;
  sparkline?: number[];
}

export interface DashboardMetrics {
  revenue: Metric;
  transactions: Metric;
  aov: Metric; // Average Order Value
  customers: Metric;
  growth: Metric;
}

export interface ChartData {
  timestamp: string;
  value: number;
  label?: string;
  previous?: number;
}

export interface Transaction {
  id: string;
  timestamp: string;
  storeId: string;
  storeName: string;
  amount: number;
  items: number;
  customerId: string;
  customerName?: string;
  paymentMethod: string;
  status: 'completed' | 'pending' | 'failed' | 'refunded';
}

export interface Store {
  id: string;
  name: string;
  region: string;
  city: string;
  barangay: string;
  latitude: number;
  longitude: number;
  revenue: number;
  transactions: number;
  performance: 'excellent' | 'good' | 'average' | 'poor';
}

export interface Alert {
  id: string;
  type: 'info' | 'warning' | 'error' | 'success';
  title: string;
  message: string;
  timestamp: string;
  read: boolean;
  actionUrl?: string;
}

export interface MetricCardProps {
  id: string;
  title: string;
  value: number;
  change: number;
  trend: 'up' | 'down' | 'stable';
  icon: React.ComponentType<any>;
  format: 'currency' | 'number' | 'percentage';
  color: 'blue' | 'green' | 'purple' | 'orange' | 'red';
  onClick?: () => void;
  isSelected?: boolean;
  sparkline?: number[];
}

export interface ChartProps {
  data: ChartData[];
  period: string;
  height?: number;
  showComparison?: boolean;
  showLegend?: boolean;
}

export interface TableProps {
  data: Transaction[];
  pageSize?: number;
  onRowClick?: (transaction: Transaction) => void;
  sortable?: boolean;
  filterable?: boolean;
}

export interface MapProps {
  stores: Store[];
  metric: string;
  height?: number;
  showClustering?: boolean;
  onStoreClick?: (store: Store) => void;
}
