import React, { useState, useEffect, useCallback } from 'react';
import Layout from '@theme/Layout';
import { Responsive, WidthProvider } from 'react-grid-layout';
import { 
  LineChart, Line, AreaChart, Area, BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer
} from 'recharts';
import { 
  TrendingUp, Store, Package, DollarSign, Users, Activity, Brain,
  Home, BarChart3, Database, Settings, HelpCircle, Search,
  ChevronDown, Filter, Calendar, Download, RefreshCw, 
  Menu, X, Bell, Maximize2, Minimize2, MoreVertical, 
  Target, Award, Globe, Clock, AlertCircle, Zap,
  Map, ShoppingBag, FileText, Grid, Layout as LayoutIcon
} from 'lucide-react';
import openAIService from '../services/openai-service';
import styles from './scout-advanced.module.css';

const ResponsiveGridLayout = WidthProvider(Responsive);

export default function ScoutAdvancedDashboard() {
  const [activeTab, setActiveTab] = useState('overview');
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [darkMode, setDarkMode] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [realTimeData, setRealTimeData] = useState(true);
  const [chatOpen, setChatOpen] = useState(false);
  const [currentLayout, setCurrentLayout] = useState('default');

  // Grid layouts for different dashboard views
  const layouts = {
    lg: [
      { i: 'kpi-overview', x: 0, y: 0, w: 12, h: 2, minH: 2 },
      { i: 'sales-trend', x: 0, y: 2, w: 8, h: 4, minH: 3 },
      { i: 'top-stores', x: 8, y: 2, w: 4, h: 4, minH: 3 },
      { i: 'category-performance', x: 0, y: 6, w: 6, h: 4, minH: 3 },
      { i: 'geographic-map', x: 6, y: 6, w: 6, h: 4, minH: 3 },
      { i: 'ai-insights', x: 0, y: 10, w: 12, h: 3, minH: 2 }
    ],
    md: [
      { i: 'kpi-overview', x: 0, y: 0, w: 10, h: 2 },
      { i: 'sales-trend', x: 0, y: 2, w: 10, h: 4 },
      { i: 'top-stores', x: 0, y: 6, w: 5, h: 4 },
      { i: 'category-performance', x: 5, y: 6, w: 5, h: 4 },
      { i: 'geographic-map', x: 0, y: 10, w: 10, h: 4 },
      { i: 'ai-insights', x: 0, y: 14, w: 10, h: 3 }
    ],
    sm: [
      { i: 'kpi-overview', x: 0, y: 0, w: 6, h: 3 },
      { i: 'sales-trend', x: 0, y: 3, w: 6, h: 4 },
      { i: 'top-stores', x: 0, y: 7, w: 6, h: 4 },
      { i: 'category-performance', x: 0, y: 11, w: 6, h: 4 },
      { i: 'geographic-map', x: 0, y: 15, w: 6, h: 4 },
      { i: 'ai-insights', x: 0, y: 19, w: 6, h: 3 }
    ]
  };

  // Enhanced data with time series
  const kpiData = [
    { 
      id: 'revenue',
      title: 'Total Revenue', 
      value: '₱5.59M', 
      change: 12.3, 
      icon: DollarSign,
      color: '#1a73e8',
      sparklineData: [450, 520, 480, 590, 720, 980, 850, 920, 1100, 1050],
      target: 6000000,
      current: 5590000
    },
    { 
      id: 'transactions',
      title: 'Transactions', 
      value: '12,676', 
      change: 8.7, 
      icon: Package,
      color: '#34a853',
      sparklineData: [120, 135, 128, 145, 160, 155, 170, 165, 180, 176],
      target: 15000,
      current: 12676
    },
    { 
      id: 'customers',
      title: 'Active Customers', 
      value: '8,429', 
      change: 15.4, 
      icon: Users,
      color: '#fbbc04',
      sparklineData: [800, 820, 850, 880, 910, 920, 950, 980, 1000, 1020],
      target: 10000,
      current: 8429
    },
    { 
      id: 'conversion',
      title: 'Conversion Rate', 
      value: '3.4%', 
      change: 2.1, 
      icon: Target,
      color: '#ea4335',
      sparklineData: [3.1, 3.2, 3.0, 3.3, 3.5, 3.4, 3.6, 3.5, 3.7, 3.4],
      target: 4.0,
      current: 3.4
    }
  ];

  const salesTrendData = [
    { date: 'Jan', revenue: 4200000, transactions: 11000, customers: 7800, forecast: 4100000 },
    { date: 'Feb', revenue: 4500000, transactions: 11500, customers: 8000, forecast: 4400000 },
    { date: 'Mar', revenue: 4800000, transactions: 12100, customers: 8200, forecast: 4700000 },
    { date: 'Apr', revenue: 5100000, transactions: 12400, customers: 8300, forecast: 5000000 },
    { date: 'May', revenue: 5400000, transactions: 12600, customers: 8400, forecast: 5300000 },
    { date: 'Jun', revenue: 5590000, transactions: 12676, customers: 8429, forecast: 5500000 }
  ];

  const storePerformance = [
    { name: 'SM Mall of Asia', revenue: 2450000, efficiency: 94, growth: 15.2, region: 'NCR', status: 'excellent' },
    { name: 'Robinsons Galleria', revenue: 1890000, efficiency: 87, growth: -5.3, region: 'NCR', status: 'good' },
    { name: 'Ayala Center Cebu', revenue: 1750000, efficiency: 91, growth: 22.1, region: 'Visayas', status: 'excellent' },
    { name: 'SM North EDSA', revenue: 1620000, efficiency: 83, growth: 8.7, region: 'NCR', status: 'good' },
    { name: 'Greenbelt Makati', revenue: 1480000, efficiency: 89, growth: 12.4, region: 'NCR', status: 'good' }
  ];

  const categoryData = [
    { name: 'Electronics', value: 35, color: '#1a73e8', revenue: 1953000 },
    { name: 'Fashion', value: 28, color: '#34a853', revenue: 1565200 },
    { name: 'Groceries', value: 20, color: '#fbbc04', revenue: 1118000 },
    { name: 'Home & Living', value: 10, color: '#ea4335', revenue: 559000 },
    { name: 'Beauty', value: 7, color: '#9aa0a6', revenue: 391300 }
  ];

  // AI Chat functionality with OpenAI integration
  const [chatMessages, setChatMessages] = useState([
    {
      type: 'bot',
      message: 'Hi! I\'m Scout AI. Ask me anything about your retail data.',
      timestamp: new Date()
    }
  ]);
  const [chatInput, setChatInput] = useState('');

  const sendChatMessage = useCallback(async (message) => {
    if (!message.trim()) return;

    // Add user message
    const userMessage = {
      type: 'user',
      message,
      timestamp: new Date()
    };
    setChatMessages(prev => [...prev, userMessage]);
    setChatInput('');

    try {
      // Get AI response from OpenAI service
      const aiResponse = await openAIService.sendMessage(message, chatMessages);
      
      const botResponse = {
        type: 'bot',
        message: aiResponse,
        timestamp: new Date()
      };
      setChatMessages(prev => [...prev, botResponse]);
      
    } catch (error) {
      console.error('Chat error:', error);
      const errorResponse = {
        type: 'bot',
        message: 'Sorry, I\'m having trouble processing your request. Please try again.',
        timestamp: new Date()
      };
      setChatMessages(prev => [...prev, errorResponse]);
    }
  }, [chatMessages]);

  // Real-time data simulation
  useEffect(() => {
    if (!realTimeData) return;
    
    const interval = setInterval(() => {
      // Simulate real-time updates
      setRefreshing(true);
      setTimeout(() => setRefreshing(false), 500);
    }, 30000);

    return () => clearInterval(interval);
  }, [realTimeData]);

  // Keyboard shortcuts
  useEffect(() => {
    const handleKeyPress = (e) => {
      if (e.key === '/' && !searchOpen) {
        e.preventDefault();
        setSearchOpen(true);
      }
      if (e.key === 'Escape') {
        setSearchOpen(false);
        setChatOpen(false);
      }
      if (e.ctrlKey && e.key === ' ') {
        e.preventDefault();
        setChatOpen(!chatOpen);
      }
    };

    document.addEventListener('keydown', handleKeyPress);
    return () => document.removeEventListener('keydown', handleKeyPress);
  }, [searchOpen, chatOpen]);

  const renderKPICard = (kpi) => (
    <div key={kpi.id} className={styles.kpiCard}>
      <div className={styles.kpiHeader}>
        <div className={styles.kpiIcon} style={{ color: kpi.color }}>
          <kpi.icon size={20} />
        </div>
        <div className={styles.kpiActions}>
          <button className={styles.kpiActionBtn}>
            <MoreVertical size={16} />
          </button>
        </div>
      </div>
      
      <div className={styles.kpiContent}>
        <div className={styles.kpiTitle}>{kpi.title}</div>
        <div className={styles.kpiValue}>{kpi.value}</div>
        <div className={`${styles.kpiChange} ${kpi.change >= 0 ? styles.positive : styles.negative}`}>
          {kpi.change >= 0 ? '↗' : '↘'} {Math.abs(kpi.change)}%
          <span className={styles.kpiPeriod}>vs last period</span>
        </div>
      </div>

      <div className={styles.kpiSparkline}>
        <ResponsiveContainer width="100%" height={40}>
          <LineChart data={kpi.sparklineData.map((value, index) => ({ value, index }))}>
            <Line 
              type="monotone" 
              dataKey="value" 
              stroke={kpi.color} 
              strokeWidth={2}
              dot={false}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>

      <div className={styles.kpiProgress}>
        <div className={styles.kpiProgressLabel}>
          {((kpi.current / kpi.target) * 100).toFixed(1)}% of target
        </div>
        <div className={styles.kpiProgressBar}>
          <div 
            className={styles.kpiProgressFill}
            style={{ 
              width: `${Math.min((kpi.current / kpi.target) * 100, 100)}%`,
              background: kpi.color
            }}
          />
        </div>
      </div>
    </div>
  );

  const renderDashboardPanel = (key, children, title, actions = null) => (
    <div key={key} className={styles.dashboardPanel}>
      <div className={styles.panelHeader}>
        <h3 className={styles.panelTitle}>{title}</h3>
        <div className={styles.panelActions}>
          {actions}
          <button className={styles.panelActionBtn}>
            <Maximize2 size={16} />
          </button>
          <button className={styles.panelActionBtn}>
            <MoreVertical size={16} />
          </button>
        </div>
      </div>
      <div className={styles.panelContent}>
        {children}
      </div>
    </div>
  );

  return (
    <Layout title="Scout Analytics - Advanced Dashboard" description="Advanced Philippine Retail Intelligence Platform">
      <div className={`${styles.scoutAdvanced} ${darkMode ? styles.darkMode : ''}`}>
        {/* Enhanced Top Navigation */}
        <header className={styles.topNav}>
          <div className={styles.topNavLeft}>
            <button 
              className={styles.menuToggle}
              onClick={() => setSidebarCollapsed(!sidebarCollapsed)}
            >
              <Menu size={20} />
            </button>
            <div className={styles.logo}>
              <div className={styles.logoIcon}>
                <BarChart3 size={24} />
              </div>
              <span className={styles.logoText}>Scout Analytics</span>
            </div>
          </div>

          <div className={styles.topNavCenter}>
            <div className={styles.searchContainer}>
              <button 
                className={styles.searchButton}
                onClick={() => setSearchOpen(true)}
              >
                <Search size={18} />
                <span>Search analytics... (Press /)</span>
              </button>
            </div>
          </div>

          <div className={styles.topNavRight}>
            <div className={styles.dataStatus}>
              <div className={`${styles.statusDot} ${realTimeData ? styles.live : ''}`} />
              <span>Live Data</span>
            </div>
            
            <button 
              className={styles.iconButton}
              onClick={() => setRefreshing(true)}
            >
              <RefreshCw size={18} className={refreshing ? styles.spinning : ''} />
            </button>

            <button className={styles.iconButton}>
              <Bell size={18} />
              <span className={styles.notificationBadge}>3</span>
            </button>

            <button 
              className={styles.iconButton}
              onClick={() => setDarkMode(!darkMode)}
            >
              {darkMode ? '☀️' : '🌙'}
            </button>

            <div className={styles.userProfile}>
              <img src="/img/avatar.png" alt="User" className={styles.avatar} />
              <ChevronDown size={16} />
            </div>
          </div>
        </header>

        {/* Enhanced Sidebar */}
        <aside className={`${styles.sidebar} ${sidebarCollapsed ? styles.collapsed : ''}`}>
          <nav className={styles.sideNav}>
            <div className={styles.navSection}>
              <div className={styles.navSectionTitle}>Analytics</div>
              <button className={`${styles.navItem} ${activeTab === 'overview' ? styles.active : ''}`}>
                <Home size={20} />
                {!sidebarCollapsed && <span>Overview</span>}
              </button>
              <button className={styles.navItem}>
                <TrendingUp size={20} />
                {!sidebarCollapsed && <span>Sales</span>}
              </button>
              <button className={styles.navItem}>
                <Users size={20} />
                {!sidebarCollapsed && <span>Customers</span>}
              </button>
            </div>

            <div className={styles.navSection}>
              <div className={styles.navSectionTitle}>Operations</div>
              <button className={styles.navItem}>
                <Store size={20} />
                {!sidebarCollapsed && <span>Stores</span>}
              </button>
              <button className={styles.navItem}>
                <Package size={20} />
                {!sidebarCollapsed && <span>Inventory</span>}
              </button>
              <button className={styles.navItem}>
                <Map size={20} />
                {!sidebarCollapsed && <span>Geographic</span>}
              </button>
            </div>

            <div className={styles.navSection}>
              <div className={styles.navSectionTitle}>Intelligence</div>
              <button className={styles.navItem}>
                <Brain size={20} />
                {!sidebarCollapsed && <span>AI Insights</span>}
              </button>
              <button className={styles.navItem}>
                <Target size={20} />
                {!sidebarCollapsed && <span>Predictions</span>}
              </button>
            </div>
          </nav>

          {!sidebarCollapsed && (
            <div className={styles.sidebarFooter}>
              <button 
                className={styles.aiChatToggle}
                onClick={() => setChatOpen(!chatOpen)}
              >
                <Brain size={16} />
                <span>AI Assistant</span>
                <kbd>Ctrl+Space</kbd>
              </button>
            </div>
          )}
        </aside>

        {/* Main Dashboard Content */}
        <main className={styles.mainContent}>
          <div className={styles.dashboardHeader}>
            <h1>Philippine Retail Intelligence</h1>
            <div className={styles.dashboardControls}>
              <select className={styles.timeRangeSelect}>
                <option value="7d">Last 7 days</option>
                <option value="30d">Last 30 days</option>
                <option value="90d">Last quarter</option>
              </select>
              <button className={styles.exportBtn}>
                <Download size={16} />
                Export
              </button>
            </div>
          </div>

          {/* Responsive Grid Layout */}
          <ResponsiveGridLayout
            className={styles.gridLayout}
            layouts={layouts}
            breakpoints={{ lg: 1200, md: 996, sm: 768, xs: 480, xxs: 0 }}
            cols={{ lg: 12, md: 10, sm: 6, xs: 4, xxs: 2 }}
            rowHeight={60}
            isDraggable={true}
            isResizable={true}
            margin={[16, 16]}
          >
            {/* KPI Overview Panel */}
            <div key="kpi-overview">
              {renderDashboardPanel(
                'kpi-overview',
                <div className={styles.kpiGrid}>
                  {kpiData.map(renderKPICard)}
                </div>,
                'Key Performance Indicators'
              )}
            </div>

            {/* Sales Trend Panel */}
            <div key="sales-trend">
              {renderDashboardPanel(
                'sales-trend',
                <ResponsiveContainer width="100%" height={200}>
                  <AreaChart data={salesTrendData}>
                    <defs>
                      <linearGradient id="revenueGradient" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="#1a73e8" stopOpacity={0.3}/>
                        <stop offset="95%" stopColor="#1a73e8" stopOpacity={0}/>
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" stroke="#e8eaed" />
                    <XAxis dataKey="date" stroke="#5f6368" />
                    <YAxis stroke="#5f6368" />
                    <Tooltip 
                      contentStyle={{ 
                        backgroundColor: 'rgba(0,0,0,0.9)', 
                        border: 'none', 
                        borderRadius: '8px',
                        color: 'white'
                      }}
                      formatter={(value) => [`₱${(value/1000000).toFixed(2)}M`, 'Revenue']}
                    />
                    <Area 
                      type="monotone" 
                      dataKey="revenue" 
                      stroke="#1a73e8" 
                      strokeWidth={2}
                      fillOpacity={1} 
                      fill="url(#revenueGradient)" 
                    />
                    <Line 
                      type="monotone" 
                      dataKey="forecast" 
                      stroke="#ea4335" 
                      strokeDasharray="5 5"
                      strokeWidth={2}
                    />
                  </AreaChart>
                </ResponsiveContainer>,
                'Sales Trend & Forecast',
                <button className={styles.panelActionBtn}>
                  <Filter size={16} />
                </button>
              )}
            </div>

            {/* Top Stores Panel */}
            <div key="top-stores">
              {renderDashboardPanel(
                'top-stores',
                <div className={styles.storeList}>
                  {storePerformance.map((store, idx) => (
                    <div key={idx} className={styles.storeItem}>
                      <div className={styles.storeInfo}>
                        <div className={styles.storeName}>{store.name}</div>
                        <div className={styles.storeRegion}>{store.region}</div>
                      </div>
                      <div className={styles.storeMetrics}>
                        <div className={styles.storeRevenue}>
                          ₱{(store.revenue/1000000).toFixed(2)}M
                        </div>
                        <div className={`${styles.storeGrowth} ${store.growth > 0 ? styles.positive : styles.negative}`}>
                          {store.growth > 0 ? '+' : ''}{store.growth}%
                        </div>
                      </div>
                      <div className={styles.storeEfficiency}>
                        <div className={styles.efficiencyBar}>
                          <div 
                            className={styles.efficiencyFill}
                            style={{ width: `${store.efficiency}%` }}
                          />
                        </div>
                        <span>{store.efficiency}%</span>
                      </div>
                    </div>
                  ))}
                </div>,
                'Top Performing Stores'
              )}
            </div>

            {/* Category Performance Panel */}
            <div key="category-performance">
              {renderDashboardPanel(
                'category-performance',
                <ResponsiveContainer width="100%" height={200}>
                  <PieChart>
                    <Pie
                      data={categoryData}
                      cx="50%"
                      cy="50%"
                      innerRadius={40}
                      outerRadius={80}
                      dataKey="value"
                      label={({name, value}) => `${name} ${value}%`}
                    >
                      {categoryData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>,
                'Category Performance'
              )}
            </div>

            {/* Geographic Map Panel */}
            <div key="geographic-map">
              {renderDashboardPanel(
                'geographic-map',
                <div className={styles.mapPlaceholder}>
                  <Map size={48} />
                  <div>Interactive Philippine Store Map</div>
                  <div className={styles.mapStats}>
                    <div>• 23 Stores across 8 regions</div>
                    <div>• Highest density: NCR (12 stores)</div>
                    <div>• Growth opportunity: Mindanao</div>
                  </div>
                </div>,
                'Geographic Distribution'
              )}
            </div>

            {/* AI Insights Panel */}
            <div key="ai-insights">
              {renderDashboardPanel(
                'ai-insights',
                <div className={styles.aiInsights}>
                  <div className={styles.insightCard}>
                    <Zap size={20} className={styles.insightIcon} />
                    <div>
                      <strong>Revenue Spike Detected:</strong> SM Mall of Asia showing 15.2% growth - consider expanding similar stores in NCR region.
                    </div>
                  </div>
                  <div className={styles.insightCard}>
                    <AlertCircle size={20} className={styles.insightIcon} />
                    <div>
                      <strong>Attention Needed:</strong> Robinsons Galleria showing -5.3% decline - investigate operational issues.
                    </div>
                  </div>
                  <div className={styles.insightCard}>
                    <Target size={20} className={styles.insightIcon} />
                    <div>
                      <strong>Opportunity:</strong> Electronics category performing well (35% share) - consider expanding inventory.
                    </div>
                  </div>
                </div>,
                'AI-Powered Insights'
              )}
            </div>
          </ResponsiveGridLayout>
        </main>

        {/* Enhanced AI Chat */}
        {chatOpen && (
          <div className={styles.aiChatPanel}>
            <div className={styles.chatHeader}>
              <div className={styles.chatTitle}>
                <Brain size={20} />
                Scout AI Assistant
              </div>
              <button 
                className={styles.chatClose}
                onClick={() => setChatOpen(false)}
              >
                <X size={18} />
              </button>
            </div>
            
            <div className={styles.chatMessages}>
              {chatMessages.map((msg, idx) => (
                <div key={idx} className={`${styles.chatMessage} ${styles[msg.type]}`}>
                  <div className={styles.messageContent}>{msg.message}</div>
                  <div className={styles.messageTime}>
                    {msg.timestamp.toLocaleTimeString()}
                  </div>
                </div>
              ))}
            </div>

            <div className={styles.chatInput}>
              <input
                type="text"
                placeholder="Ask about your retail data..."
                value={chatInput}
                onChange={(e) => setChatInput(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && sendChatMessage(chatInput)}
              />
              <button onClick={() => sendChatMessage(chatInput)}>
                <Search size={16} />
              </button>
            </div>
          </div>
        )}

        {/* Search Overlay */}
        {searchOpen && (
          <div className={styles.searchOverlay}>
            <div className={styles.searchBox}>
              <Search size={20} />
              <input
                type="text"
                placeholder="Search analytics, stores, customers..."
                autoFocus
                onBlur={() => setSearchOpen(false)}
              />
            </div>
          </div>
        )}
      </div>
    </Layout>
  );
}