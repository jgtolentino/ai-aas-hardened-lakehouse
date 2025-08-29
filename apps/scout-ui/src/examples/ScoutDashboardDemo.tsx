import React, { useState } from 'react';
import { ScoutDashboard } from '../components';

/**
 * Scout Dashboard Demo
 * 
 * Complete implementation of the TBWA Scout Analytics Dashboard
 * integrating financial template patterns with Scout-specific requirements.
 * 
 * Features:
 * - Real-time campaign analytics
 * - Financial performance metrics in Philippine Peso
 * - Regional performance tracking across APAC
 * - AI-powered insights and recommendations
 * - Responsive design optimized for executive viewing
 * 
 * Usage:
 * import { ScoutDashboardDemo } from '@/examples/ScoutDashboardDemo';
 * 
 * <ScoutDashboardDemo />
 */
export const ScoutDashboardDemo: React.FC = () => {
  const [currentView, setCurrentView] = useState<'executive' | 'operational' | 'creative'>('executive');
  const [timeRange, setTimeRange] = useState<'7d' | '30d' | '90d' | '1y'>('30d');

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Navigation Header */}
      <nav className="bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            {/* Brand */}
            <div className="flex items-center space-x-4">
              <div className="flex items-center">
                <div className="w-8 h-8 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-lg flex items-center justify-center">
                  <span className="text-white font-bold text-sm">S</span>
                </div>
                <div className="ml-3">
                  <h1 className="text-xl font-bold text-gray-900">Scout Analytics</h1>
                  <p className="text-xs text-gray-500">TBWA Enterprise Platform</p>
                </div>
              </div>
              
              {/* View Toggle */}
              <div className="hidden md:flex items-center space-x-1 bg-gray-100 rounded-lg p-1">
                {(['executive', 'operational', 'creative'] as const).map((view) => (
                  <button
                    key={view}
                    onClick={() => setCurrentView(view)}
                    className={`px-3 py-1 text-sm font-medium rounded-md transition-colors ${
                      currentView === view
                        ? 'bg-white text-gray-900 shadow-sm'
                        : 'text-gray-600 hover:text-gray-900'
                    }`}
                  >
                    {view.charAt(0).toUpperCase() + view.slice(1)}
                  </button>
                ))}
              </div>
            </div>

            {/* User Actions */}
            <div className="flex items-center space-x-4">
              {/* Time Range Selector */}
              <select
                value={timeRange}
                onChange={(e) => setTimeRange(e.target.value as typeof timeRange)}
                className="text-sm border border-gray-300 rounded-md px-3 py-1 bg-white focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="7d">Last 7 Days</option>
                <option value="30d">Last 30 Days</option>
                <option value="90d">Last 90 Days</option>
                <option value="1y">Last Year</option>
              </select>

              {/* Status Indicator */}
              <div className="flex items-center space-x-2">
                <div className="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
                <span className="text-sm text-gray-600">Live Data</span>
              </div>

              {/* User Avatar */}
              <div className="w-8 h-8 bg-gray-200 rounded-full flex items-center justify-center">
                <span className="text-xs font-medium text-gray-600">JT</span>
              </div>
            </div>
          </div>
        </div>
      </nav>

      {/* Main Dashboard Content */}
      <main className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
        {/* Dashboard Context Banner */}
        <div className="mb-6 bg-gradient-to-r from-blue-500 to-indigo-600 rounded-lg p-6 text-white">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-2xl font-bold mb-2">
                {currentView === 'executive' ? '👑 Executive Overview' :
                 currentView === 'operational' ? '⚡ Operational Dashboard' : 
                 '🎨 Creative Performance'}
              </h2>
              <p className="text-blue-100">
                {currentView === 'executive' ? 'Strategic insights for leadership decision-making' :
                 currentView === 'operational' ? 'Real-time operational metrics and campaign management' :
                 'Creative asset performance and brand intelligence'}
              </p>
            </div>
            <div className="hidden lg:block">
              <div className="text-right">
                <div className="text-3xl font-bold">₱2.85M</div>
                <div className="text-blue-200 text-sm">Total Revenue ({timeRange})</div>
              </div>
            </div>
          </div>
        </div>

        {/* Department-Specific Content */}
        <div className="space-y-6">
          {currentView === 'executive' && (
            <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
              <div className="flex">
                <div className="flex-shrink-0">
                  <span className="text-yellow-400 text-lg">🎯</span>
                </div>
                <div className="ml-3">
                  <h3 className="text-sm font-medium text-yellow-800">Executive Focus Areas</h3>
                  <p className="text-sm text-yellow-700 mt-1">
                    Revenue up 12.5% • Client satisfaction at 94.2% • 5 high-priority campaign optimizations recommended
                  </p>
                </div>
              </div>
            </div>
          )}

          {currentView === 'operational' && (
            <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-6">
              <div className="flex">
                <div className="flex-shrink-0">
                  <span className="text-green-400 text-lg">⚡</span>
                </div>
                <div className="ml-3">
                  <h3 className="text-sm font-medium text-green-800">Operational Status</h3>
                  <p className="text-sm text-green-700 mt-1">
                    24 active campaigns • 3 requiring immediate attention • Resource utilization at 87%
                  </p>
                </div>
              </div>
            </div>
          )}

          {currentView === 'creative' && (
            <div className="bg-purple-50 border border-purple-200 rounded-lg p-4 mb-6">
              <div className="flex">
                <div className="flex-shrink-0">
                  <span className="text-purple-400 text-lg">🎨</span>
                </div>
                <div className="ml-3">
                  <h3 className="text-sm font-medium text-purple-800">Creative Intelligence</h3>
                  <p className="text-sm text-purple-700 mt-1">
                    Brand compliance at 96.2% • 8 high-performing creative assets • 2 optimization opportunities identified
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* Scout Dashboard Component */}
          <div className="bg-white rounded-lg shadow-sm border border-gray-200">
            <ScoutDashboard
              timeRange={timeRange}
              department={currentView === 'executive' ? 'all' : 
                         currentView === 'operational' ? 'account' : 'creative'}
              className="p-6"
            />
          </div>

          {/* Footer Information */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mt-8">
            {/* Data Sources */}
            <div className="bg-gray-50 rounded-lg p-6">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">📊 Data Sources</h3>
              <ul className="text-sm text-gray-600 space-y-2">
                <li>• Supabase Analytics Database</li>
                <li>• Campaign Management Platform</li>
                <li>• Financial Systems Integration</li>
                <li>• Client Feedback Systems</li>
                <li>• Regional Performance APIs</li>
              </ul>
            </div>

            {/* Integration Status */}
            <div className="bg-gray-50 rounded-lg p-6">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">🔄 Integration Status</h3>
              <div className="space-y-2">
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-600">Figma Bridge</span>
                  <span className="text-green-600 font-medium">✅ Active</span>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-600">Live Data Feed</span>
                  <span className="text-green-600 font-medium">✅ Connected</span>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-600">AI Insights</span>
                  <span className="text-blue-600 font-medium">🤖 Processing</span>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-600">Code Connect</span>
                  <span className="text-green-600 font-medium">✅ Synced</span>
                </div>
              </div>
            </div>

            {/* Quick Actions */}
            <div className="bg-gray-50 rounded-lg p-6">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">🚀 Quick Actions</h3>
              <div className="space-y-2">
                <button className="w-full text-left text-sm text-blue-600 hover:text-blue-800 py-1">
                  → Export Dashboard to Figma
                </button>
                <button className="w-full text-left text-sm text-blue-600 hover:text-blue-800 py-1">
                  → Generate Executive Report
                </button>
                <button className="w-full text-left text-sm text-blue-600 hover:text-blue-800 py-1">
                  → Schedule AI Analysis
                </button>
                <button className="w-full text-left text-sm text-blue-600 hover:text-blue-800 py-1">
                  → Configure Alerts
                </button>
              </div>
            </div>
          </div>

          {/* Technical Implementation Notes */}
          <div className="mt-8 p-6 bg-blue-50 rounded-lg border border-blue-200">
            <h3 className="text-sm font-medium text-blue-900 mb-3">
              🛠️ Implementation Features:
            </h3>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 text-sm text-blue-800">
              <ul className="space-y-1">
                <li>• Built with Scout UI Component Library</li>
                <li>• Financial template integration complete</li>
                <li>• Code Connect bridge for Figma sync</li>
                <li>• Responsive design optimized for executives</li>
              </ul>
              <ul className="space-y-1">
                <li>• Live data binding with Supabase</li>
                <li>• Philippine Peso currency formatting</li>
                <li>• APAC regional performance tracking</li>
                <li>• AI-powered insights and recommendations</li>
              </ul>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
};

export default ScoutDashboardDemo;