import React, { useState, useEffect } from 'react';
import { TabNavigation, TabContent } from './components/TabNavigation';
import { ChartContainer } from './components/charts/ChartWrappers';
import { FilterPanel } from './components/FilterPanel';
import { useFiltersStore } from './store/filters';
import { useAIInsights, useAnomalyDetection } from './services/ai-integration';
import dashboardConfig from './config/dashboard-config.json';

// Tab components
import { OverviewTab } from './components/tabs/OverviewTab';
import { MixTab } from './components/tabs/MixTab';
import { CompetitiveTab } from './components/tabs/CompetitiveTab';
import { GeographyTab } from './components/tabs/GeographyTab';
import { ConsumersTab } from './components/tabs/ConsumersTab';
import { AITab } from './components/tabs/AITab';

export interface ScoutDashboardProps {
  persona?: string;
  theme?: 'light' | 'dark';
  className?: string;
}

export const ScoutDashboard: React.FC<ScoutDashboardProps> = ({
  persona = 'regional_manager',
  theme = 'light',
  className = ''
}) => {
  const { activeTab, hasActiveFilters } = useFiltersStore();
  const [showFilters, setShowFilters] = useState(false);
  const { anomalies, clearAnomalies } = useAnomalyDetection();

  // Tab change handler
  const handleTabChange = (tabId: string) => {
    console.log(`Tab changed to: ${tabId}`);
  };

  // Render tab content based on active tab
  const renderTabContent = () => {
    switch (activeTab) {
      case 'overview':
        return <OverviewTab persona={persona} />;
      case 'mix':
        return <MixTab persona={persona} />;
      case 'competitive':
        return <CompetitiveTab persona={persona} />;
      case 'geography':
        return <GeographyTab persona={persona} />;
      case 'consumers':
        return <ConsumersTab persona={persona} />;
      case 'ai':
        return <AITab persona={persona} />;
      default:
        return <OverviewTab persona={persona} />;
    }
  };

  const DashboardHeader = () => (
    <div className="bg-white border-b border-gray-200 px-6 py-4">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">
            {dashboardConfig.dashboard.title}
          </h1>
          <p className="text-sm text-gray-600 mt-1">
            {dashboardConfig.dashboard.subtitle} • v{dashboardConfig.dashboard.version}
          </p>
        </div>
        
        <div className="flex items-center space-x-4">
          {/* Anomaly Alerts */}
          {anomalies.length > 0 && (
            <div className="flex items-center space-x-2">
              <div className="relative">
                <button
                  className="p-2 text-red-600 hover:text-red-800 hover:bg-red-50 rounded-lg transition-colors"
                  onClick={() => {
                    // Handle anomaly alert click
                    console.log('Anomaly alerts:', anomalies);
                  }}
                >
                  <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                  </svg>
                  {anomalies.length > 1 && (
                    <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full h-5 w-5 flex items-center justify-center">
                      {anomalies.length}
                    </span>
                  )}
                </button>
              </div>
            </div>
          )}

          {/* Filter Toggle */}
          <button
            onClick={() => setShowFilters(!showFilters)}
            className={`flex items-center px-4 py-2 rounded-lg border transition-colors ${
              hasActiveFilters()
                ? 'bg-blue-50 border-blue-200 text-blue-700 hover:bg-blue-100'
                : 'bg-white border-gray-300 text-gray-700 hover:bg-gray-50'
            }`}
          >
            <svg className="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.707A1 1 0 013 7V4z" />
            </svg>
            Filters
            {hasActiveFilters() && (
              <span className="ml-2 bg-blue-600 text-white text-xs px-2 py-0.5 rounded-full">
                Active
              </span>
            )}
          </button>

          {/* Refresh Data */}
          <button
            className="p-2 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors"
            onClick={() => {
              // Handle data refresh
              window.location.reload();
            }}
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
          </button>
        </div>
      </div>
    </div>
  );

  const FilterSlideOut = () => (
    <div className={`fixed inset-y-0 right-0 z-50 w-96 bg-white border-l border-gray-200 transform transition-transform duration-300 ease-in-out ${showFilters ? 'translate-x-0' : 'translate-x-full'}`}>
      <div className="flex items-center justify-between p-4 border-b border-gray-200">
        <h2 className="text-lg font-semibold text-gray-900">Filters</h2>
        <button
          onClick={() => setShowFilters(false)}
          className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <div className="p-4">
        <FilterPanel />
      </div>
    </div>
  );

  const Overlay = () => showFilters ? (
    <div 
      className="fixed inset-0 bg-black bg-opacity-50 z-40"
      onClick={() => setShowFilters(false)}
    />
  ) : null;

  return (
    <div className={`min-h-screen bg-gray-50 ${theme === 'dark' ? 'dark' : ''} ${className}`}>
      {/* Dashboard Header */}
      <DashboardHeader />

      {/* Tab Navigation */}
      <TabNavigation 
        persona={persona} 
        onTabChange={handleTabChange}
        className="sticky top-0 z-30"
      />

      {/* Main Content */}
      <main className="relative">
        {/* Tab Content */}
        <div className="min-h-screen">
          <TabContent tabId={activeTab}>
            {renderTabContent()}
          </TabContent>
        </div>

        {/* Filter Slide-out */}
        <FilterSlideOut />
        
        {/* Overlay */}
        <Overlay />
      </main>

      {/* Real-time Status Bar */}
      <div className="fixed bottom-4 right-4 z-20">
        <div className="bg-white border border-gray-200 rounded-lg shadow-lg px-4 py-2 flex items-center space-x-3">
          <div className="flex items-center">
            <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse mr-2"></div>
            <span className="text-sm text-gray-600">Live Data</span>
          </div>
          
          {dashboardConfig.ai_integration.mode === 'mcp_dev_mode' && (
            <div className="flex items-center">
              <div className="w-2 h-2 bg-purple-500 rounded-full mr-2"></div>
              <span className="text-sm text-gray-600">AI Ready</span>
            </div>
          )}
          
          <div className="text-xs text-gray-500">
            Last updated: {new Date().toLocaleTimeString()}
          </div>
        </div>
      </div>
    </div>
  );
};

export default ScoutDashboard;