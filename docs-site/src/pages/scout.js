import React, { useState } from 'react';
import Layout from '@theme/Layout';
import { 
  BarChart, Bar, LineChart, Line, PieChart, Pie, Cell, 
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, 
  Legend, ResponsiveContainer, ComposedChart
} from 'recharts';
import { 
  TrendingUp, Store, Package, DollarSign, Users, Activity,
  Home, BarChart3, Database, Brain, Settings, HelpCircle,
  ChevronDown, Filter, Calendar, Download, RefreshCw, 
  Search, Bell, Menu, X, FileText, Map, ShoppingBag,
  Target, Zap, Award, Globe, Clock, AlertCircle
} from 'lucide-react';
import styles from './scout.module.css';

export default function ScoutDashboard() {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [dateRange, setDateRange] = useState('7d');
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [selectedStore, setSelectedStore] = useState('all');
  const [refreshing, setRefreshing] = useState(false);

  // Philippine retail data with enhanced metrics
  const kpiData = {
    sales: {
      newCustomers: 25420,
      newCustomersChange: 36.6,
      newRevenue: 3510000,
      newRevenueChange: 18.7,
      mrr: 46820000,
      mrrChange: 36.6,
      cancellation: 14.93,
      cancellationChange: -0.74
    },
    marketing: {
      mqls: { conversion: 68, target: 100 },
      newCustomers: { current: 450, previous: 320 }
    },
    finance: {
      cashFlow: [
        { month: 'Jan', actual: 310000, forecast: 290000 },
        { month: 'Feb', actual: 340000, forecast: 320000 },
        { month: 'Mar', actual: 380000, forecast: 360000 },
        { month: 'Apr', actual: 420000, forecast: 400000 }
      ]
    },
    hr: {
      hiringRate: { current: 82, previous: 75 },
      attritionRate: { current: 8, previous: 12 }
    }
  };

  // Store performance data
  const storeData = [
    { name: 'SM Mall of Asia', revenue: 2450000, transactions: 12340, growth: 15.2, region: 'NCR' },
    { name: 'Robinsons Galleria', revenue: 1890000, transactions: 10456, growth: -5.3, region: 'NCR' },
    { name: 'Ayala Center Cebu', revenue: 1750000, transactions: 9123, growth: 22.1, region: 'Visayas' },
    { name: 'SM North EDSA', revenue: 1620000, transactions: 8987, growth: 8.7, region: 'NCR' },
    { name: 'Greenbelt Makati', revenue: 1480000, transactions: 7876, growth: 12.4, region: 'NCR' }
  ];

  // Category performance
  const categoryData = [
    { name: 'Electronics', value: 35, color: '#0078d4' },
    { name: 'Fashion', value: 28, color: '#40a9ff' },
    { name: 'Groceries', value: 20, color: '#1890ff' },
    { name: 'Home', value: 10, color: '#69c0ff' },
    { name: 'Beauty', value: 7, color: '#91d5ff' }
  ];

  // Time series data
  const timeSeriesData = [
    { date: 'Mon', sales: 450000, footfall: 8500, conversion: 2.8 },
    { date: 'Tue', sales: 520000, footfall: 9200, conversion: 3.1 },
    { date: 'Wed', sales: 480000, footfall: 8800, conversion: 2.9 },
    { date: 'Thu', sales: 590000, footfall: 10500, conversion: 3.4 },
    { date: 'Fri', sales: 720000, footfall: 12000, conversion: 3.8 },
    { date: 'Sat', sales: 980000, footfall: 15000, conversion: 4.2 },
    { date: 'Sun', sales: 850000, footfall: 13500, conversion: 3.9 }
  ];

  const handleRefresh = () => {
    setRefreshing(true);
    setTimeout(() => setRefreshing(false), 1000);
  };

  const renderTabContent = () => {
    switch(activeTab) {
      case 'dashboard':
        return (
          <div className={styles.dashboardContent}>
            {/* Department Sections */}
            <div className={styles.departmentGrid}>
              {/* Sales Section */}
              <div className={styles.departmentCard}>
                <div className={styles.departmentHeader}>
                  <h3>Sales</h3>
                  <button className={styles.viewDetailsBtn}>View Details →</button>
                </div>
                
                <div className={styles.metricsGrid}>
                  <div className={styles.metricBox}>
                    <div className={styles.metricLabel}>New Customers</div>
                    <div className={styles.metricValue}>
                      {kpiData.sales.newCustomers.toLocaleString()}
                      <span className={styles.metricChange}>↑ {kpiData.sales.newCustomersChange}%</span>
                    </div>
                  </div>
                  
                  <div className={styles.metricBox}>
                    <div className={styles.metricLabel}>New Revenue</div>
                    <div className={styles.metricValue}>
                      ₱{(kpiData.sales.newRevenue / 1000000).toFixed(2)}M
                      <span className={styles.metricChange}>↑ {kpiData.sales.newRevenueChange}%</span>
                    </div>
                  </div>
                  
                  <div className={styles.metricBox}>
                    <div className={styles.metricLabel}>Net MRR</div>
                    <div className={styles.metricValue}>
                      ₱{(kpiData.sales.mrr / 1000000).toFixed(2)}M
                      <span className={styles.metricChange}>↑ {kpiData.sales.mrrChange}%</span>
                    </div>
                  </div>
                  
                  <div className={styles.metricBox}>
                    <div className={styles.metricLabel}>Net Cancellation</div>
                    <div className={styles.metricValue}>
                      {kpiData.sales.cancellation}%
                      <span className={styles.metricChangeNegative}>↓ {Math.abs(kpiData.sales.cancellationChange)}%</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Marketing Section */}
              <div className={styles.departmentCard}>
                <div className={styles.departmentHeader}>
                  <h3>Marketing</h3>
                  <button className={styles.viewDetailsBtn}>View Details →</button>
                </div>
                
                <div className={styles.chartContainer}>
                  <h4>Leads - MQL to SQL</h4>
                  <ResponsiveContainer width="100%" height={200}>
                    <ComposedChart data={timeSeriesData}>
                      <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                      <XAxis dataKey="date" />
                      <YAxis />
                      <Tooltip />
                      <Bar dataKey="footfall" fill="#0078d4" opacity={0.8} />
                      <Line type="monotone" dataKey="conversion" stroke="#ff7300" strokeWidth={2} yAxisId="right" />
                      <YAxis yAxisId="right" orientation="right" />
                    </ComposedChart>
                  </ResponsiveContainer>
                  <div className={styles.chartLegend}>
                    <span className={styles.legendItem}>
                      <span className={styles.legendDot} style={{backgroundColor: '#0078d4'}}></span>
                      MQL TO SQL Conv. Rate
                    </span>
                    <span className={styles.legendItem}>
                      <span className={styles.legendDot} style={{backgroundColor: '#ff7300'}}></span>
                      Leads to New Customer
                    </span>
                  </div>
                </div>
              </div>
            </div>

            {/* Finance & HR Row */}
            <div className={styles.departmentGrid}>
              {/* Finance Section */}
              <div className={styles.departmentCard}>
                <div className={styles.departmentHeader}>
                  <h3>Finance</h3>
                  <button className={styles.viewDetailsBtn}>View Details →</button>
                </div>
                
                <div className={styles.chartContainer}>
                  <h4>Cash Flow Monthly Trend</h4>
                  <ResponsiveContainer width="100%" height={200}>
                    <AreaChart data={kpiData.finance.cashFlow}>
                      <defs>
                        <linearGradient id="cashGradient" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#52c41a" stopOpacity={0.8}/>
                          <stop offset="95%" stopColor="#52c41a" stopOpacity={0.1}/>
                        </linearGradient>
                        <linearGradient id="forecastGradient" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#ff7300" stopOpacity={0.8}/>
                          <stop offset="95%" stopColor="#ff7300" stopOpacity={0.1}/>
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                      <XAxis dataKey="month" />
                      <YAxis />
                      <Tooltip formatter={(value) => `₱${(value/1000).toFixed(0)}K`} />
                      <Area type="monotone" dataKey="actual" stroke="#52c41a" fillOpacity={1} fill="url(#cashGradient)" />
                      <Area type="monotone" dataKey="forecast" stroke="#ff7300" fillOpacity={1} fill="url(#forecastGradient)" />
                    </AreaChart>
                  </ResponsiveContainer>
                  <div className={styles.chartLegend}>
                    <span className={styles.legendItem}>
                      <span className={styles.legendDot} style={{backgroundColor: '#52c41a'}}></span>
                      Cash Flow
                    </span>
                    <span className={styles.legendItem}>
                      <span className={styles.legendDot} style={{backgroundColor: '#ff7300'}}></span>
                      Forecast Cash Flow
                    </span>
                  </div>
                </div>
              </div>

              {/* HR Section */}
              <div className={styles.departmentCard}>
                <div className={styles.departmentHeader}>
                  <h3>HR</h3>
                  <button className={styles.viewDetailsBtn}>View Details →</button>
                </div>
                
                <div className={styles.chartContainer}>
                  <h4>Hiring vs Attrition rate by year</h4>
                  <ResponsiveContainer width="100%" height={200}>
                    <LineChart data={[
                      { month: 'Jan', hiring: 78, attrition: 12 },
                      { month: 'Feb', hiring: 80, attrition: 10 },
                      { month: 'Mar', hiring: 82, attrition: 9 },
                      { month: 'Apr', hiring: 82, attrition: 8 }
                    ]}>
                      <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                      <XAxis dataKey="month" />
                      <YAxis />
                      <Tooltip />
                      <Line type="monotone" dataKey="hiring" stroke="#1890ff" strokeWidth={2} dot={{ fill: '#1890ff' }} />
                      <Line type="monotone" dataKey="attrition" stroke="#ff4d4f" strokeWidth={2} dot={{ fill: '#ff4d4f' }} />
                    </LineChart>
                  </ResponsiveContainer>
                  <div className={styles.chartLegend}>
                    <span className={styles.legendItem}>
                      <span className={styles.legendDot} style={{backgroundColor: '#1890ff'}}></span>
                      Hiring Rate
                    </span>
                    <span className={styles.legendItem}>
                      <span className={styles.legendDot} style={{backgroundColor: '#ff4d4f'}}></span>
                      Attrition Rate
                    </span>
                  </div>
                </div>
              </div>
            </div>

            {/* Smart Chat Interface */}
            <div className={styles.smartChatBox}>
              <div className={styles.smartChatIcon}>
                <Brain size={20} />
              </div>
              <input 
                type="text" 
                placeholder="Ask Scout AI about your retail data..."
                className={styles.smartChatInput}
              />
              <button className={styles.smartChatButton}>
                <Search size={16} />
              </button>
            </div>
          </div>
        );

      case 'productivity':
        return (
          <div className={styles.productivityContent}>
            <div className={styles.productivityHeader}>
              <h2>Store Performance Analytics</h2>
              <div className={styles.productivityActions}>
                <select className={styles.regionFilter}>
                  <option value="all">All Regions</option>
                  <option value="ncr">NCR</option>
                  <option value="visayas">Visayas</option>
                  <option value="mindanao">Mindanao</option>
                </select>
                <button className={styles.exportBtn}>
                  <Download size={16} /> Export
                </button>
              </div>
            </div>
            
            <div className={styles.storeGrid}>
              {storeData.map((store, idx) => (
                <div key={idx} className={styles.storeCard}>
                  <div className={styles.storeHeader}>
                    <h3>{store.name}</h3>
                    <span className={styles.storeRegion}>{store.region}</span>
                  </div>
                  <div className={styles.storeMetrics}>
                    <div className={styles.storeMetric}>
                      <span className={styles.storeMetricLabel}>Revenue</span>
                      <span className={styles.storeMetricValue}>₱{(store.revenue/1000000).toFixed(2)}M</span>
                    </div>
                    <div className={styles.storeMetric}>
                      <span className={styles.storeMetricLabel}>Transactions</span>
                      <span className={styles.storeMetricValue}>{store.transactions.toLocaleString()}</span>
                    </div>
                    <div className={styles.storeMetric}>
                      <span className={styles.storeMetricLabel}>Growth</span>
                      <span className={`${styles.storeMetricValue} ${store.growth > 0 ? styles.positive : styles.negative}`}>
                        {store.growth > 0 ? '+' : ''}{store.growth}%
                      </span>
                    </div>
                  </div>
                  <div className={styles.storeActions}>
                    <button className={styles.storeActionBtn}>View Details</button>
                    <button className={styles.storeActionBtn}>Analytics</button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        );

      case 'collaboration':
        return (
          <div className={styles.collaborationContent}>
            <div className={styles.collaborationHeader}>
              <h2>Campaign Performance & ROI</h2>
              <div className={styles.collaborationFilters}>
                <select className={styles.brandFilter}>
                  <option value="all">All Brands</option>
                  <option value="brand1">Brand A</option>
                  <option value="brand2">Brand B</option>
                </select>
                <select className={styles.yearFilter}>
                  <option value="2024">2024</option>
                  <option value="2023">2023</option>
                </select>
              </div>
            </div>

            <div className={styles.campaignGrid}>
              <div className={styles.campaignCard}>
                <div className={styles.campaignHeader}>
                  <Award size={24} color="#FFD700" />
                  <h3>Holiday Season Blast</h3>
                </div>
                <div className={styles.campaignMetrics}>
                  <div className={styles.campaignMetric}>
                    <span>ROI</span>
                    <strong>3.5x</strong>
                  </div>
                  <div className={styles.campaignMetric}>
                    <span>CES Score</span>
                    <strong>92</strong>
                  </div>
                  <div className={styles.campaignMetric}>
                    <span>Sales Uplift</span>
                    <strong>+24%</strong>
                  </div>
                </div>
                <div className={styles.campaignStatus}>
                  <span className={styles.statusBadge}>Award Winner</span>
                </div>
              </div>

              <div className={styles.campaignCard}>
                <div className={styles.campaignHeader}>
                  <Target size={24} color="#0078d4" />
                  <h3>Back to School Promo</h3>
                </div>
                <div className={styles.campaignMetrics}>
                  <div className={styles.campaignMetric}>
                    <span>ROI</span>
                    <strong>2.8x</strong>
                  </div>
                  <div className={styles.campaignMetric}>
                    <span>CES Score</span>
                    <strong>85</strong>
                  </div>
                  <div className={styles.campaignMetric}>
                    <span>Sales Uplift</span>
                    <strong>+18%</strong>
                  </div>
                </div>
                <div className={styles.campaignStatus}>
                  <span className={styles.statusBadge}>High Performer</span>
                </div>
              </div>
            </div>

            {/* Category Performance Chart */}
            <div className={styles.categoryChart}>
              <h3>Revenue by Category</h3>
              <ResponsiveContainer width="100%" height={300}>
                <PieChart>
                  <Pie
                    data={categoryData}
                    cx="50%"
                    cy="50%"
                    labelLine={false}
                    label={({name, value}) => `${name} ${value}%`}
                    outerRadius={100}
                    fill="#8884d8"
                    dataKey="value"
                  >
                    {categoryData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            </div>
          </div>
        );

      default:
        return null;
    }
  };

  return (
    <Layout title="Scout Analytics Platform" description="Philippine Retail Intelligence Dashboard">
      <div className={styles.scoutDashboard}>
        {/* Top Navigation */}
        <div className={styles.topNav}>
          <div className={styles.topNavLeft}>
            <button 
              className={styles.menuToggle}
              onClick={() => setSidebarCollapsed(!sidebarCollapsed)}
            >
              <Menu size={20} />
            </button>
            <div className={styles.logo}>
              <Package size={24} />
              <span>Scout Analytics</span>
            </div>
          </div>
          
          <div className={styles.topNavCenter}>
            <div className={styles.tabNav}>
              <button 
                className={`${styles.tabButton} ${activeTab === 'dashboard' ? styles.active : ''}`}
                onClick={() => setActiveTab('dashboard')}
              >
                My Dashboard
              </button>
              <button 
                className={`${styles.tabButton} ${activeTab === 'productivity' ? styles.active : ''}`}
                onClick={() => setActiveTab('productivity')}
              >
                Productivity
              </button>
              <button 
                className={`${styles.tabButton} ${activeTab === 'collaboration' ? styles.active : ''}`}
                onClick={() => setActiveTab('collaboration')}
              >
                Collaboration
              </button>
            </div>
          </div>

          <div className={styles.topNavRight}>
            <button className={styles.iconButton} onClick={handleRefresh}>
              <RefreshCw size={18} className={refreshing ? styles.spinning : ''} />
            </button>
            <button className={styles.iconButton}>
              <Bell size={18} />
              <span className={styles.notificationDot}></span>
            </button>
            <button className={styles.newDashboardBtn}>
              + New Dashboard
            </button>
            <div className={styles.userMenu}>
              <img src="/img/avatar.png" alt="User" className={styles.userAvatar} />
              <ChevronDown size={16} />
            </div>
          </div>
        </div>

        {/* Main Layout */}
        <div className={styles.mainLayout}>
          {/* Sidebar */}
          <div className={`${styles.sidebar} ${sidebarCollapsed ? styles.collapsed : ''}`}>
            <nav className={styles.sideNav}>
              <button className={styles.sideNavItem}>
                <Home size={20} />
                {!sidebarCollapsed && <span>Overview</span>}
              </button>
              <button className={styles.sideNavItem}>
                <Store size={20} />
                {!sidebarCollapsed && <span>Stores</span>}
              </button>
              <button className={styles.sideNavItem}>
                <Package size={20} />
                {!sidebarCollapsed && <span>Products</span>}
              </button>
              <button className={styles.sideNavItem}>
                <BarChart3 size={20} />
                {!sidebarCollapsed && <span>Analytics</span>}
              </button>
              <button className={styles.sideNavItem}>
                <Map size={20} />
                {!sidebarCollapsed && <span>Geographic</span>}
              </button>
              <button className={styles.sideNavItem}>
                <Brain size={20} />
                {!sidebarCollapsed && <span>AI Insights</span>}
              </button>
              <button className={styles.sideNavItem}>
                <Database size={20} />
                {!sidebarCollapsed && <span>Data Sources</span>}
              </button>
              
              <div className={styles.sideNavDivider}></div>
              
              <button className={styles.sideNavItem}>
                <FileText size={20} />
                {!sidebarCollapsed && <span>Reports</span>}
              </button>
              <button className={styles.sideNavItem}>
                <Settings size={20} />
                {!sidebarCollapsed && <span>Settings</span>}
              </button>
              <button className={styles.sideNavItem}>
                <HelpCircle size={20} />
                {!sidebarCollapsed && <span>Help</span>}
              </button>
            </nav>

            {!sidebarCollapsed && (
              <div className={styles.sidebarFooter}>
                <div className={styles.chatAssistant}>
                  <Brain size={16} />
                  <span>Smart Chat (Ctrl+Space)</span>
                </div>
              </div>
            )}
          </div>

          {/* Content Area */}
          <div className={styles.contentArea}>
            {renderTabContent()}
          </div>
        </div>
      </div>
    </Layout>
  );
}