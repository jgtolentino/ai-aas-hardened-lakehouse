import React, { useState } from 'react';
import Layout from '@theme/Layout';
import { 
  BarChart, Bar, LineChart, Line, PieChart, Pie, Cell, 
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, 
  Legend, ResponsiveContainer, RadialBarChart, RadialBar
} from 'recharts';
import { 
  TrendingUp, Store, Package, DollarSign, Users, Activity,
  Calendar, MapPin, ShoppingCart, CreditCard, Clock, Filter
} from 'lucide-react';
import styles from './dashboard.module.css';

export default function Dashboard() {
  const [activeTab, setActiveTab] = useState('overview');
  const [dateRange, setDateRange] = useState('7d');
  const [selectedStore, setSelectedStore] = useState('all');

  // Sample Scout data for Philippine retail
  const storePerformance = [
    { store: 'SM Mall of Asia', revenue: 2450000, transactions: 1234, growth: 15.2 },
    { store: 'Robinsons Galleria', revenue: 1890000, transactions: 2456, growth: -5.3 },
    { store: 'Ayala Center Cebu', revenue: 1750000, transactions: 5123, growth: 22.1 },
    { store: 'SM North EDSA', revenue: 1620000, transactions: 987, growth: 8.7 },
    { store: 'Greenbelt Makati', revenue: 1480000, transactions: 1876, growth: 12.4 }
  ];

  const categoryPerformance = [
    { category: 'Electronics', value: 35, revenue: 3200000 },
    { category: 'Fashion', value: 28, revenue: 2560000 },
    { category: 'Groceries', value: 20, revenue: 1830000 },
    { category: 'Home & Living', value: 10, revenue: 915000 },
    { category: 'Beauty', value: 7, revenue: 640000 }
  ];

  const timeSeriesData = [
    { date: 'Mon', sales: 450000, footfall: 8500, conversion: 2.8 },
    { date: 'Tue', sales: 520000, footfall: 9200, conversion: 3.1 },
    { date: 'Wed', sales: 480000, footfall: 8800, conversion: 2.9 },
    { date: 'Thu', sales: 590000, footfall: 10500, conversion: 3.4 },
    { date: 'Fri', sales: 720000, footfall: 12000, conversion: 3.8 },
    { date: 'Sat', sales: 980000, footfall: 15000, conversion: 4.2 },
    { date: 'Sun', sales: 850000, footfall: 13500, conversion: 3.9 }
  ];

  const paymentMethods = [
    { method: 'Cash', count: 4532, percentage: 45 },
    { method: 'Credit Card', count: 2518, percentage: 25 },
    { method: 'GCash', count: 2012, percentage: 20 },
    { method: 'Debit Card', count: 1008, percentage: 10 }
  ];

  const kpiMetrics = [
    { 
      title: 'Total Revenue', 
      value: '₱5.59M', 
      change: '+12.3%', 
      icon: DollarSign,
      color: '#0078d4' 
    },
    { 
      title: 'Transactions', 
      value: '12,676', 
      change: '+8.7%', 
      icon: ShoppingCart,
      color: '#40a9ff' 
    },
    { 
      title: 'Avg Basket Size', 
      value: '₱441', 
      change: '+3.2%', 
      icon: Package,
      color: '#1890ff' 
    },
    { 
      title: 'Store Footfall', 
      value: '78.5K', 
      change: '+15.4%', 
      icon: Users,
      color: '#096dd9' 
    }
  ];

  const renderContent = () => {
    switch(activeTab) {
      case 'overview':
        return (
          <div className={styles.overviewContent}>
            {/* KPI Cards */}
            <div className={styles.kpiGrid}>
              {kpiMetrics.map((metric, index) => (
                <div key={index} className={styles.kpiCard}>
                  <div className={styles.kpiHeader}>
                    <metric.icon size={24} color={metric.color} />
                    <span className={styles.kpiTitle}>{metric.title}</span>
                  </div>
                  <div className={styles.kpiValue}>{metric.value}</div>
                  <div className={`${styles.kpiChange} ${metric.change.startsWith('+') ? styles.positive : styles.negative}`}>
                    {metric.change} vs last period
                  </div>
                </div>
              ))}
            </div>

            {/* Charts Grid */}
            <div className={styles.chartsGrid}>
              {/* Sales Trend */}
              <div className={styles.chartCard}>
                <h3><TrendingUp size={18} /> Sales Trend</h3>
                <ResponsiveContainer width="100%" height={300}>
                  <AreaChart data={timeSeriesData}>
                    <defs>
                      <linearGradient id="salesGradient" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="#0078d4" stopOpacity={0.8}/>
                        <stop offset="95%" stopColor="#0078d4" stopOpacity={0.1}/>
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" stroke="#e0e0e0" />
                    <XAxis dataKey="date" />
                    <YAxis />
                    <Tooltip formatter={(value) => `₱${value.toLocaleString()}`} />
                    <Area type="monotone" dataKey="sales" stroke="#0078d4" fillOpacity={1} fill="url(#salesGradient)" />
                  </AreaChart>
                </ResponsiveContainer>
              </div>

              {/* Store Performance */}
              <div className={styles.chartCard}>
                <h3><Store size={18} /> Store Performance</h3>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={storePerformance}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#e0e0e0" />
                    <XAxis dataKey="store" angle={-45} textAnchor="end" height={80} />
                    <YAxis />
                    <Tooltip formatter={(value) => `₱${value.toLocaleString()}`} />
                    <Bar dataKey="revenue" fill="#0078d4" radius={[8, 8, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>

              {/* Category Distribution */}
              <div className={styles.chartCard}>
                <h3><Package size={18} /> Category Distribution</h3>
                <ResponsiveContainer width="100%" height={300}>
                  <PieChart>
                    <Pie
                      data={categoryPerformance}
                      dataKey="value"
                      nameKey="category"
                      cx="50%"
                      cy="50%"
                      outerRadius={100}
                      label={({category, value}) => `${category} ${value}%`}
                    >
                      {categoryPerformance.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={['#0078d4', '#40a9ff', '#69c0ff', '#91d5ff', '#bae7ff'][index % 5]} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              </div>

              {/* Payment Methods */}
              <div className={styles.chartCard}>
                <h3><CreditCard size={18} /> Payment Methods</h3>
                <ResponsiveContainer width="100%" height={300}>
                  <RadialBarChart cx="50%" cy="50%" innerRadius="10%" outerRadius="90%" data={paymentMethods}>
                    <RadialBar dataKey="percentage" cornerRadius={10} fill="#0078d4" />
                    <Legend />
                    <Tooltip />
                  </RadialBarChart>
                </ResponsiveContainer>
              </div>
            </div>
          </div>
        );

      case 'stores':
        return (
          <div className={styles.storesContent}>
            <div className={styles.storeTable}>
              <table>
                <thead>
                  <tr>
                    <th>Store Name</th>
                    <th>Region</th>
                    <th>Revenue</th>
                    <th>Transactions</th>
                    <th>Avg Basket</th>
                    <th>Growth</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {storePerformance.map((store, idx) => (
                    <tr key={idx}>
                      <td>{store.store}</td>
                      <td>Metro Manila</td>
                      <td>₱{store.revenue.toLocaleString()}</td>
                      <td>{store.transactions.toLocaleString()}</td>
                      <td>₱{Math.round(store.revenue / store.transactions)}</td>
                      <td className={store.growth > 0 ? styles.positive : styles.negative}>
                        {store.growth > 0 ? '+' : ''}{store.growth}%
                      </td>
                      <td><span className={styles.statusActive}>Active</span></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        );

      case 'products':
        return (
          <div className={styles.productsContent}>
            <h3>Top Products by Category</h3>
            <div className={styles.productGrid}>
              {categoryPerformance.map((cat, idx) => (
                <div key={idx} className={styles.productCard}>
                  <h4>{cat.category}</h4>
                  <div className={styles.productMetric}>
                    <span>Revenue</span>
                    <strong>₱{cat.revenue.toLocaleString()}</strong>
                  </div>
                  <div className={styles.productBar}>
                    <div 
                      className={styles.productBarFill} 
                      style={{width: `${cat.value}%`, backgroundColor: '#0078d4'}}
                    />
                  </div>
                </div>
              ))}
            </div>
          </div>
        );

      case 'analytics':
        return (
          <div className={styles.analyticsContent}>
            <h3>Advanced Analytics</h3>
            <div className={styles.analyticsGrid}>
              <div className={styles.metricCard}>
                <h4>Conversion Rate</h4>
                <div className={styles.bigNumber}>3.4%</div>
                <div className={styles.trend}>↑ 0.3% from last week</div>
              </div>
              <div className={styles.metricCard}>
                <h4>Customer Retention</h4>
                <div className={styles.bigNumber}>68%</div>
                <div className={styles.trend}>↑ 5% from last month</div>
              </div>
              <div className={styles.metricCard}>
                <h4>Revenue per Sqm</h4>
                <div className={styles.bigNumber}>₱8,420</div>
                <div className={styles.trend}>↑ 12% YoY</div>
              </div>
            </div>
          </div>
        );

      default:
        return null;
    }
  };

  return (
    <Layout title="Scout Dashboard" description="Philippine Retail Analytics Dashboard">
      <div className={styles.dashboard}>
        {/* Header */}
        <div className={styles.header}>
          <div className={styles.headerLeft}>
            <h1>Scout Analytics Dashboard</h1>
            <p>Philippine Retail Intelligence Platform</p>
          </div>
          <div className={styles.headerRight}>
            <select 
              className={styles.dateSelector}
              value={dateRange}
              onChange={(e) => setDateRange(e.target.value)}
            >
              <option value="24h">Last 24 Hours</option>
              <option value="7d">Last 7 Days</option>
              <option value="30d">Last 30 Days</option>
              <option value="90d">Last Quarter</option>
            </select>
            <button className={styles.filterButton}>
              <Filter size={16} /> Filters
            </button>
          </div>
        </div>

        {/* Main Layout */}
        <div className={styles.mainLayout}>
          {/* Sidebar */}
          <div className={styles.sidebar}>
            <nav className={styles.nav}>
              <button 
                className={`${styles.navItem} ${activeTab === 'overview' ? styles.active : ''}`}
                onClick={() => setActiveTab('overview')}
              >
                <Activity size={18} /> Overview
              </button>
              <button 
                className={`${styles.navItem} ${activeTab === 'stores' ? styles.active : ''}`}
                onClick={() => setActiveTab('stores')}
              >
                <Store size={18} /> Stores
              </button>
              <button 
                className={`${styles.navItem} ${activeTab === 'products' ? styles.active : ''}`}
                onClick={() => setActiveTab('products')}
              >
                <Package size={18} /> Products
              </button>
              <button 
                className={`${styles.navItem} ${activeTab === 'analytics' ? styles.active : ''}`}
                onClick={() => setActiveTab('analytics')}
              >
                <TrendingUp size={18} /> Analytics
              </button>
            </nav>
          </div>

          {/* Content Area */}
          <div className={styles.content}>
            {renderContent()}
          </div>
        </div>
      </div>
    </Layout>
  );
}