import React, { useState, useEffect } from 'react';
import { useFiltersStore } from '../store/filters';
import dashboardConfig from '../config/dashboard-config.json';

export interface TabConfig {
  id: string;
  title: string;
  icon: string;
  description: string;
  components: string[];
  personas: string[];
  priority: number;
  mcpIntegration?: boolean;
}

export interface TabNavigationProps {
  persona?: string;
  onTabChange?: (tabId: string) => void;
  className?: string;
}

export const TabNavigation: React.FC<TabNavigationProps> = ({
  persona = 'regional_manager',
  onTabChange,
  className = ''
}) => {
  const { activeTab, setActiveTab } = useFiltersStore();
  const [availableTabs, setAvailableTabs] = useState<TabConfig[]>([]);

  // Filter tabs based on persona access
  useEffect(() => {
    const tabs = dashboardConfig.tabs.filter(tab => 
      tab.personas.includes('all') || 
      tab.personas.includes(persona)
    ).sort((a, b) => a.priority - b.priority);
    
    setAvailableTabs(tabs);
    
    // Ensure active tab is accessible to current persona
    if (!tabs.find(tab => tab.id === activeTab)) {
      const defaultTab = tabs[0]?.id || 'overview';
      setActiveTab(defaultTab);
      onTabChange?.(defaultTab);
    }
  }, [persona, activeTab, setActiveTab, onTabChange]);

  const handleTabClick = (tabId: string) => {
    setActiveTab(tabId);
    onTabChange?.(tabId);
  };

  const getTabIcon = (tab: TabConfig) => {
    // Add special indicators for AI tab and restricted access
    const baseIcon = tab.icon;
    if (tab.mcpIntegration) {
      return `${baseIcon} 🤖`;
    }
    return baseIcon;
  };

  const isTabActive = (tabId: string) => activeTab === tabId;

  const getTabClassName = (tab: TabConfig) => {
    const baseClasses = `
      relative flex items-center px-6 py-4 text-sm font-medium transition-all duration-200 cursor-pointer
      border-b-2 whitespace-nowrap
    `;
    
    if (isTabActive(tab.id)) {
      return `${baseClasses} 
        text-blue-600 border-blue-600 bg-blue-50/50
        before:absolute before:bottom-0 before:left-0 before:right-0 before:h-0.5 
        before:bg-gradient-to-r before:from-blue-500 before:to-indigo-500
      `;
    }
    
    return `${baseClasses} 
      text-gray-600 border-transparent hover:text-gray-900 hover:border-gray-300
      hover:bg-gray-50/50
    `;
  };

  const TabBadge: React.FC<{ tab: TabConfig }> = ({ tab }) => {
    if (tab.mcpIntegration) {
      return (
        <span className="ml-2 px-2 py-0.5 text-xs font-medium bg-purple-100 text-purple-700 rounded-full">
          AI
        </span>
      );
    }
    return null;
  };

  const TabTooltip: React.FC<{ tab: TabConfig; children: React.ReactNode }> = ({ tab, children }) => (
    <div className="group relative">
      {children}
      <div className="absolute z-50 invisible group-hover:visible opacity-0 group-hover:opacity-100 
                      transition-all duration-200 bottom-full left-1/2 transform -translate-x-1/2 mb-2">
        <div className="bg-gray-900 text-white text-xs rounded-lg px-3 py-2 whitespace-nowrap max-w-xs">
          {tab.description}
          <div className="absolute top-full left-1/2 transform -translate-x-1/2 
                         border-4 border-transparent border-t-gray-900"></div>
        </div>
      </div>
    </div>
  );

  if (availableTabs.length === 0) {
    return (
      <div className="flex items-center justify-center h-16 bg-gray-50 border-b">
        <span className="text-sm text-gray-500">Loading navigation...</span>
      </div>
    );
  }

  return (
    <div className={`bg-white border-b border-gray-200 ${className}`}>
      {/* Tab Navigation */}
      <div className="flex items-center overflow-x-auto scrollbar-hide">
        {availableTabs.map((tab) => (
          <TabTooltip key={tab.id} tab={tab}>
            <button
              onClick={() => handleTabClick(tab.id)}
              className={getTabClassName(tab)}
              role="tab"
              aria-selected={isTabActive(tab.id)}
              aria-controls={`tabpanel-${tab.id}`}
              id={`tab-${tab.id}`}
            >
              <span className="mr-2 text-base" role="img" aria-label={tab.title}>
                {getTabIcon(tab)}
              </span>
              <span>{tab.title}</span>
              <TabBadge tab={tab} />
            </button>
          </TabTooltip>
        ))}
      </div>

      {/* Persona Indicator */}
      <div className="px-6 py-2 bg-gray-50 border-b border-gray-100">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-2 text-xs text-gray-600">
            <span className="inline-flex items-center px-2 py-1 rounded-full bg-blue-100 text-blue-800 font-medium">
              {persona.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())}
            </span>
            <span>•</span>
            <span>{availableTabs.length} tabs available</span>
          </div>
          
          {/* Active tab info */}
          {activeTab && (
            <div className="text-xs text-gray-500">
              {availableTabs.find(tab => tab.id === activeTab)?.description}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

// Tab content wrapper component
export interface TabContentProps {
  tabId: string;
  children: React.ReactNode;
  className?: string;
  loading?: boolean;
}

export const TabContent: React.FC<TabContentProps> = ({
  tabId,
  children,
  className = '',
  loading = false
}) => {
  const { activeTab } = useFiltersStore();
  const isActive = activeTab === tabId;

  if (!isActive) {
    return null;
  }

  if (loading) {
    return (
      <div className={`min-h-96 flex items-center justify-center ${className}`}>
        <div className="flex flex-col items-center space-y-4">
          <div className="w-8 h-8 border-4 border-blue-200 border-t-blue-600 rounded-full animate-spin"></div>
          <span className="text-sm text-gray-600">Loading {tabId} data...</span>
        </div>
      </div>
    );
  }

  return (
    <div
      id={`tabpanel-${tabId}`}
      role="tabpanel"
      aria-labelledby={`tab-${tabId}`}
      className={`min-h-96 ${className}`}
    >
      {children}
    </div>
  );
};

// Mobile-responsive tab selector
export const MobileTabSelector: React.FC<{
  persona: string;
  onTabChange?: (tabId: string) => void;
}> = ({ persona, onTabChange }) => {
  const { activeTab, setActiveTab } = useFiltersStore();
  const [isOpen, setIsOpen] = useState(false);

  const availableTabs = dashboardConfig.tabs.filter(tab => 
    tab.personas.includes('all') || 
    tab.personas.includes(persona)
  ).sort((a, b) => a.priority - b.priority);

  const activeTabConfig = availableTabs.find(tab => tab.id === activeTab);

  const handleTabSelect = (tabId: string) => {
    setActiveTab(tabId);
    onTabChange?.(tabId);
    setIsOpen(false);
  };

  return (
    <div className="md:hidden relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center justify-between w-full px-4 py-3 text-sm font-medium 
                   text-gray-900 bg-white border border-gray-300 rounded-lg shadow-sm 
                   hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500"
      >
        <div className="flex items-center">
          <span className="mr-2 text-base">
            {activeTabConfig?.icon}
          </span>
          <span>{activeTabConfig?.title || 'Select Tab'}</span>
        </div>
        <svg
          className={`w-5 h-5 transition-transform ${isOpen ? 'rotate-180' : ''}`}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="m19 9-7 7-7-7" />
        </svg>
      </button>

      {isOpen && (
        <div className="absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg">
          {availableTabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => handleTabSelect(tab.id)}
              className={`flex items-center w-full px-4 py-3 text-sm hover:bg-gray-50
                         ${tab.id === activeTab ? 'bg-blue-50 text-blue-600' : 'text-gray-900'}
                         ${tab === availableTabs[0] ? 'rounded-t-lg' : ''}
                         ${tab === availableTabs[availableTabs.length - 1] ? 'rounded-b-lg' : ''}
                         border-b border-gray-100 last:border-b-0`}
            >
              <span className="mr-3 text-base">
                {getTabIcon(tab)}
              </span>
              <div className="text-left">
                <div className="font-medium">{tab.title}</div>
                <div className="text-xs text-gray-500">{tab.description}</div>
              </div>
              {tab.mcpIntegration && (
                <span className="ml-auto px-2 py-1 text-xs bg-purple-100 text-purple-700 rounded-full">
                  AI
                </span>
              )}
            </button>
          ))}
        </div>
      )}
    </div>
  );
};

// Helper function to get tab icon with special indicators
function getTabIcon(tab: TabConfig): string {
  if (tab.mcpIntegration) {
    return `${tab.icon}`;
  }
  return tab.icon;
}

export default TabNavigation;